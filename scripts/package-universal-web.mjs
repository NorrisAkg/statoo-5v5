import {
  cpSync,
  existsSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  writeFileSync,
} from "node:fs";
import { join, relative, resolve } from "node:path";
import { createHash } from "node:crypto";
import { fileURLToPath } from "node:url";

const projectRoot = resolve(fileURLToPath(import.meta.url), "../..");

// PERF-005 : le précache ne contient que ce que l'app peut charger. Les fichiers exclus
// restent publiés et passent par le réseau. Les choix du loader Flutter
// (flutter_bootstrap.js) sont relus depuis `_flutter.buildConfig` et la config `load`.
export function precacheRules(bootstrap) {
  const match = /_flutter\.buildConfig\s*=\s*(\{.*?\});\s*$/m.exec(bootstrap);
  let builds;
  try {
    builds = JSON.parse(match?.[1] ?? "null")?.builds;
  } catch {}
  if (!Array.isArray(builds) || builds.length === 0)
    throw Error("flutter_bootstrap.js: _flutter.buildConfig introuvable ou illisible");
  const renderers = new Set(builds.map((build) => build.renderer));
  // Toute affectation de l'option doit valoir `true` ou `false` littéral : une autre forme
  // (`!0`, variable…) sortirait des fichiers nécessaires du précache sans signal.
  const enabled = (option) => {
    const pattern = new RegExp(`["']?\\b${option}\\b["']?\\s*:\\s*([^,}\\s]*)`, "g");
    const values = [...bootstrap.matchAll(pattern)].map((match) => match[1]);
    for (const value of values)
      if (value !== "true" && value !== "false")
        throw Error(`flutter_bootstrap.js: ${option} vaut « ${value} », écrire true ou false`);
    return values.includes("true");
  };
  const skwasm = renderers.has("skwasm");
  const canvaskit = renderers.has("canvaskit");
  const wimp = enabled("enableWimp");
  const webParagraph = enabled("preferWebParagraph");
  return (file) => {
    if (file.endsWith(".symbols") || file === "assets/NOTICES") return false;
    if (!file.startsWith("canvaskit/")) return true;
    const name = file.slice("canvaskit/".length);
    if (/^skwasm(_heavy)?\.(js|wasm)$/.test(name)) return skwasm;
    if (/^wimp\.(js|wasm)$/.test(name)) return skwasm && wimp;
    if (name.startsWith("webparagraph/")) return canvaskit && webParagraph;
    if (/^(chromium\/)?canvaskit\.(js|wasm)$/.test(name)) return canvaskit;
    return true;
  };
}

export function packageUniversal({
  build = "mobile/build/web",
  legacy = "web/dist",
  landing = resolve(projectRoot, "web/landing.html"),
  output = "web/universal-dist",
} = {}) {
  for (const file of [
    "index.html",
    "flutter_bootstrap.js",
    "main.dart.js",
    "sqlite3.wasm",
    "sqflite_sw.js",
  ]) {
    if (!existsSync(join(build, file)))
      throw Error("Missing Flutter web asset: " + file);
  }
  // Validée avant toute copie : une configuration refusée ne laisse pas de sortie partielle.
  const precached = precacheRules(
    readFileSync(join(build, "flutter_bootstrap.js"), "utf8"),
  );
  mkdirSync(output, { recursive: true });
  cpSync(build, output, { recursive: true });

  // Expose Flutter web app directly under app.html and app/index.html so Vercel cleanUrls can serve /app
  cpSync(join(build, "index.html"), join(output, "app.html"));
  mkdirSync(join(output, "app"), { recursive: true });
  cpSync(join(build, "index.html"), join(output, "app/index.html"));

  // Serve landing page directly at the root index.html and landing.html (200 OK, no redirect)
  if (existsSync(landing)) {
    cpSync(landing, join(output, "landing.html"));
    cpSync(landing, join(output, "index.html"));
  }

  if (existsSync(legacy))
    cpSync(legacy, join(output, "portal"), { recursive: true });

  const logoSource = resolve(projectRoot, "web/icons/logo-transparent.png");
  const logoTarget = join(output, "icons/logo-transparent.png");
  if (existsSync(logoSource) && !existsSync(logoTarget)) {
    mkdirSync(join(output, "icons"), { recursive: true });
    cpSync(logoSource, logoTarget);
  }
  const files = [];
  const hash = createHash("sha256");
  function visit(directory) {
    for (const entry of readdirSync(directory, { withFileTypes: true })) {
      if (entry.name.startsWith(".") || entry.name.endsWith(".map")) continue;
      const path = join(directory, entry.name);
      if (entry.isDirectory()) visit(path);
      else {
        const file = relative(build, path).replaceAll("\\", "/");
        if (!precached(file)) continue;
        files.push(file);
        hash.update(file + "\0");
        hash.update(readFileSync(path));
      }
    }
  }
  visit(build);
  if (existsSync(join(output, "landing.html")) && !files.includes("landing.html")) {
    files.push("landing.html");
    hash.update(readFileSync(join(output, "landing.html")));
  }
  if (existsSync(join(output, "app.html")) && !files.includes("app.html")) {
    files.push("app.html");
    hash.update(readFileSync(join(output, "app.html")));
  }
  if (
    existsSync(join(output, "icons/logo-transparent.png")) &&
    !files.includes("icons/logo-transparent.png")
  ) {
    files.push("icons/logo-transparent.png");
    hash.update(readFileSync(join(output, "icons/logo-transparent.png")));
  }
  const version = hash.digest("hex").slice(0, 16);
  const worker = `const CACHE='statoo-universal:${version}';
const ROOT=self.registration.scope;
const FILES=${JSON.stringify(files)};
const ALLOWED=new Set(FILES.map(f=>new URL(f,ROOT).href));
self.addEventListener('install',e=>e.waitUntil(caches.open(CACHE).then(c=>c.addAll([...ALLOWED].map(url=>new Request(url,{cache:'reload'}))))));
self.addEventListener('activate',e=>e.waitUntil((async()=>{for(const k of await caches.keys())if(k.startsWith('statoo-universal:')&&k!==CACHE)await caches.delete(k);await self.clients.claim();})()));
self.addEventListener('message',e=>{if(e.data?.type==='SKIP_WAITING')self.skipWaiting();});
self.addEventListener('fetch',e=>{
  const r=e.request;
  if(r.method!=='GET'||r.headers.has('Authorization'))return;
  const u=new URL(r.url);
  if(r.mode==='navigate'){
    if(u.pathname==='/app'||u.pathname.startsWith('/app/')){
      e.respondWith(caches.open(CACHE).then(async c=>(await c.match(new URL('app.html',ROOT).href))||fetch(r)).catch(()=>fetch(r)));
      return;
    }
    if(u.pathname==='/'||u.pathname==='/landing'||u.pathname==='/landing.html'||u.pathname==='/telecharger'){
      e.respondWith(caches.open(CACHE).then(async c=>(await c.match(new URL('index.html',ROOT).href))||(await c.match(new URL('landing.html',ROOT).href))||fetch(r)).catch(()=>fetch(r)));
      return;
    }
  }
  if(!ALLOWED.has(u.href))return;
  e.respondWith(caches.open(CACHE).then(async c=>(await c.match(r))||fetch(r)).catch(()=>fetch(r)));
});
`;
  writeFileSync(join(output, "sw.js"), worker);
  return { version, assets: files.length, output };
}
if (
  process.argv[1] &&
  resolve(process.argv[1]) === fileURLToPath(import.meta.url)
)
  console.log(packageUniversal());
