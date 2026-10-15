import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
test("GRP-06/07 names support commas, lines, surrounding spaces and blank entries", async () => {
  const domain = await import("../domain.mjs");
  assert.equal(
    typeof domain.parseMemberNames,
    "function",
    "Member parsing must support mixed separators",
  );
  assert.deepEqual(
    domain.parseMemberNames(" Alice,   Bob\r\nCamille Dupont,\n , Diane  "),
    ["Alice", "Bob", "Camille Dupont", "Diane"],
  );
  assert.deepEqual(domain.parseMemberNames(" , \n,\r\n"), []);
});
test("GRP-09 registration does not supply a chosen group identifier", () => {
  const source = readFileSync(new URL("../app.mjs", import.meta.url), "utf8");
  assert.equal(source.includes("group_id: group.value.trim()"), false);
});
