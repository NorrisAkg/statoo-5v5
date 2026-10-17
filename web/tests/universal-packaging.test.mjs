import test from "node:test";
import assert from "node:assert/strict";
import {
  mkdtempSync,
  mkdirSync,
  writeFileSync,
  readFileSync,
  existsSync,
  rmSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

test("PAR17/20 universal package includes SQLite, offline shell and legacy portal without secrets", async () => {
  const moduleUrl = new URL(
    "../../scripts/package-universal-web.mjs",
    import.meta.url,
  );
  assert.ok(existsSync(moduleUrl), "Universal packaging must exist");
  const { packageUniversal } = await import(moduleUrl);
  const root = mkdtempSync(join(tmpdir(), "statoo-parity-"));
  try {
    const build = join(root, "build"),
      legacy = join(root, "legacy"),
      output = join(root, "output");
    mkdirSync(build);
    mkdirSync(legacy);
    for (const file of [
      "index.html",
      "flutter_bootstrap.js",
      "main.dart.js",
      "sqlite3.wasm",
      "sqflite_sw.js",
    ])
      writeFileSync(join(build, file), "test");
    writeFileSync(join(legacy, "index.html"), "legacy");
    writeFileSync(join(root, ".env"), "PRIVATE=secret");
    packageUniversal({ build, legacy, output });
    assert.equal(
      readFileSync(join(output, "portal/index.html"), "utf8"),
      "legacy",
    );
    assert.ok(existsSync(join(output, "sqlite3.wasm")));
    const worker = readFileSync(join(output, "sw.js"), "utf8");
    assert.ok(worker.includes("main.dart.js"));
    assert.ok(!worker.includes("portal/index.html"));
    assert.ok(!worker.includes("/groups"));
    assert.equal(existsSync(join(output, ".env")), false);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
