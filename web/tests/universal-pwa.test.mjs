import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync, existsSync } from "node:fs";
import vm from "node:vm";
const root = new URL("../../mobile/web/", import.meta.url);
test("PWAS-16 Flutter loads the bundled rendering engine on the same origin", () => {
  const source = readFileSync(new URL("flutter_bootstrap.js", root), "utf8")
    .replace("{{flutter_js}}", "")
    .replace("{{flutter_build_config}}", "");
  let options;
  vm.runInNewContext(source, {
    URL,
    document: { baseURI: "https://example.test/statoo/" },
    _flutter: {
      loader: {
        load: (value) => {
          options = value;
        },
      },
    },
  });
  assert.equal(
    options.config?.canvasKitBaseUrl,
    "https://example.test/statoo/canvaskit/",
  );
});
test("PWAS-01 Flutter web includes install metadata and real existing logo assets", () => {
  const manifest = JSON.parse(
    readFileSync(new URL("manifest.json", root), "utf8"),
  );
  assert.equal(manifest.display, "standalone");
  assert.equal(manifest.scope, "./");
  assert.equal(manifest.start_url, "./");
  for (const size of [192, 1024]) {
    const icon = manifest.icons.find((i) => i.sizes === `${size}x${size}`);
    assert.ok(icon, `Icon ${size} missing`);
    const buffer = readFileSync(new URL(icon.src, root));
    assert.equal(buffer.readUInt32BE(16), size);
    assert.equal(buffer.readUInt32BE(20), size);
  }
  const html = readFileSync(new URL("index.html", root), "utf8");
  assert.match(html, /apple-touch-icon/);
  assert.match(html, /rel="icon"/);
  assert.match(html, /pwa-shell\.css/);
  assert.ok(existsSync(new URL("pwa-shell.css", root)));
});
