import test from "node:test";
import assert from "node:assert/strict";
import {
  mkdtempSync,
  mkdirSync,
  cpSync,
  readdirSync,
  readFileSync,
  existsSync,
  rmSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

test("STAB-08 a clean static package contains every application module", () => {
  const directory = mkdtempSync(join(tmpdir(), "statoo-package-"));
  const source = fileURLToPath(new URL("../../", import.meta.url));
  try {
    mkdirSync(join(directory, "scripts"));
    mkdirSync(join(directory, "web/tests"), { recursive: true });
    cpSync(join(source, "scripts/app.mjs"), join(directory, "scripts/app.mjs"));
    for (const file of readdirSync(join(source, "web"))) {
      if (["tests", "dist"].includes(file)) continue;
      cpSync(join(source, "web", file), join(directory, "web", file), {
        recursive: true,
      });
    }
    const built = spawnSync(
      process.execPath,
      ["scripts/app.mjs", "build-web"],
      {
        cwd: directory,
        encoding: "utf8",
        timeout: 30000,
        env: { ...process.env, STATOO_PUBLIC_API_URL: "" },
      },
    );
    assert.equal(built.status, 0, built.stderr + built.stdout);
    const visited = new Set();
    function inspect(path) {
      assert.ok(
        existsSync(path),
        `Module importé absent du portail statique : ${path}`,
      );
      if (visited.has(path)) return;
      visited.add(path);
      const script = readFileSync(path, "utf8");
      for (const match of script.matchAll(
        /(?:from\s*|import\s*)["'](\.\.?\/[^"']+\.mjs)["']/g,
      ))
        inspect(resolve(dirname(path), match[1]));
    }
    inspect(join(directory, "web/dist/app.mjs"));
    assert.ok(
      visited.size > 1,
      "Le parcours des imports doit inspecter les dépendances du portail.",
    );
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});
