import test from "node:test";
import assert from "node:assert/strict";
import { createServer } from "node:http";
import {
  mkdtempSync,
  mkdirSync,
  readFileSync,
  writeFileSync,
  cpSync,
  rmSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { fileURLToPath } from "node:url";
import { join, extname } from "node:path";
import { chromium } from "playwright";
import { packageUniversal } from "../../scripts/package-universal-web.mjs";
const source = new URL("../../mobile/web/", import.meta.url);
const mime = {
  ".js": "application/javascript",
  ".css": "text/css",
  ".html": "text/html",
  ".json": "application/manifest+json",
  ".png": "image/png",
  ".wasm": "application/wasm",
};
const html = `<!doctype html><html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><link rel="manifest" href="manifest.json"><link rel="stylesheet" href="pwa-shell.css"></head><body><main><h1>Terrain de test</h1><input aria-label="Saisie en cours"><p id="version"></p></main><script src="marker.js"></script><script src="app-shell.js"></script></body></html>`;
async function fixture({ real = false } = {}) {
  const dir = mkdtempSync(join(tmpdir(), "statoo-pwa-shell-"));
  const build = join(dir, "build"),
    output = join(dir, "output");
  mkdirSync(build);
  let failAssets = false;
  function deploy(version) {
    for (const f of [
      "flutter_bootstrap.js",
      "main.dart.js",
      "sqlite3.wasm",
      "sqflite_sw.js",
    ])
      writeFileSync(join(build, f), "test-" + version);
    for (const f of ["app-shell.js", "manifest.json"])
      cpSync(new URL(f, source), join(build, f));
    if (version === "v1")
      cpSync(new URL("icons", source), join(build, "icons"), {
        recursive: true,
      });
    try {
      cpSync(new URL("pwa-shell.css", source), join(build, "pwa-shell.css"));
    } catch {
      writeFileSync(join(build, "pwa-shell.css"), "");
    }
    writeFileSync(join(build, "index.html"), html);
    writeFileSync(
      join(build, "marker.js"),
      `document.getElementById('version').textContent='${version}';`,
    );
    packageUniversal({ build, output, legacy: join(dir, "no-legacy") });
  }
  deploy("v1");
  const server = createServer((req, res) => {
    const pathname = new URL(req.url, "http://local").pathname;
    const file = pathname === "/" ? "index.html" : pathname.slice(1);
    if (failAssets && file === "marker.js") {
      res.writeHead(503).end();
      return;
    }
    if (file.includes("..")) {
      res.writeHead(400).end();
      return;
    }
    try {
      const body = readFileSync(join(output, file));
      res
        .writeHead(200, {
          "Content-Type": mime[extname(file)] || "application/octet-stream",
          "Cache-Control":
            file === "marker.js" ? "public,max-age=3600" : "no-store",
        })
        .end(body);
    } catch {
      res.writeHead(404).end();
    }
  });
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  const browser = real
    ? null
    : await chromium.launch({ channel: "chrome", headless: true });
  const context = real
    ? await chromium.launchPersistentContext(join(dir, "profile"), {
        channel: "chrome",
        headless: true,
      })
    : await browser.newContext();
  if (!real)
    await context.addInitScript(() => {
      const sw = new EventTarget(),
        reg = new EventTarget(),
        installing = new EventTarget();
      window.pwaTest = { sent: [], checks: 0, prompts: 0, fail: false };
      reg.waiting = null;
      reg.installing = installing;
      reg.update = async () => {
        window.pwaTest.checks++;
        if (window.pwaTest.fail) throw Error("offline");
      };
      sw.controller = {};
      sw.register = async (_url, options) => {
        if (window.pwaTest.failRegister) throw Error("registration refused");
        window.pwaTest.options = options;
        return reg;
      };
      Object.defineProperty(navigator, "serviceWorker", {
        configurable: true,
        value: sw,
      });
      window.pwaTest.waiting = () => {
        reg.waiting = { postMessage: (m) => window.pwaTest.sent.push(m) };
        reg.dispatchEvent(new Event("updatefound"));
        installing.dispatchEvent(new Event("statechange"));
      };
      window.pwaTest.activate = () => {
        reg.waiting = null;
        sw.dispatchEvent(new Event("controllerchange"));
      };
      window.pwaTest.install = () => {
        const event = new Event("beforeinstallprompt", { cancelable: true });
        event.prompt = async () => {
          window.pwaTest.prompts++;
        };
        event.userChoice = Promise.resolve({ outcome: "dismissed" });
        window.dispatchEvent(event);
      };
    });
  const page = await context.newPage();
  const url = `http://127.0.0.1:${server.address().port}/`;
  return {
    page,
    context,
    url,
    deploy,
    setFailAssets: (value) => {
      failAssets = value;
    },
    close: async () => {
      await context.close();
      if (browser) await browser.close();
      await new Promise((r) => server.close(r));
      rmSync(dir, { recursive: true, force: true });
    },
  };
}
test("PWAS-02/03/04/05/06/08/13 install and update controls are explicit, deduplicated and recoverable", async () => {
  const x = await fixture();
  try {
    const p = x.page;
    await p.goto(x.url);
    assert.equal(
      await p.locator("#statoo-pwa").count(),
      1,
      "PWA controls missing",
    );
    await p.locator("#statoo-pwa summary").click();
    await p
      .getByRole("button", { name: "Installer Statoo", exact: true })
      .click();
    assert.match(
      await p.getByRole("dialog").innerText(),
      /menu|écran d’accueil/,
    );
    await p.getByRole("button", { name: "Fermer", exact: true }).click();
    await p.evaluate(() => window.pwaTest.install());
    await p
      .getByRole("button", { name: "Installer Statoo", exact: true })
      .click();
    assert.equal(await p.evaluate(() => window.pwaTest.prompts), 1);
    await p.evaluate(() => {
      window.pwaTest.waiting();
      window.pwaTest.waiting();
    });
    await p.addScriptTag({
      path: fileURLToPath(new URL("app-shell.js", source)),
    });
    assert.equal(await p.locator("#statoo-pwa").count(), 1);
    assert.equal(
      await p
        .getByRole("button", { name: "Mettre à jour Statoo", exact: true })
        .count(),
      1,
      JSON.stringify(
        await p.evaluate(() => ({
          open: document.querySelector("#statoo-pwa").open,
          hidden: document.querySelector("#statoo-pwa-update").hidden,
          status: document.querySelector("#statoo-pwa-status").textContent,
          options: window.pwaTest.options,
        })),
      ),
    );
    await p
      .getByRole("button", { name: "Mettre à jour Statoo", exact: true })
      .click();
    await p.getByRole("button", { name: "Plus tard", exact: true }).click();
    assert.equal(await p.evaluate(() => window.pwaTest.sent.length), 0);
    await p
      .getByRole("button", { name: "Mettre à jour Statoo", exact: true })
      .click();
    await p
      .getByRole("button", { name: "Confirmer la mise à jour", exact: true })
      .click();
    assert.deepEqual(await p.evaluate(() => window.pwaTest.sent), [
      { type: "SKIP_WAITING" },
    ]);
    await p.evaluate(() => window.dispatchEvent(new Event("appinstalled")));
    assert.equal(
      await p
        .getByRole("button", { name: "Installer Statoo", exact: true })
        .isVisible(),
      false,
    );
    assert.equal(
      await p.evaluate(() => window.pwaTest.options.updateViaCache),
      "none",
    );
    await p.evaluate(() => {
      window.pwaTest.fail = true;
    });
    await p
      .getByRole("button", { name: "Vérifier les mises à jour", exact: true })
      .click();
    assert.match(
      await p.locator("#statoo-pwa-status").innerText(),
      /indisponible/,
    );
    await p.evaluate(() => {
      window.pwaTest.fail = false;
    });
    await p
      .getByRole("button", { name: "Vérifier les mises à jour", exact: true })
      .click();
    assert.doesNotMatch(
      await p.locator("#statoo-pwa-status").innerText(),
      /indisponible/,
    );
  } finally {
    await x.close();
  }
});
test("PWAS-07/10/11 real v1 to v2 activation preserves storage and works offline", async () => {
  const x = await fixture({ real: true });
  try {
    const p = x.page;
    await p.goto(x.url);
    assert.equal(
      await p.locator("#statoo-pwa").count(),
      1,
      "PWA controls missing",
    );
    await p.waitForFunction(() => !!navigator.serviceWorker.controller);
    const cdp = await x.context.newCDPSession(p);
    const eligibility = await cdp.send("Page.getInstallabilityErrors");
    assert.deepEqual(
      eligibility.installabilityErrors,
      [],
      "Chrome must accept the manifest and icons",
    );
    await p.evaluate(async () => {
      localStorage.setItem("draft-test", "kept");
      await new Promise((resolve, reject) => {
        const req = indexedDB.open("pwa-persistence-test", 1);
        req.onupgradeneeded = () => req.result.createObjectStore("data");
        req.onerror = reject;
        req.onsuccess = () => {
          const db = req.result;
          const tx = db.transaction("data", "readwrite");
          tx.objectStore("data").put("kept", "record");
          tx.oncomplete = () => {
            db.close();
            resolve();
          };
        };
      });
    });
    x.deploy("v2");
    await p.evaluate(async () => {
      const reg = await navigator.serviceWorker.getRegistration();
      await reg.update();
    });
    await p.waitForFunction(
      () => document.querySelector("#statoo-pwa-update")?.hidden === false,
    );
    assert.equal(await p.locator("#version").innerText(), "v1");
    await p.locator("#statoo-pwa summary").click();
    await p
      .getByRole("button", { name: "Mettre à jour Statoo", exact: true })
      .click();
    await p
      .getByRole("button", { name: "Confirmer la mise à jour", exact: true })
      .click();
    await p.waitForFunction(
      () => document.querySelector("#version")?.textContent === "v2",
    );
    assert.equal(
      await p.evaluate(() => localStorage.getItem("draft-test")),
      "kept",
    );
    assert.equal(
      await p.evaluate(
        () =>
          new Promise((resolve) => {
            const r = indexedDB.open("pwa-persistence-test", 1);
            r.onsuccess = () => {
              const db = r.result;
              const q = db
                .transaction("data")
                .objectStore("data")
                .get("record");
              q.onsuccess = () => {
                db.close();
                resolve(q.result);
              };
            };
          }),
      ),
      "kept",
    );
    await x.context.setOffline(true);
    await p.reload();
    assert.equal(await p.locator("#version").innerText(), "v2");
    assert.equal(
      await p.evaluate(async () => {
        try {
          await fetch("/api/private");
          return true;
        } catch {
          return false;
        }
      }),
      false,
    );
  } finally {
    await x.close();
  }
});
test("PWAS-04/07/09 standalone, first activation, external activation and registration recovery", async () => {
  const x = await fixture();
  try {
    await x.context.addInitScript(() => {
      navigator.serviceWorker.controller = null;
      window.pwaTest.failRegister = true;
    });
    const p = x.page;
    await p.goto(x.url);
    await p.locator("#statoo-pwa summary").click();
    assert.match(
      await p.locator("#statoo-pwa-status").innerText(),
      /indisponible/,
    );
    await p.evaluate(() => {
      window.pwaTest.failRegister = false;
    });
    await p
      .getByRole("button", { name: "Vérifier les mises à jour", exact: true })
      .click();
    await p.getByLabel("Saisie en cours").fill("non validé");
    await p.evaluate(() => window.pwaTest.activate());
    assert.equal(
      await p.getByLabel("Saisie en cours").inputValue(),
      "non validé",
    );
    assert.equal(await p.locator("#statoo-pwa-update").isVisible(), false);
    await p.evaluate(() => window.pwaTest.activate());
    // The input remains intact until the user explicitly accepts reloading.
    assert.equal(
      await p.getByLabel("Saisie en cours").inputValue(),
      "non validé",
    );
    if (!(await p.locator("#statoo-pwa").evaluate((d) => d.open)))
      await p.locator("#statoo-pwa summary").click();
    assert.equal(await p.locator("#statoo-pwa-update").isVisible(), true);
    const standalone = await x.context.newPage();
    await standalone.addInitScript(() => {
      const original = window.matchMedia;
      window.matchMedia = (q) =>
        q === "(display-mode: standalone)"
          ? { matches: true, addEventListener() {} }
          : original(q);
    });
    await standalone.goto(x.url);
    await standalone.locator("#statoo-pwa summary").click();
    assert.equal(
      await standalone.locator("#statoo-pwa-install").isVisible(),
      false,
    );
    await standalone.close();
    const ios = await x.context.newPage();
    await ios.addInitScript(() =>
      Object.defineProperty(navigator, "userAgent", { value: "iPhone Safari" }),
    );
    await ios.goto(x.url);
    await ios.locator("#statoo-pwa summary").click();
    await ios
      .getByRole("button", { name: "Installer Statoo", exact: true })
      .click();
    assert.match(
      await ios.getByRole("dialog").innerText(),
      /Safari.*Partager/s,
    );
    await ios.close();
  } finally {
    await x.close();
  }
});
test("PWAS-15 download failure leaves v1 active with an actionable message", async () => {
  const x = await fixture({ real: true });
  try {
    const p = x.page;
    await p.goto(x.url);
    await p.waitForFunction(() => !!navigator.serviceWorker.controller);
    x.deploy("v2");
    x.setFailAssets(true);
    await p.locator("#statoo-pwa summary").click();
    await p
      .getByRole("button", { name: "Vérifier les mises à jour", exact: true })
      .click();
    await p.waitForFunction(
      () =>
        document
          .querySelector("#statoo-pwa-status")
          .textContent.includes("Téléchargement indisponible"),
      {},
      { timeout: 5000 },
    );
    assert.equal(await p.locator("#version").innerText(), "v1");
    assert.equal(await p.locator("#statoo-pwa-update").isVisible(), false);
  } finally {
    await x.close();
  }
});
test("PWAS-12 compact controls and dialogs reflow in both themes and large text", async () => {
  const x = await fixture();
  try {
    for (const theme of ["light", "dark"])
      for (const width of [320, 393])
        for (const scale of [1, 1.3, 2]) {
          const p = await x.context.newPage();
          await p.setViewportSize({ width, height: 852 });
          await p.emulateMedia({ colorScheme: theme });
          await p.goto(x.url);
          assert.equal(await p.locator("#statoo-pwa").count(), 1);
          await p.evaluate(
            (scale) =>
              (document.documentElement.style.fontSize = 16 * scale + "px"),
            scale,
          );
          assert.equal(
            await p.evaluate(() => {
              const command = document.createElement("button");
              command.textContent = "Passer";
              command.style.cssText =
                "position:fixed;right:8px;top:8px;width:70px;height:48px;z-index:50";
              document.body.append(command);
              const box = command.getBoundingClientRect();
              const reachable =
                document.elementFromPoint(
                  box.x + box.width / 2,
                  box.y + box.height / 2,
                ) === command;
              command.remove();
              return reachable;
            }),
            true,
            "Closed PWA menu must not intercept the right header action",
          );
          await p.locator("#statoo-pwa summary").click();
          assert.equal(
            await p.evaluate(
              () => document.documentElement.scrollWidth > innerWidth,
            ),
            false,
          );
          for (const button of await p
            .locator("#statoo-pwa button:visible")
            .all()) {
            const box = await button.boundingBox();
            assert.ok(box.height >= 48);
          }
          await p
            .getByRole("button", { name: "Installer Statoo", exact: true })
            .click();
          assert.equal(
            await p
              .getByRole("dialog")
              .evaluate((d) => d.scrollWidth > d.clientWidth),
            false,
          );
          await p.keyboard.press("Escape");
          assert.equal(await p.getByRole("dialog").count(), 0);
          if (width === 393 && scale === 1)
            await p.screenshot({ path: `${tmpdir()}/statoo-pwa-${theme}.png` });
          await p.close();
        }
  } finally {
    await x.close();
  }
});
