import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { RegistrationDraft } from "../registration-draft.mjs";
import { validate, registrationSchema } from "../validation.mjs";

test("ACC13 splash lifecycle belongs to the same JavaScript version", () => {
  const html = readFileSync(new URL("../index.html", import.meta.url), "utf8");
  assert.equal(html.includes('id="splash"'), false);
});

test("ACC08/09 short name survives drafts, changes and validation", () => {
  const data = new Map();
  const storage = {
    getItem: (k) => data.get(k),
    setItem: (k, v) => data.set(k, v),
  };
  const draft = new RegistrationDraft(storage);
  draft.save({ name: "Football Club", short_name: " ÉFC ", roster: "Alice" });
  assert.equal(new RegistrationDraft(storage).load().short_name, "ÉFC");
  draft.save({ name: "Football Club", short_name: "FC", roster: "Alice" });
  assert.equal(draft.load().short_name, "FC");
  assert.throws(() =>
    draft.save({ name: "Club", short_name: "A".repeat(31), roster: "Alice" }),
  );
  const body = {
    name: "Club",
    username: "admin",
    password: "Password1",
    shared_username: "members",
    shared_password: "Password2",
    members: [{ id: "a", name: "Alice" }],
  };
  assert.equal(
    validate(registrationSchema, { ...body, short_name: " FC " }).short_name,
    "FC",
  );
  assert.throws(() =>
    validate(registrationSchema, { ...body, short_name: "A".repeat(31) }),
  );
});
