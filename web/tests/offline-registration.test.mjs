import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
async function setup(storage) {
  const source = readFileSync(new URL("../app.mjs", import.meta.url), "utf8");
  assert.match(
    source,
    /RegistrationDraft/,
    "Offline preparation must be supported",
  );
  const { RegistrationDraft } = await import("../registration-draft.mjs");
  const data = new Map();
  const memory = storage || {
    getItem: (k) => data.get(k) || null,
    setItem: (k, v) => data.set(k, v),
    removeItem: (k) => data.delete(k),
  };
  return {
    draft: new RegistrationDraft(memory),
    memory,
    data,
    RegistrationDraft,
  };
}
test("OFF-02/04/05 drafts survive reload, exclude credentials and keep retry identity", async () => {
  const { draft, memory, data, RegistrationDraft } = await setup();
  draft.save({
    name: "Club",
    roster: "Alice, Bob",
    password: "secret",
    username: "admin",
  });
  assert.equal([...data.values()].join("").includes("secret"), false);
  assert.equal([...data.values()].join("").includes("admin"), false);
  const first = draft.prepare("https://api.test");
  const restored = new RegistrationDraft(memory);
  assert.equal(restored.load().name, "Club");
  assert.deepEqual(restored.prepare("https://api.test"), first);
  assert.throws(() => restored.save({ name: "Changed", roster: "Alice" }));
  assert.throws(() => restored.prepare("https://other.test"));
  restored.clear();
  assert.equal(restored.load(), null);
});
test("OFF-07/08 invalid or unavailable drafts never claim success", async () => {
  const { draft } = await setup();
  assert.throws(() => draft.save({ name: "", roster: "Alice" }));
  assert.throws(() => draft.save({ name: "Club", roster: ", \n" }));
  const bad = await setup({
    getItem: () => "{broken",
    setItem: () => {},
    removeItem: () => {},
  });
  assert.throws(() => bad.draft.load());
  assert.throws(() => bad.draft.save({ name: "Club", roster: "Alice" }));
  const full = await setup({
    getItem: () => null,
    setItem: () => {
      throw Error("quota");
    },
    removeItem: () => {},
  });
  assert.throws(() => full.draft.save({ name: "Club", roster: "Alice" }));
});
