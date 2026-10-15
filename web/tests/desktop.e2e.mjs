import test from "node:test";
import assert from "node:assert/strict";
import { chromium } from "playwright";
import { mkdirSync } from "node:fs";
const base = process.env.STATOO_TEST_URL || "http://127.0.0.1:18085";
test("DESK-06 tournament uses three columns on desktop and stacked teams on mobile", async () => {
  const browser = await chromium.launch({ channel: "chrome", headless: true });
  try {
    for (const width of [390, 1440]) {
      const context = await browser.newContext({
          viewport: { width, height: 1000 },
        }),
        p = await context.newPage();
      const account = { id: "me", roles: ["SG"], shared: false };
      const snapshot = {
        name: "Tournoi desktop",
        account,
        members: [],
        leaders: [],
        opening: { cash: 0, members: {} },
        finances: { cash: 0, members: {} },
        documents: {
          s: {
            domain: "sport",
            owner: "me",
            revision: 1,
            generation: 0,
            candidates: [],
            payload: {
              session: {
                id: "s",
                played_at: "2026-10-15T20:00:00",
                status: "CLOSED",
                session_type: "TOURNAMENT_3",
                wins_a: 3,
                wins_b: 2,
                wins_c: 1,
                team_names: {
                  A: "Racing Atlas",
                  B: "Union des Cèdres",
                  C: "Sporting du Port",
                },
              },
              participations: [],
            },
          },
        },
      };
      await p.route("**/groups/g", (r) => r.fulfill({ json: snapshot }));
      await p.addInitScript(
        ({ base, account }) =>
          sessionStorage.setItem(
            "statoo-connection",
            JSON.stringify({
              api: base,
              group: "g",
              token: "synthetic",
              expires_at: "2099-01-01T00:00:00Z",
              account,
            }),
          ),
        { base, account },
      );
      await p.goto(base + "/portal/");
      await p
        .getByRole("heading", { name: "Tournoi desktop", exact: true })
        .waitFor();
      const boxes = await p
        .locator(".teams.tournament .team")
        .evaluateAll((nodes) =>
          nodes.map((n) => ({
            x: n.getBoundingClientRect().x,
            y: n.getBoundingClientRect().y,
          })),
        );
      assert.equal(boxes.length, 3);
      if (width >= 1280) {
        assert.ok(Math.abs(boxes[0].y - boxes[2].y) < 4);
        assert.ok(boxes[0].x < boxes[1].x && boxes[1].x < boxes[2].x);
      } else assert.ok(boxes[0].y < boxes[1].y && boxes[1].y < boxes[2].y);
      await context.close();
    }
  } finally {
    await browser.close();
  }
});
test("DESK-01/02/03/04/07 responsive branded registration in both themes", async () => {
  const browser = await chromium.launch({ channel: "chrome", headless: true });
  mkdirSync("mobile/build/pwa-desktop", { recursive: true });
  try {
    for (const theme of ["dark", "light"])
      for (const width of [320, 390, 768, 1280, 1440, 1920]) {
        const context = await browser.newContext({
            viewport: { width, height: 1000 },
            colorScheme: theme,
          }),
          p = await context.newPage();
        await p.goto(base + "/portal/");
        await p
          .getByRole("button", { name: "Créer un groupe", exact: true })
          .click();
        await p.evaluate(() => document.fonts.ready);
        const logo = p.locator(".brand img");
        assert.equal(
          await logo.count(),
          1,
          "Real logo must replace the S placeholder",
        );
        assert.equal(
          await logo.evaluate((i) => i.complete && i.naturalWidth > 0),
          true,
        );
        const bounds = await p.evaluate(() => ({
          overflow: document.documentElement.scrollWidth > innerWidth,
          header: document.querySelector(".topbar").getBoundingClientRect()
            .height,
          hero: document.querySelector(".welcome-copy").getBoundingClientRect()
            .top,
          card: document.querySelector(".welcome .card").getBoundingClientRect()
            .top,
        }));
        assert.equal(bounds.overflow, false, `${theme} ${width}: overflow`);
        assert.ok(bounds.header <= 96, `${width}: oversized header`);
        const admin = p.getByLabel("Identifiant Admin", { exact: true }),
          password = p.getByLabel("Mot de passe Admin", { exact: true });
        if (width >= 1280) {
          assert.ok(
            Math.abs(bounds.hero - bounds.card) < 80,
            "Intro must align with top of registration",
          );
          const a = await admin.boundingBox(),
            b = await p
              .getByLabel("Identifiant collectif", { exact: true })
              .boundingBox();
          assert.ok(
            Math.abs(a.y - b.y) < 4 && b.x > a.x,
            "Admin and collective access should use columns",
          );
          const main = await p.locator("main").boundingBox();
          assert.ok(main.width >= 1200, "Use desktop width");
        } else if (width <= 390) {
          const a = await admin.boundingBox(),
            b = await password.boundingBox();
          assert.ok(b.y > a.y && a.height >= 44);
        }
        await p
          .getByRole("group", { name: "Votre accès Admin", exact: true })
          .waitFor();
        if ([390, 1440, 1920].includes(width))
          await p.screenshot({
            path: `mobile/build/pwa-desktop/registration-${width}-${theme}.png`,
            fullPage: true,
          });
        await context.close();
      }
  } finally {
    await browser.close();
  }
});
