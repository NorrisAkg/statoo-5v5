import test from "node:test";
import assert from "node:assert/strict";
import { createServer } from "node:http";
import { readFileSync, mkdirSync, writeFileSync } from "node:fs";
import { resolve, extname, sep } from "node:path";
import { chromium } from "playwright";

const root = resolve("mobile/build/web");
const output = "docs/accessibility-2026-10-26";
const mime = {
  ".html": "text/html",
  ".js": "application/javascript",
  ".wasm": "application/wasm",
  ".json": "application/json",
  ".ttf": "font/ttf",
  ".png": "image/png",
  ".css": "text/css",
  ".svg": "image/svg+xml",
};
async function reveal(page, locator, width, height) {
  const scale = Number(new URL(page.url()).searchParams.get("scale") || 1);
  const heading = page.getByRole("heading").first();
  const header = (await heading.count()) ? await heading.boundingBox() : null;
  const top = Math.max(80, header ? header.y + header.height + 8 : 80);
  let reset = false;
  for (let i = 0; i < 60; i++) {
    const box = (await locator.count())
      ? await locator.boundingBox().catch(() => null)
      : null;
    const label = (await locator.count())
      ? await locator.getAttribute("aria-label")
      : "";
    const contentControl =
      /^(Retirer|Marquer|Équipe [ABC]|Rechercher|Effacer)/.test(label || "");
    const bottom =
      height - (scale <= 1.25 && width >= 360 && contentControl ? 88 : 4);
    const minTop =
      scale <= 1.25 && width >= 360 && page.url().includes("/seances/nouvelle")
        ? Math.max(top, 180)
        : top;
    if (box && box.y >= minTop && box.y + box.height <= bottom) return;
    if (!box && !reset) {
      await page.mouse.move(width / 2, height * 0.65);
      await page.mouse.wheel(0, -20000);
      await page.waitForTimeout(150);
      reset = true;
      continue;
    }
    await page.mouse.move(width / 2, height * 0.65);
    await page.mouse.wheel(0, box && box.y < minTop ? -160 : 160);
    await page.waitForTimeout(80);
  }
  throw Error("Action not reachable: " + locator.toString());
}
async function click(page, locator, width, height) {
  await reveal(page, locator, width, height);
  await locator.click();
}

test(
  "F08 actual Flutter web names, keyboard actions and visible composition",
  { timeout: 360000 },
  async () => {
    const server = createServer((req, res) => {
      try {
        const url = new URL(req.url, "http://localhost");
        const path = resolve(
          root,
          "." + (url.pathname === "/" ? "/index.html" : url.pathname),
        );
        if (!path.startsWith(root + sep)) throw Error("outside");
        let bytes = readFileSync(path);
        if (path.endsWith("index.html"))
          bytes = Buffer.from(
            bytes
              .toString()
              .replace(
                "<head>",
                `<head><style>html{font-size:${16 * Number(url.searchParams.get("scale") || 1)}px}</style>`,
              ),
          );
        res.setHeader(
          "Content-Type",
          mime[extname(path)] || "application/octet-stream",
        );
        res.end(bytes);
      } catch {
        res.writeHead(404).end();
      }
    });
    await new Promise((r) => server.listen(0, "127.0.0.1", r));
    const base = "http://127.0.0.1:" + server.address().port;
    const browser = await chromium.launch({
      channel: "chrome",
      headless: true,
    });
    mkdirSync(output, { recursive: true });
    const configs = process.env.A11Y_WIDTH
      ? [
          [
            Number(process.env.A11Y_WIDTH),
            Number(process.env.A11Y_SCALE || 1),
            process.env.A11Y_THEME || "light",
          ],
        ]
      : process.env.A11Y_SMOKE
        ? [[393, 1, "light"]]
        : [
            [320, 1, "light"],
            [393, 1, "dark"],
            [320, 2, "dark"],
            [393, 2, "light"],
          ];
    try {
      for (const [width, scale, colorScheme] of configs) {
        const height = width === 320 ? 568 : 852;
        const context = await browser.newContext({
          viewport: { width, height },
          deviceScaleFactor: 1,
          colorScheme,
        });
        const page = await context.newPage();
        page.setDefaultTimeout(20000);
        const errors = [];
        page.on("pageerror", (e) => errors.push(e.message));
        const key = `${width}-${scale}-${colorScheme}`;
        try {
          await page.goto(base + "/?scale=" + scale);
          await page
            .getByRole("button", { name: "Passer", exact: true })
            .click();
          await page.goto(base + "/?scale=" + scale + "#/creer-equipe");
          const input = page
            .locator('input[data-semantics-role="text-field"]')
            .first();
          await input.waitFor();
          await input.fill("QA accessibilité");
          await click(
            page,
            page.getByRole("button", {
              name: "Continuer vers l'effectif",
              exact: true,
            }),
            width,
            height,
          );
          for (const name of [
            "Alice",
            "Bob",
            "Jean-Pierre au nom particulièrement long",
          ]) {
            await page
              .getByRole("textbox", { name: /Nom ou prénom/ })
              .waitFor();
            const field = page
              .locator('input[data-semantics-role="text-field"]')
              .first();
            await reveal(page, field, width, height);
            await field.click();
            await page.waitForTimeout(150);
            await page.keyboard.press("ControlOrMeta+A");
            await page.keyboard.type(name, { delay: 25 });
            await page.waitForTimeout(150);
            assert.equal(await field.inputValue(), name);
            await click(
              page,
              page.getByRole("button", {
                name: "Ajouter ce joueur",
                exact: true,
              }),
              width,
              height,
            );
            await reveal(
              page,
              page.getByRole("button", {
                name: `Retirer ${name} du groupe`,
                exact: true,
              }),
              width,
              height,
            );
          }
          await page.screenshot({ path: `${output}/roster-${key}.png` });
          await click(
            page,
            page.getByRole("button", {
              name: "Terminer et aller à l'Accueil",
              exact: true,
            }),
            width,
            height,
          );
          await page.goto(base + "/?scale=" + scale + "#/seances");
          const create = page
            .getByRole("button", { name: "Nouvelle séance", exact: true })
            .last();
          await create.waitFor();
          await reveal(page, create, width, height);
          await create.focus();
          await page.keyboard.press("Enter");
          if (colorScheme === "dark")
            await click(
              page,
              page.getByRole("button", {
                name: "Tournoi (3 équipes)",
                exact: true,
              }),
              width,
              height,
            );
          await click(
            page,
            page.getByRole("button", { name: "Continuer", exact: true }),
            width,
            height,
          );
          const present = page.getByRole("button", {
            name: "Marquer Alice présent",
            exact: true,
          });
          await reveal(page, present, width, height);
          await present.focus();
          await page.keyboard.press("Enter");
          const teamA = page.getByRole("button", {
            name: "Équipe A pour Alice",
            exact: true,
          });
          await click(page, teamA, width, height);
          if (colorScheme === "dark")
            await click(
              page,
              page.getByRole("button", {
                name: "Équipe C pour Alice",
                exact: true,
              }),
              width,
              height,
            );
          const search = page.getByRole("textbox", {
            name: /Rechercher un joueur/,
          });
          assert.equal(await search.count(), 1);
          const name = await search.getAttribute("aria-label");
          assert.ok(
            !name?.includes("Alice"),
            "search name must not aggregate the roster",
          );
          await reveal(page, search, width, height);
          await page.waitForTimeout(300);
          const searchBox = await search.boundingBox();
          await page.mouse.click(
            searchBox.x + searchBox.width / 2,
            searchBox.y + searchBox.height / 2,
          );
          await page.waitForTimeout(300);
          assert.match(
            await page.evaluate(
              () => document.activeElement.getAttribute("aria-label") || "",
            ),
            /Rechercher un joueur/,
          );
          await page.keyboard.press("ControlOrMeta+A");
          await page.keyboard.type("Bob", { delay: 25 });
          await page
            .getByRole("button", { name: "Effacer la recherche", exact: true })
            .waitFor({ state: "attached" });
          await page
            .getByRole("button", { name: "Marquer Bob présent", exact: true })
            .waitFor();
          assert.equal(
            await page
              .getByRole("button", {
                name: "Marquer Alice présent",
                exact: true,
              })
              .count(),
            0,
          );
          assert.ok(
            !(await page.locator("body").ariaSnapshot()).includes(
              "Jean-Pierre",
            ),
            "query must actually filter the long-named player",
          );
          await click(
            page,
            page.getByRole("button", {
              name: "Effacer la recherche",
              exact: true,
            }),
            width,
            height,
          );
          await teamA.waitFor();
          const remove = page.getByRole("button", {
            name: "Retirer Alice de la séance",
            exact: true,
          });
          await reveal(page, remove, width, height);
          await page.waitForTimeout(300);
          await page.screenshot({ path: `${output}/composition-${key}.png` });
          writeFileSync(
            `${output}/semantics-${key}.txt`,
            await page.locator("body").ariaSnapshot(),
          );
          await remove.click();
          await reveal(page, present, width, height);
          const longName = "Jean-Pierre au nom particulièrement long";
          await click(
            page,
            page.getByRole("button", {
              name: `Marquer ${longName} présent`,
              exact: true,
            }),
            width,
            height,
          );
          await click(
            page,
            page.getByRole("button", {
              name: `Équipe B pour ${longName}`,
              exact: true,
            }),
            width,
            height,
          );
          const longRemove = page.getByRole("button", {
            name: `Retirer ${longName} de la séance`,
            exact: true,
          });
          await reveal(page, longRemove, width, height);
          await page.waitForTimeout(300);
          await page.screenshot({ path: `${output}/long-name-${key}.png` });
          writeFileSync(
            `${output}/long-name-semantics-${key}.txt`,
            await page.locator("body").ariaSnapshot(),
          );
          assert.deepEqual(errors, []);
          console.log(
            JSON.stringify({
              width,
              scale,
              colorScheme,
              searchName: name,
              errors,
              keyboard: "Enter creates and marks present",
            }),
          );
        } catch (error) {
          await page.screenshot({ path: `${output}/failure-${key}.png` });
          writeFileSync(
            `${output}/failure-${key}.txt`,
            await page.locator("body").ariaSnapshot(),
          );
          throw error;
        } finally {
          await context.close();
        }
      }
    } finally {
      await browser.close();
      await new Promise((r) => server.close(r));
    }
  },
);
