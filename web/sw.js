const SCOPE = new URL(self.registration.scope);
const PREFIX = "statoo-shell:" + SCOPE.pathname + ":";
const CACHE = PREFIX + "2026-10-15-7";
const SHELL = [
  "./",
  "index.html",
  "app.mjs",
  "config.mjs",
  "registration-draft.mjs",
  "config.json",
  "client.mjs",
  "domain.mjs",
  "summary.mjs",
  "pwa.mjs",
  "styles.css",
  "manifest.webmanifest",
  "team-names.json",
  "icons/icon-192.png",
  "icons/logo.jpg",
  "icons/logo-transparent.png",
  "icons/favicon.png",
  "icons/icon-1024.png",
  "icons/apple-touch-icon.png",
  "fonts/Poppins-Regular.ttf",
  "fonts/Poppins-SemiBold.ttf",
];
const ALLOWED = new Set(SHELL.map((path) => new URL(path, SCOPE).href));
self.addEventListener("install", (event) =>
  event.waitUntil(
    caches.open(CACHE).then((cache) => cache.addAll([...ALLOWED])),
  ),
);
self.addEventListener("activate", (event) =>
  event.waitUntil(
    (async () => {
      for (const key of await caches.keys())
        if (key.startsWith(PREFIX) && key !== CACHE) await caches.delete(key);
      await self.clients.claim();
    })(),
  ),
);
self.addEventListener("message", (event) => {
  if (event.data?.type === "SKIP_WAITING") self.skipWaiting();
});
self.addEventListener("fetch", (event) => {
  const request = event.request,
    url = new URL(request.url);
  if (
    request.method !== "GET" ||
    request.headers.has("Authorization") ||
    url.origin !== SCOPE.origin ||
    !ALLOWED.has(url.href)
  )
    return;
  event.respondWith(
    (async () => {
      const cache = await caches.open(CACHE);
      if (request.mode === "navigate") {
        try {
          return await fetch(request);
        } catch {
          return (
            (await cache.match(new URL("index.html", SCOPE).href)) ||
            Response.error()
          );
        }
      }
      // Public, same-origin allowlisted assets can vary by Origin on the API host.
      // Module/font requests include Origin whereas addAll's requests may not.
      return (
        (await cache.match(request, { ignoreVary: true })) || fetch(request)
      );
    })(),
  );
});
