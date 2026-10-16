import test from "node:test";
import assert from "node:assert/strict";
import { PortalClient } from "../client.mjs";
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
test("GRP-09 registration request lets the server assign the group identifier", async () => {
  const sent = [];
  const storage = { getItem: () => null, setItem() {}, removeItem() {} };
  const account = { id: "admin", roles: ["ADMIN"], shared: false };
  const client = new PortalClient({
    storage,
    session: storage,
    fetch: async (url, options) => {
      if (url.endsWith("/groups")) {
        sent.push(JSON.parse(options.body));
        return Response.json({ group_id: "assigned", token: "test", account });
      }
      return Response.json({ account, members: [], documents: {} });
    },
  });
  await client.connect("https://example.test", "", "", "", {
    name: "Groupe",
    username: "admin",
    password: "password",
    shared_username: "members",
    shared_password: "password",
    members: [{ id: "alice", name: "Alice" }],
  });
  assert.equal(sent.length, 1);
  assert.equal("group_id" in sent[0], false);
  assert.equal(client.connection.group, "assigned");
});
