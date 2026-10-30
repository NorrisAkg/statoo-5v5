import test from "node:test";
import assert from "node:assert/strict";
import { createServer } from "node:http";
import { readFileSync, mkdirSync, writeFileSync } from "node:fs";
import { resolve, extname, sep } from "node:path";
import { chromium } from "playwright";

const root = resolve("mobile/build/web");
const output =
  process.env.STATOO_QA_OUTPUT || "docs/startup-group-2026-10-26/green";
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

test(
  "F11 real Flutter web preserves active-group statistics on direct reload and new tab",
  { timeout: 150000 },
  async () => {
    const server = createServer((req, res) => {
      try {
        const url = new URL(req.url, "http://localhost");
        const path = resolve(
          root,
          "." + (url.pathname === "/" ? "/index.html" : url.pathname),
        );
        if (!path.startsWith(root + sep)) throw Error("outside");
        res.setHeader(
          "Content-Type",
          mime[extname(path)] || "application/octet-stream",
        );
        res.end(readFileSync(path));
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
    const context = await browser.newContext({
      viewport: { width: 1280, height: 1000 },
    });
    const page = await context.newPage();
    page.setDefaultTimeout(20000);
    const errors = [];
    context.on("page", (p) => p.on("pageerror", (e) => errors.push(e.message)));
    page.on("pageerror", (e) => errors.push(e.message));
    mkdirSync(output, { recursive: true });
    async function stats(p, label) {
      await p
        .getByRole("heading", { name: "Statistiques", exact: true })
        .waitFor();
      let snapshot = "";
      const deadline = Date.now() + 20000;
      do {
        snapshot = await p.locator("body").ariaSnapshot();
        if (/6\s+Joueurs actifs\s+Sur 6 inscrits au total/.test(snapshot))
          break;
        await p.waitForTimeout(150);
      } while (Date.now() < deadline);
      writeFileSync(`${output}/${label}.txt`, snapshot);
      await p.screenshot({ path: `${output}/${label}.png` });
      assert.match(snapshot, /6\s+Joueurs actifs\s+Sur 6 inscrits au total/);
      assert.match(snapshot, /0[\s\S]*Séances jouées/);
      return snapshot;
    }
    try {
      await page.goto(base);
      await page.getByRole("button", { name: "Passer", exact: true }).click();
      await page.goto(base + "/#/creer-equipe");
      const field = page
        .locator('input[data-semantics-role="text-field"]')
        .first();
      await field.waitFor();
      await field.fill("QA reprise du groupe");
      await page
        .getByRole("button", { name: "Continuer vers l'effectif", exact: true })
        .click();
      for (const name of [
        "Alice",
        "Bob",
        "Camille",
        "Diane",
        "Emile",
        "Fatou",
      ]) {
        await page.getByRole("textbox", { name: /Nom ou prénom/ }).waitFor();
        const input = page
          .locator('input[data-semantics-role="text-field"]')
          .first();
        await input.click();
        await page.waitForTimeout(150);
        await page.keyboard.press("ControlOrMeta+A");
        await page.keyboard.type(name, { delay: 20 });
        await page.waitForTimeout(150);
        assert.equal(await input.inputValue(), name);
        await page
          .getByRole("button", { name: "Ajouter ce joueur", exact: true })
          .click();
        await page
          .getByRole("button", {
            name: `Retirer ${name} du groupe`,
            exact: true,
          })
          .waitFor();
      }
      await page
        .getByRole("button", {
          name: "Terminer et aller à l'Accueil",
          exact: true,
        })
        .click();
      await page.getByRole("button", { name: "Stats", exact: true }).click();
      await stats(page, "before-reload");
      assert.match(page.url(), /#\/stats$/);
      await page.reload();
      await stats(page, "after-reload");
      const fresh = await context.newPage();
      fresh.setDefaultTimeout(20000);
      await fresh.goto(base + "/#/stats");
      await stats(fresh, "new-tab");
      assert.deepEqual(errors, []);
    } catch (error) {
      writeFileSync(
        `${output}/failure.txt`,
        await page.locator("body").ariaSnapshot(),
      );
      await page.screenshot({ path: `${output}/failure.png` });
      throw error;
    } finally {
      await context.close();
      await browser.close();
      await new Promise((r) => server.close(r));
    }
  },
);
