import test from "node:test";
import assert from "node:assert/strict";
import { chromium } from "playwright";
import { mkdirSync } from "node:fs";
const url = "http://127.0.0.1:19094/prototypes/live-stats/";
test("LIVE-01/04/06/07/08/09/12 live event flow, wins, undo, persistence and review", async () => {
  const browser = await chromium.launch({ channel: "chrome", headless: true });
  try {
    const p = await browser.newPage({ viewport: { width: 393, height: 852 } }),
      requests = [];
    p.on("request", (r) => requests.push(r.url()));
    await p.goto(url);
    await p
      .getByRole("button", { name: "Match · 2 équipes", exact: true })
      .click();
    await p
      .getByRole("button", { name: "Ajouter un but", exact: true })
      .click();
    await p.getByRole("button", { name: "Karim Benali", exact: true }).click();
    await p
      .getByRole("button", { name: "Youssef El Amrani", exact: true })
      .click();
    assert.match(await p.locator('[data-team="A"] .score').innerText(), /1/);
    assert.match(await p.locator('[data-player="a1"]').innerText(), /1 but/);
    await p
      .getByRole("button", { name: "Annuler la dernière action", exact: true })
      .click();
    assert.equal(await p.locator('[data-team="A"] .score').innerText(), "0");
    await p
      .getByRole("button", { name: "Tournoi · 3 équipes", exact: true })
      .click();
    await p
      .getByRole("button", {
        name: "Ajouter une victoire à Racing Atlas",
        exact: true,
      })
      .click();
    await p
      .getByRole("button", { name: "Ajouter un but", exact: true })
      .click();
    await p
      .getByRole("button", { name: "Buteur non renseigné", exact: true })
      .click();
    assert.equal(await p.locator('[data-team="A"] .score').innerText(), "1");
    await p.reload();
    assert.equal(await p.locator('[data-team="A"] .score').innerText(), "1");
    await p
      .getByRole("button", { name: "Ajouter un but", exact: true })
      .click();
    await p.getByRole("button", { name: "Annuler le but", exact: true }).click();
    await p
      .getByRole("button", { name: "Terminer la séance", exact: true })
      .click();
    await p
      .getByRole("button", { name: "Continuer la saisie", exact: true })
      .click();
    await p
      .getByRole("button", { name: "Terminer la séance", exact: true })
      .click();
    await p
      .getByRole("button", { name: "Confirmer la clôture", exact: true })
      .click();
    assert.equal(
      await p
        .getByRole("button", { name: "Ajouter un but", exact: true })
        .isDisabled(),
      true,
    );
    await p
      .getByRole("button", { name: "Reprendre la saisie", exact: true })
      .click();
    await p.getByLabel("Accès", { exact: true }).selectOption("viewer");
    assert.equal(
      await p
        .getByRole("button", { name: "Ajouter un but", exact: true })
        .isDisabled(),
      true,
    );
    assert.equal(
      requests.some((u) => /\/groups|onrender|\/auth/.test(u)),
      false,
      "Demo must never contact API",
    );
  } finally {
    await browser.close();
  }
});
test("LIVE-10 refused storage reports unsaved changes", async () => {
  const browser = await chromium.launch({ channel: "chrome", headless: true });
  try {
    const p = await browser.newPage();
    await p.addInitScript(() => {
      const original = Storage.prototype.setItem;
      Storage.prototype.setItem = function (k, v) {
        if (k.startsWith("statoo-live-prototype")) throw Error("quota");
        return original.call(this, k, v);
      };
    });
    await p.goto(url);
    await p
      .getByRole("button", {
        name: "Ajouter une victoire à Racing Atlas",
        exact: true,
      })
      .click();
    await p.getByRole("alert").filter({ hasText: "non enregistrée" }).waitFor();
  } finally {
    await browser.close();
  }
});
test("LIVE-11 themes, 320/393 widths and 100/130/200 percent text reflow", async () => {
  const browser = await chromium.launch({ channel: "chrome", headless: true });
  mkdirSync("mobile/build/live-prototype", { recursive: true });
  try {
    for (const theme of ["dark", "light"])
      for (const width of [320, 393, 1200])
        for (const scale of ["100", "130", "200"]) {
          const p = await browser.newPage({
            viewport: { width, height: 900 },
            colorScheme: theme,
          });
          await p.goto(url);
          await p
            .getByLabel("Taille du texte", { exact: true })
            .selectOption(scale);
          await p
            .getByRole("tab", { name: "Sporting du Port", exact: true })
            .click();
          assert.equal(
            await p.evaluate(
              () => document.documentElement.scrollWidth > innerWidth,
            ),
            false,
            `${width}/${scale}/${theme}`,
          );
          await p
            .getByRole("button", { name: "Ajouter un but", exact: true })
            .click();
          const choices = p.locator("dialog button");
          for (const b of await choices.all()) {
            const box = await b.boundingBox();
            if (box) assert.ok(box.width >= 48 && box.height >= 48);
          }
          assert.equal(
            await p
            .locator("dialog[open]")
              .evaluate((d) => d.scrollWidth > d.clientWidth),
            false,
          );
          await p.keyboard.press("Escape");
          if (scale === "100" && [393, 1200].includes(width))
            await p.screenshot({
              path: `mobile/build/live-prototype/${width}-${theme}.png`,
              fullPage: true,
            });
          await p.close();
        }
  } finally {
    await browser.close();
  }
});
