// PERF-005 (audit 14/11/2026) : le service worker Flutter précachait 47,5 Mo, dont des
// fichiers que l'app ne charge jamais (symboles de débogage, NOTICES, moteurs skwasm et
// wimp d'un build dart2js, variante webparagraph non demandée).
import test from "node:test";
import assert from "node:assert/strict";
import vm from "node:vm";
import {
  mkdtempSync,
  mkdirSync,
  writeFileSync,
  readFileSync,
  existsSync,
  rmSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { packageUniversal } from "../../scripts/package-universal-web.mjs";

const SCOPE = "https://statoo.example/";
const JS_BUILD = [
  { compileTarget: "dart2js", renderer: "canvaskit", mainJsPath: "main.dart.js" },
];
const WASM_BUILD = [
  { compileTarget: "dart2wasm", renderer: "skwasm", mainWasmPath: "main.dart.wasm", jsSupportRuntimePath: "main.dart.mjs" },
  ...JS_BUILD,
];

const CORE = [
  "index.html",
  "flutter_bootstrap.js",
  "flutter.js",
  "main.dart.js",
  "sqlite3.wasm",
  "sqflite_sw.js",
  "app-shell.js",
  "pwa-shell.css",
  "manifest.json",
  "version.json",
  "flutter_service_worker.js",
  "icons/icon-192.png",
  "icons/favicon.png",
  "icons/apple-touch-icon.png",
  "icons/icon-1024.png",
  "assets/AssetManifest.bin",
  "assets/AssetManifest.bin.json",
  "assets/FontManifest.json",
  "assets/fonts/MaterialIcons-Regular.otf",
  "assets/fonts/fallback/Roboto-Regular.ttf",
  "assets/assets/google_fonts/Poppins-Regular.ttf",
  "assets/assets/google_fonts/OFL.txt",
  "assets/assets/images/logo.jpg",
  "assets/packages/remixicon/fonts/remix.ttf",
  "assets/shaders/ink_sparkle.frag",
  // Les deux CanvasKit : chromium pour Chrome/Edge, complet pour Firefox/Safari.
  "canvaskit/canvaskit.js",
  "canvaskit/canvaskit.wasm",
  "canvaskit/chromium/canvaskit.js",
  "canvaskit/chromium/canvaskit.wasm",
];
const SYMBOLS = [
  "canvaskit/canvaskit.js.symbols",
  "canvaskit/chromium/canvaskit.js.symbols",
  "canvaskit/skwasm.js.symbols",
  "canvaskit/skwasm_heavy.js.symbols",
  "canvaskit/wimp.js.symbols",
  "canvaskit/webparagraph/canvaskit.js.symbols",
];
const SKWASM = [
  "canvaskit/skwasm.js",
  "canvaskit/skwasm.wasm",
  "canvaskit/skwasm_heavy.js",
  "canvaskit/skwasm_heavy.wasm",
];
const WIMP = ["canvaskit/wimp.js", "canvaskit/wimp.wasm"];
const WEBPARAGRAPH = [
  "canvaskit/webparagraph/canvaskit.js",
  "canvaskit/webparagraph/canvaskit.wasm",
];
const NEVER = [...SYMBOLS, "assets/NOTICES"];

function bootstrap({ builds = JS_BUILD, config = "" } = {}) {
  // Forme réelle : le loader minifié mentionne preferWebParagraph et enableWimp sans les activer.
  return [
    "(()=>{let o=e.preferWebParagraph&&s.hasTextCluster,i=e.enableWimp?\"wimp\":\"skwasm\"})();",
    `if (!window._flutter) { window._flutter = {}; }`,
    `_flutter.buildConfig = ${JSON.stringify({ engineRevision: "abc", builds, useLocalCanvasKit: true })};`,
    `_flutter.loader.load({ config: { canvasKitBaseUrl: "canvaskit/"${config} } });`,
  ].join("\n");
}

function withBuild(options, run) {
  const root = mkdtempSync(join(tmpdir(), "statoo-precache-"));
  try {
    const build = join(root, "build");
    const output = join(root, "output");
    const extra = options.extra ?? [];
    for (const file of [...CORE, ...NEVER, ...SKWASM, ...WIMP, ...WEBPARAGRAPH, ...extra]) {
      mkdirSync(dirname(join(build, file)), { recursive: true });
      writeFileSync(join(build, file), `contenu ${file}`);
    }
    writeFileSync(join(build, "flutter_bootstrap.js"), options.bootstrap ?? bootstrap(options));
    return run({ build, output, root });
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

function worker(output) {
  const listeners = {};
  const added = [];
  const opened = {
    addAll: async (requests) => added.push(...requests.map((r) => r.url)),
    match: async () => undefined,
  };
  const context = {
    self: {
      registration: { scope: SCOPE },
      addEventListener: (type, listener) => (listeners[type] = listener),
      skipWaiting() {},
      clients: { claim: async () => {} },
    },
    caches: { open: async () => opened, keys: async () => [], delete: async () => true, match: async () => undefined },
    Request: class { constructor(url) { this.url = url; } },
    URL,
    Set,
    fetch: async () => ({}),
  };
  vm.runInNewContext(readFileSync(join(output, "sw.js"), "utf8"), context);
  return {
    async precached() {
      let done;
      listeners.install({ waitUntil: (promise) => (done = promise) });
      await done;
      return added.map((url) => url.slice(SCOPE.length)).sort();
    },
    intercepts(path) {
      let answered = false;
      listeners.fetch({
        request: { method: "GET", url: SCOPE + path, mode: "no-cors", headers: { has: () => false } },
        respondWith: () => (answered = true),
      });
      return answered;
    },
  };
}

test("PERF005-01 un build dart2js ne précache que les fichiers que l'app peut charger", async () => {
  await withBuild({}, async ({ build, output }) => {
    packageUniversal({ build, legacy: join(build, "absent"), output });
    assert.deepEqual(await worker(output).precached(), [...CORE].sort());
  });
});

test("PERF005-02 symboles, NOTICES et moteurs inutiles restent publiés mais hors précache", async () => {
  await withBuild({}, async ({ build, output }) => {
    packageUniversal({ build, legacy: join(build, "absent"), output });
    const sw = worker(output);
    for (const file of [...NEVER, ...SKWASM, ...WIMP, ...WEBPARAGRAPH]) {
      assert.ok(existsSync(join(output, file)), `${file} doit rester téléchargeable`);
      assert.equal(sw.intercepts(file), false, `${file} ne doit pas être servi depuis le cache`);
    }
    for (const file of ["main.dart.js", "canvaskit/chromium/canvaskit.wasm", "canvaskit/canvaskit.wasm"])
      assert.equal(sw.intercepts(file), true, file);
  });
});

test("PERF005-03 un build wasm garde skwasm et skwasm_heavy, sans wimp ni symboles", async () => {
  const extra = ["main.dart.wasm", "main.dart.mjs"];
  await withBuild({ builds: WASM_BUILD, extra }, async ({ build, output }) => {
    packageUniversal({ build, legacy: join(build, "absent"), output });
    assert.deepEqual(await worker(output).precached(), [...CORE, ...SKWASM, ...extra].sort());
  });
});

test("PERF005-04 wimp est précaché seulement si enableWimp est activé sur un build wasm", async () => {
  await withBuild({ builds: WASM_BUILD, config: ", enableWimp: true" }, async ({ build, output }) => {
    packageUniversal({ build, legacy: join(build, "absent"), output });
    const files = await worker(output).precached();
    for (const file of WIMP) assert.ok(files.includes(file), file);
  });
  await withBuild({ config: ", enableWimp: true" }, async ({ build, output }) => {
    packageUniversal({ build, legacy: join(build, "absent"), output });
    const files = await worker(output).precached();
    for (const file of WIMP) assert.ok(!files.includes(file), `${file} sans renderer skwasm`);
  });
});

test("PERF005-05 webparagraph est précaché seulement si preferWebParagraph est activé", async () => {
  await withBuild({ config: ", preferWebParagraph: true" }, async ({ build, output }) => {
    packageUniversal({ build, legacy: join(build, "absent"), output });
    const files = await worker(output).precached();
    for (const file of WEBPARAGRAPH) assert.ok(files.includes(file), file);
  });
});

test("PERF005-06 un buildConfig introuvable ou illisible arrête le packaging", () => {
  for (const broken of ["_flutter.loader.load({});", "_flutter.buildConfig = {builds:[;"]) {
    withBuild({ bootstrap: broken }, ({ build, output }) => {
      assert.throws(
        () => packageUniversal({ build, legacy: join(build, "absent"), output }),
        /buildConfig/,
      );
    });
  }
});

test("PERF005-07 la version du cache ignore les fichiers hors précache", () => {
  withBuild({}, ({ build, output }) => {
    const first = packageUniversal({ build, legacy: join(build, "absent"), output }).version;
    writeFileSync(join(build, "canvaskit/skwasm.js.symbols"), "autre");
    writeFileSync(join(build, "assets/NOTICES"), "autre");
    assert.equal(packageUniversal({ build, legacy: join(build, "absent"), output }).version, first);
    writeFileSync(join(build, "main.dart.js"), "nouvelle version");
    assert.notEqual(packageUniversal({ build, legacy: join(build, "absent"), output }).version, first);
  });
});

test("PERF005-08 un buildConfig vide ou non JSON arrête aussi le packaging", () => {
  for (const broken of [
    '_flutter.buildConfig = {builds:[]};',
    '_flutter.buildConfig = {"builds":[]};',
  ]) {
    withBuild({ bootstrap: broken }, ({ build, output }) => {
      assert.throws(
        () => packageUniversal({ build, legacy: join(build, "absent"), output }),
        /buildConfig/,
      );
    });
  }
});

test("PERF005-09 une option du loader écrite autrement que `true`/`false` arrête le packaging", () => {
  // Revue : une forme non reconnue sortirait webparagraph ou wimp du précache sans signal.
  for (const config of [
    ", preferWebParagraph: !0",
    ", preferWebParagraph: choix",
    ", enableWimp: 1",
  ]) {
    withBuild({ builds: WASM_BUILD, config }, ({ build, output }) => {
      assert.throws(
        () => packageUniversal({ build, legacy: join(build, "absent"), output }),
        /preferWebParagraph|enableWimp/,
        config,
      );
    });
  }
});

test("PERF005-10 `false` explicite garde l'option désactivée", async () => {
  await withBuild(
    { builds: WASM_BUILD, config: ", preferWebParagraph: false, enableWimp: false" },
    async ({ build, output }) => {
      packageUniversal({ build, legacy: join(build, "absent"), output });
      const files = await worker(output).precached();
      for (const file of [...WIMP, ...WEBPARAGRAPH]) assert.ok(!files.includes(file), file);
    },
  );
});

test("PERF005-11 une clé entre guillemets est reconnue", async () => {
  await withBuild(
    { builds: WASM_BUILD, config: ', "preferWebParagraph": true, \'enableWimp\': true' },
    async ({ build, output }) => {
      packageUniversal({ build, legacy: join(build, "absent"), output });
      const files = await worker(output).precached();
      for (const file of [...WIMP, ...WEBPARAGRAPH]) assert.ok(files.includes(file), file);
    },
  );
});
