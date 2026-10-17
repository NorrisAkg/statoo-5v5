import test from "node:test";
import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";

const root = new URL("../../", import.meta.url);
const configFile = new URL("vercel.json", root);
const config = existsSync(configFile)
  ? JSON.parse(readFileSync(configFile, "utf8"))
  : {};
const pkg = JSON.parse(readFileSync(new URL("package.json", root), "utf8"));

test("VER-01 Vercel uses the plain static site preset", () => {
  assert.equal(config.framework, null, "Select Other instead of Nuxt");
});

test("VER-02 Vercel publishes the shared Flutter web app and retains the legacy portal", () => {
  assert.equal(config.buildCommand, "bash scripts/build-universal-web.sh");
  assert.equal(config.outputDirectory, "web/universal-dist");
  assert.equal(pkg.scripts["build:web"], "node scripts/app.mjs build-web");
});

test("VER-03 a clean deployment installs from the root lockfile", () => {
  assert.equal(config.installCommand, "npm ci");
  const lock = JSON.parse(readFileSync(new URL("package-lock.json", root), "utf8"));
  assert.deepEqual(lock.packages[""].dependencies, pkg.dependencies);
  assert.deepEqual(lock.packages[""].devDependencies, pkg.devDependencies);
});
