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

export function packageUniversal({
  build = "mobile/build/web",
  legacy = "web/dist",
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
  mkdirSync(output, { recursive: true });
  cpSync(build, output, { recursive: true });
  if (existsSync(legacy))
    cpSync(legacy, join(output, "portal"), { recursive: true });
  const files = [];
  const hash = createHash("sha256");
  function visit(directory) {
    for (const entry of readdirSync(directory, { withFileTypes: true })) {
      if (entry.name.startsWith(".") || entry.name.endsWith(".map")) continue;
      const path = join(directory, entry.name);
      if (entry.isDirectory()) visit(path);
      else {
        files.push(relative(build, path).replaceAll("\\", "/"));
        hash.update(readFileSync(path));
      }
    }
  }
  visit(build);
  const version = hash.digest("hex").slice(0, 16);
  const worker = `const CACHE='statoo-universal:${version}';
const ROOT=self.registration.scope;
const FILES=${JSON.stringify(files)};
const ALLOWED=new Set(FILES.map(f=>new URL(f,ROOT).href));
self.addEventListener('install',e=>e.waitUntil(caches.open(CACHE).then(c=>c.addAll([...ALLOWED]))));
self.addEventListener('activate',e=>e.waitUntil((async()=>{for(const k of await caches.keys())if(k.startsWith('statoo-universal:')&&k!==CACHE)await caches.delete(k);await self.clients.claim();})()));
self.addEventListener('message',e=>{if(e.data?.type==='SKIP_WAITING')self.skipWaiting();});
self.addEventListener('fetch',e=>{const r=e.request;if(r.method!=='GET'||r.headers.has('Authorization'))return;const u=new URL(r.url);if(r.mode==='navigate'&&u.href===ROOT){e.respondWith(caches.open(CACHE).then(c=>c.match(new URL('index.html',ROOT).href)));return;}if(!ALLOWED.has(u.href))return;e.respondWith(caches.open(CACHE).then(async c=>(await c.match(r))||fetch(r)));});
`;
  writeFileSync(join(output, "sw.js"), worker);
  return { version, assets: files.length, output };
}
if (
  process.argv[1] &&
  resolve(process.argv[1]) === fileURLToPath(import.meta.url)
)
  console.log(packageUniversal());
