import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync, existsSync } from "node:fs";
const file = (name) => new URL("../" + name, import.meta.url);
test("DESK-01/05 existing logo and favicon are integrated locally", () => {
  const html = readFileSync(file("index.html"), "utf8");
  assert.equal(
    html.includes("brand-icon"),
    false,
    "Replace the placeholder with the real logo",
  );
  assert.ok(existsSync(file("icons/logo.jpg")));
  assert.deepEqual(
    readFileSync(file("icons/logo.jpg")),
    readFileSync(
      new URL("../../mobile/assets/images/logo.jpg", import.meta.url),
    ),
  );
  assert.match(html, /rel="icon"[^>]*href="icons\/logo-transparent\.png"/);
  assert.deepEqual(
    readFileSync(file("icons/favicon.png")),
    readFileSync(
      new URL(
        "../../mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png",
        import.meta.url,
      ),
    ),
  );
  const worker = readFileSync(file("sw.js"), "utf8");
  assert.match(worker, /icons\/logo\.jpg/);
  assert.match(worker, /icons\/favicon\.png/);
});
