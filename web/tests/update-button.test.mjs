import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
async function setup(waiting = true) {
  class Element extends EventTarget {
    hidden = true;
    children = [];
    append(e) {
      this.children.push(e);
    }
  }
  const parent = new Element(),
    install = new Element();
  install.parentElement = parent;
  const installing = new EventTarget(),
    registration = new EventTarget(),
    sw = new EventTarget();
  const sent = [];
  registration.waiting = waiting ? { postMessage: (m) => sent.push(m) } : null;
  registration.installing = installing;
  sw.controller = waiting ? {} : null;
  sw.register = async () => registration;
  let accepted = true,
    reloads = 0;
  const context = {
    window: new EventTarget(),
    navigator: { serviceWorker: sw },
    document: { createElement: () => new Element() },
    confirm: () => accepted,
    location: { reload: () => reloads++ },
    URL,
  };
  const source = readFileSync(new URL("../pwa.mjs", import.meta.url), "utf8")
    .replace("export function", "function")
    .replaceAll("import.meta.url", '"https://example.test/portal/pwa.mjs"');
  vm.runInNewContext(source + ";globalThis.start=registerPwa;", context);
  context.start(install);
  await new Promise((r) => setImmediate(r));
  return {
    parent,
    registration,
    sw,
    sent,
    setAccepted: (v) => (accepted = v),
    reloads: () => reloads,
    update: () => {
      registration.dispatchEvent(new Event("updatefound"));
      installing.dispatchEvent(new Event("statechange"));
    },
  };
}
test("UPD-01/02/03 update notifications reuse one button targeting the current waiting worker", async () => {
  const x = await setup();
  x.update();
  x.update();
  assert.equal(
    x.parent.children.length,
    1,
    "Repeated events must not append update buttons",
  );
  const latest = [];
  x.registration.waiting = { postMessage: (m) => latest.push(m) };
  x.update();
  assert.equal(x.parent.children.length, 1);
  const button = x.parent.children[0];
  x.setAccepted(false);
  button.dispatchEvent(new Event("click"));
  assert.equal(latest.length, 0);
  x.setAccepted(true);
  button.dispatchEvent(new Event("click"));
  assert.equal(latest.length, 1);
  assert.equal(latest[0].type, "SKIP_WAITING");
  assert.equal(x.sent.length, 0);
});
test("UPD-04 no update button without waiting worker; controller change reloads once after first install", async () => {
  const x = await setup(false);
  x.update();
  assert.equal(x.parent.children.length, 0);
  x.sw.dispatchEvent(new Event("controllerchange"));
  assert.equal(x.reloads(), 0);
  x.sw.dispatchEvent(new Event("controllerchange"));
  x.sw.dispatchEvent(new Event("controllerchange"));
  assert.equal(x.reloads(), 1);
});
