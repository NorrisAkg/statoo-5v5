import test from "node:test";
import assert from "node:assert/strict";
import { createServer } from "node:http";
import { readFileSync, mkdirSync, writeFileSync } from "node:fs";
import { resolve, extname, sep } from "node:path";
import { chromium } from "playwright";

const root = resolve("mobile/build/web");
const output =
  process.env.STATOO_QA_OUTPUT || "docs/portable-photos-2026-10-27";
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
  "F15 real web restores an embedded photo and renders it after reload",
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
        let bytes = readFileSync(path);
        if (path.endsWith('index.html')) bytes = Buffer.from(bytes.toString().replace('<head>', `<head><style>html{font-size:${16 * Number(url.searchParams.get('scale') || 1)}px}</style>`));
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
    const context = await browser.newContext({
      viewport: { width: 393, height: 852 },
    });
    const page = await context.newPage();
    page.setDefaultTimeout(20000);
    const errors = [];
    context.on("page", (p) => p.on("pageerror", (e) => errors.push(e.message)));
    page.on("pageerror", (e) => errors.push(e.message));
    mkdirSync(output, { recursive: true });
    try {
      await page.goto(base);
      await page.getByRole("button", { name: "Passer", exact: true }).click();
      await page.goto(base + "/#/creer-equipe");
      const chooser = page.waitForEvent('filechooser');
      await page.getByText("J'ai déjà une sauvegarde Statoo", {exact:true}).click();
      const png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==';
      const payload = {version:2, app:'statoo_5v5', exported_at:'2026-10-27',
        teams:[{id:'photo-team',name:'QA photos portables',created_at:'2026-10-27'}],
        players:[{id:'photo-player',team_id:'photo-team',name:'Alexandre Photo portable',created_at:'2026-10-27',updated_at:'2026-10-27',avatar_url:'data:image/png;base64,'+png}],
        sessions:[],participations:[],meta:{}};
      await (await chooser).setFiles({name:'photos.json',mimeType:'application/json',buffer:Buffer.from(JSON.stringify(payload))});
      await page.getByRole('button',{name:'Remplacer toutes les données',exact:true}).click();
      await page.waitForTimeout(500);
      writeFileSync(output+'/after-restore.txt', await page.locator('body').ariaSnapshot());
      await page.getByRole('button',{name:'Joueurs',exact:true}).click();
      await page.getByRole('group', {name:'Alexandre Photo portable', exact:true}).waitFor();
      await page.waitForTimeout(1000);
      await page.screenshot({path:output+'/list-light.png'});
      await page.getByRole('group', {name:'Alexandre Photo portable', exact:true}).click();
      await page.getByRole('heading', {name:'Alexandre Photo portable', exact:true}).waitFor();
      await page.waitForTimeout(1000);
      await page.screenshot({path:output+'/detail-light.png'});
      await page.reload();
      await page.getByRole('heading', {name:'Alexandre Photo portable', exact:true}).waitFor();
      await page.waitForTimeout(1000);
      await page.screenshot({path:output+'/detail-after-reload.png'});
      await page.emulateMedia({colorScheme:'dark'});
      await page.setViewportSize({width:320,height:800});
      await page.goto(base+'/?scale=2#/joueurs');
      await page.getByRole('group', {name:'Alexandre Photo portable', exact:true}).waitFor();
      await page.waitForTimeout(1000);
      await page.screenshot({path:output+'/list-dark-small.png'});
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
