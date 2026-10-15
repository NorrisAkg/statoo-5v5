import test from "node:test";
import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import vm from "node:vm";
const file = (name) =>
  readFileSync(new URL("../" + name, import.meta.url), "utf8");
test("PWA-01/02 installable shell exists at root and under /portal/", () => {
  assert.ok(
    existsSync(new URL("../manifest.webmanifest", import.meta.url)),
    "manifest missing",
  );
  const manifest = JSON.parse(file("manifest.webmanifest"));
  assert.equal(manifest.lang, "fr");
  assert.equal(manifest.display, "standalone");
  for (const base of [
    "https://example.test/",
    "https://example.test/portal/",
  ]) {
    assert.equal(
      new URL(manifest.start_url, base).pathname,
      new URL("./", base).pathname,
    );
    assert.equal(
      new URL(manifest.scope, base).pathname,
      new URL("./", base).pathname,
    );
  }
  for (const size of [192, 1024]) {
    const icon = manifest.icons.find((i) => i.sizes === `${size}x${size}`);
    assert.ok(icon);
    const buffer = readFileSync(new URL("../" + icon.src, import.meta.url));
    assert.equal(buffer.readUInt32BE(16), size);
    assert.equal(buffer.readUInt32BE(20), size);
  }
  assert.match(file("index.html"), /rel="manifest"/);
});
test("PWA-04/05 worker caches shell but never API or auth responses", async () => {
  assert.ok(existsSync(new URL("../sw.js", import.meta.url)), "worker missing");
  const handlers = {},
    puts = [];
  let network = 0;
  const cache = {
    addAll: async () => {},
    match: async () => null,
    put: async (...args) => puts.push(args),
  };
  vm.runInNewContext(file("sw.js"), {
    URL,
    Response,
    Request,
    Promise,
    console,
    self: {
      registration: { scope: "https://example.test/portal/" },
      location: { href: "https://example.test/portal/sw.js" },
      addEventListener: (name, handler) => (handlers[name] = handler),
      clients: { claim: async () => {} },
    },
    caches: {
      open: async () => cache,
      match: async () => null,
      keys: async () => [],
      delete: async () => {},
    },
    fetch: async () => {
      network++;
      return new Response("ok");
    },
  });
  for (const url of [
    "https://example.test/groups/g",
    "https://remote.test/groups/g",
    "https://example.test/auth/login",
  ]) {
    let intercepted = false;
    handlers.fetch({
      request: new Request(url),
      respondWith: () => (intercepted = true),
    });
    assert.equal(intercepted, false);
  }
  let response;
  handlers.fetch({
    request: new Request("https://example.test/portal/styles.css"),
    respondWith: (p) => (response = p),
  });
  await response;
  assert.equal(network, 1);
  assert.equal(puts.length, 0);
});

test("PWA-06 activation removes only older Statoo caches in the same scope", async () => {
  const handlers = {},
    deleted = [];
  let claimed = false,
    installed = [];
  const cache = { addAll: async (urls) => (installed = urls) };
  vm.runInNewContext(file("sw.js"), {
    URL,
    Response,
    Request,
    Promise,
    console,
    self: {
      registration: { scope: "https://example.test/portal/" },
      addEventListener: (name, handler) => (handlers[name] = handler),
      clients: { claim: async () => (claimed = true) },
    },
    caches: {
      open: async () => cache,
      keys: async () => [
        "other-app",
        "statoo-shell:/other/:old",
        "statoo-shell:/portal/:old",
        "statoo-shell:/portal/:2026-10-15-7",
      ],
      delete: async (key) => deleted.push(key),
    },
    fetch: async () => new Response("ok"),
  });
  let task;
  handlers.install({ waitUntil: (p) => (task = p) });
  await task;
  assert.ok(installed.includes("https://example.test/portal/app.mjs"));
  assert.ok(
    installed.every((url) => url.startsWith("https://example.test/portal/")),
  );
  handlers.activate({ waitUntil: (p) => (task = p) });
  await task;
  assert.deepEqual(deleted, ["statoo-shell:/portal/:old"]);
  assert.equal(claimed, true);
});
