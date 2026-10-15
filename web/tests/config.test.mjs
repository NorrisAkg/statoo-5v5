import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
const source = readFileSync(new URL("../app.mjs", import.meta.url), "utf8");
test("CFG-01 login and registration never ask for the API address", () => {
  assert.equal(source.includes("Adresse de l’API"), false);
  assert.equal(source.includes("form.append(server)"), false);
});
test("CFG-02/03/04 configuration resolves safely", async () => {
  // Import only after the behavior assertion so RED is not a missing-module failure.
  assert.match(
    source,
    /apiAddress/,
    "Application must use the deployment configuration",
  );
  const { apiAddress } = await import("../config.mjs");
  assert.equal(apiAddress({}, "https://site.test"), "https://site.test");
  assert.equal(
    apiAddress({ api_url: "" }, "https://site.test"),
    "https://site.test",
  );
  assert.equal(
    apiAddress({ api_url: " https://api.test/prefix/ " }, "https://site.test"),
    "https://api.test/prefix",
  );
  for (const api_url of [
    "ftp://api.test",
    "javascript:alert(1)",
    "no-url",
    "https://a:b@api.test",
    "https://api.test?q=x",
    "https://api.test/#x",
  ])
    assert.throws(() => apiAddress({ api_url }, "https://site.test"));
});
test("CFG-06/07 build and offline shell include only public config", () => {
  const build = readFileSync(
    new URL("../../scripts/app.mjs", import.meta.url),
    "utf8",
  );
  const worker = readFileSync(new URL("../sw.js", import.meta.url), "utf8");
  assert.match(build, /STATOO_PUBLIC_API_URL/);
  assert.match(build, /loadEnvFile/);
  assert.match(worker, /config\.json/);
  assert.match(worker, /config\.mjs/);
});
