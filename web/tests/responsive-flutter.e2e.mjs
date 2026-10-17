import test from "node:test";
import assert from "node:assert/strict";
import { createServer } from "node:http";
import { readFileSync, mkdirSync } from "node:fs";
import { resolve, extname, sep } from "node:path";
import { chromium } from "playwright";
const root = resolve("mobile/build/web");
const mime = {
  ".html": "text/html",
  ".js": "application/javascript",
  ".css": "text/css",
  ".wasm": "application/wasm",
  ".json": "application/json",
  ".png": "image/png",
  ".ttf": "font/ttf",
};
const overlap = (a, b) =>
  a.x < b.x + b.width &&
  a.x + a.width > b.x &&
  a.y < b.y + b.height &&
  a.y + a.height > b.y;
async function reveal(page, locator, width, height) {
  for (let i = 0; i < 35; i++) {
    const box = (await locator.count()) ? await locator.boundingBox() : null;
    if (box && box.y >= 85 && box.y + box.height <= height - 4) return box;
    await page.mouse.move(width / 2, height * 0.65);
    await page.mouse.wheel(0, box && box.y < 85 ? -220 : 220);
    await page.waitForTimeout(100);
  }
  throw Error(
    "Flutter action could not be reached by scrolling: " +
      (await locator.getAttribute("aria-label")),
  );
}

test(
  "RSP09/11 actual Flutter web frame separates PWA controls from app header",
  { timeout: 180000 },
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
    const browser = await chromium.launch({
      channel: "chrome",
      headless: true,
    });
    mkdirSync("docs/responsive-captures", { recursive: true });
    try {
      for (const width of process.env.RSP_WIDTH
        ? [Number(process.env.RSP_WIDTH)]
        : process.env.RSP_FULL
          ? [320, 390, 393]
          : [390]) {
        for (const scale of process.env.RSP_SCALE
          ? [Number(process.env.RSP_SCALE)]
          : process.env.RSP_FULL
            ? [1, 1.3, 2]
            : [1]) {
          for (const colorScheme of process.env.RSP_FULL
            ? ["light", "dark"]
            : ["light"]) {
            const context = await browser.newContext({
              viewport: { width, height: width === 320 ? 568 : 844 },
              deviceScaleFactor: 1,
              colorScheme,
            });
            const page = await context.newPage();
            page.setDefaultTimeout(45000);
            const errors = [];
            page.on("pageerror", (e) => errors.push(e.message));
            await page.goto(
              "http://127.0.0.1:" + server.address().port + "/?scale=" + scale,
            );
            await page
              .getByRole("button", { name: "Passer", exact: true })
              .click();
            await page.screenshot({
              path: `docs/responsive-captures/entry-${width}-${scale}-${colorScheme}.png`,
            });
            const summaryBox = await page
              .locator("#statoo-pwa summary")
              .boundingBox();
            assert.ok(
              summaryBox.height <= Math.max(48, 14 * scale * 1.5 + 22) + 1,
              "PWA label should fit one line when viewport allows",
            );
            const create = page.getByRole("button", {
              name: "Créer un groupe",
              exact: true,
            });
            const createRect = await reveal(
              page,
              create,
              width,
              width === 320 ? 568 : 844,
            );
            console.log(
              JSON.stringify({ width, scale, colorScheme, createRect }),
            );
            await create.click();
            const menu = await page
              .locator("#statoo-pwa summary")
              .boundingBox();
            const badge = await page
              .getByText("Étape 1 sur 2 · Votre équipe", { exact: true })
              .boundingBox();
            await page.screenshot({
              path: `docs/responsive-captures/create-${width}-${scale}-${colorScheme}.png`,
            });
            assert.ok(menu && badge);
            assert.equal(
              overlap(menu, badge),
              false,
              "PWA menu must not cover the Flutter header",
            );
            const input = page
              .locator('input[data-semantics-role="text-field"]')
              .first();
            await input.fill("Équipe QA responsive");
            const formButton = page.getByRole("button", {
              name: "Continuer vers l'effectif",
              exact: true,
            });
            await reveal(page, formButton, width, width === 320 ? 568 : 844);
            await page.waitForTimeout(200);
            assert.equal(await input.inputValue(), "Équipe QA responsive");
            assert.equal(errors.length, 0, errors.join("\n"));
            await page.screenshot({
              path: `docs/responsive-captures/create-action-${width}-${scale}-${colorScheme}.png`,
            });
            console.log(
              JSON.stringify(
                await page.evaluate(() => ({
                  scrollY,
                  menuAfter: document
                    .querySelector("#statoo-pwa")
                    .getBoundingClientRect()
                    .toJSON(),
                  viewport: {
                    height: visualViewport.height,
                    offsetTop: visualViewport.offsetTop,
                    scale: visualViewport.scale,
                  },
                  body: document.body.style.cssText,
                })),
              ),
            );
            console.log(
              JSON.stringify({
                width,
                scale,
                colorScheme,
                menu,
                badge,
                errors,
              }),
            );
            await context.close();
          }
        }
      }
    } finally {
      await browser.close();
      await new Promise((r) => server.close(r));
    }
  },
);
