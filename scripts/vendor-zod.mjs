import { build } from "esbuild";
import { mkdirSync, copyFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
const root = fileURLToPath(new URL("../", import.meta.url));
mkdirSync(new URL("../web/vendor/", import.meta.url), { recursive: true });
await build({
  stdin: {
    contents:
      'export { object, string, number, boolean, array, record, enum as enumeration, preprocess, union, literal, unknown, ZodError } from "zod";',
    resolveDir: root,
    sourcefile: "zod-browser-entry.mjs",
  },
  bundle: true,
  format: "esm",
  platform: "browser",
  target: "es2022",
  minify: true,
  legalComments: "eof",
  outfile: fileURLToPath(new URL("../web/vendor/zod.mjs", import.meta.url)),
});
copyFileSync(
  new URL("../node_modules/zod/LICENSE", import.meta.url),
  new URL("../web/vendor/ZOD-LICENSE.txt", import.meta.url),
);
