import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { chromium } from "playwright";
const root = new URL("../../mobile/web/", import.meta.url);
const html = readFileSync(new URL("index.html", root), "utf8");

test("IOS-01/02/03 semantic fields have safe font sizes before focus without changing other fields", async () => {
  const browser = await chromium.launch({ channel: "chrome", headless: true });
  try {
    const page = await browser.newPage({
      viewport: { width: 390, height: 844 },
      deviceScaleFactor: 3,
    });
    // Chromium lacks the iOS feature query: activate just its body to test the rule.
    const css = readFileSync(new URL("pwa-shell.css", root), "utf8").replace(
      /@supports\s*\(-webkit-touch-callout:\s*none\)/g,
      "@media all",
    );
    await page.setContent(
      `<style>input,textarea{font-size:11px}</style><style>${css}</style><flutter-view><flt-semantics-host><flt-semantics><input data-semantics-role="text-field" aria-label="Nom"><input type="password" data-semantics-role="text-field"><input type="number" data-semantics-role="text-field"><textarea data-semantics-role="text-field"></textarea></flt-semantics></flt-semantics-host></flutter-view><input id="outside">`,
    );
    for (const element of await page
      .locator('[data-semantics-role="text-field"]')
      .all())
      assert.ok(
        (await element.evaluate((e) =>
          parseFloat(getComputedStyle(e).fontSize),
        )) >= 16,
        "semantic font must prevent iOS focus auto-zoom",
      );
    await page
      .getByRole("textbox", { name: "Nom", exact: true })
      .fill("Équipe de test");
    await page.locator("#outside").focus();
    assert.equal(
      await page
        .getByRole("textbox", { name: "Nom", exact: true })
        .inputValue(),
      "Équipe de test",
    );
    assert.equal(
      await page
        .locator("#outside")
        .evaluate((e) => getComputedStyle(e).fontSize),
      "11px",
    );
    await page
      .locator("flt-semantics")
      .evaluate((e) =>
        e.insertAdjacentHTML(
          "beforeend",
          '<textarea data-semantics-role="text-field" id="late"></textarea>',
        ),
      );
    assert.ok(
      (await page
        .locator("#late")
        .evaluate((e) => parseFloat(getComputedStyle(e).fontSize))) >= 16,
    );
  } finally {
    await browser.close();
  }
});

test("IOS-04/05 accessibility, browser zoom and early stylesheet are retained", () => {
  assert.match(html, /pwa-shell\.css/);
  assert.ok(
    html.indexOf("pwa-shell.css") < html.indexOf("flutter_bootstrap.js"),
  );
  const css = readFileSync(new URL("pwa-shell.css", root), "utf8");
  assert.match(css, /@supports\s*\(-webkit-touch-callout:\s*none\)/);
  assert.doesNotMatch(
    css,
    /user-scalable\s*[:=]\s*no|maximum-scale\s*[:=]\s*1/,
  );
  assert.doesNotMatch(html, /user-scalable=no|maximum-scale=1/);
  assert.match(
    readFileSync(new URL("../lib/main_web.dart", root), "utf8"),
    /ensureSemantics\(\)/,
  );
});
