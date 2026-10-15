import test from "node:test";
import assert from "node:assert/strict";
import { PortalClient } from "../client.mjs";
function memory() {
  const data = new Map();
  return {
    get length() {
      return data.size;
    },
    key: (i) => [...data.keys()][i],
    getItem: (k) => data.get(k) ?? null,
    setItem: (k, v) => data.set(k, v),
    removeItem: (k) => data.delete(k),
  };
}
const identity = {
  token: "test-token",
  group_id: "g",
  expires_at: "2099-01-01T00:00:00Z",
  account: { id: "sport", roles: ["SG"], shared: false },
};
const snapshot = {
  name: "Groupe",
  account: identity.account,
  members: [],
  documents: {},
  finances: { cash: 0, members: {} },
};
const json = (value, status = 200) =>
  new Response(JSON.stringify(value), {
    status,
    headers: { "Content-Type": "application/json" },
  });
async function setup() {
  const storage = memory(),
    session = memory();
  const client = new PortalClient({
    storage,
    session,
    fetch: async (url) =>
      url.endsWith("/auth/login") ? json(identity) : json(snapshot),
  });
  await client.connect("https://example.test", "g", "sport", "password");
  return { client, storage, session };
}
test("WEB-01/08/30 connect, cache, 401 erases private state", async () => {
  const { client, storage, session } = await setup();
  assert.equal(client.snapshot.name, "Groupe");
  client.saveDraft("sport", "draft", { name: "draft" });
  assert.ok(storage.length);
  client.fetch = async () => json({ detail: "Connexion expirée" }, 401);
  await assert.rejects(() => client.refresh(), /expirée/);
  assert.equal(client.snapshot, null);
  assert.equal(client.connection, null);
  assert.equal(storage.length, 0);
  assert.equal(session.length, 0);
});
test("WEB-27/31 drafts survive same identity only and logout clears local data even offline", async () => {
  const { client, storage, session } = await setup();
  client.saveDraft("sport", "x", { goals: 2 });
  const restored = new PortalClient({
    storage,
    session,
    fetch: async () => {
      throw Error("offline");
    },
  });
  restored.restore();
  assert.deepEqual(restored.readDraft("sport", "x"), { goals: 2 });
  restored.connection = { ...restored.connection, account: { id: "other" } };
  assert.equal(restored.readDraft("sport", "x"), null);
  client.fetch = async () => {
    throw Error("offline");
  };
  await client.logout();
  assert.equal(storage.length, 0);
  assert.equal(client.snapshot, null);
});
test("WEB-28 timeout retries exact operation once without double accounting", async () => {
  const { client } = await setup();
  const bodies = [];
  client.fetch = async (url, options) => {
    bodies.push(options.body);
    throw Error("offline");
  };
  await assert.rejects(
    () => client.send("sport", "2026-10-15-1", { session: { id: "s" } }),
    /offline/,
  );
  assert.equal(client.pending().length, 1);
  client.fetch = async (url, options) =>
    url.endsWith("/sync")
      ? (bodies.push(options.body), json({ status: "accepted", revision: 1 }))
      : json(snapshot);
  await client.retryPending();
  assert.equal(bodies[0], bodies[1]);
  assert.equal(client.pending().length, 0);
});
test("WEB-29 conflict does not remain queued or claim publication", async () => {
  const { client } = await setup();
  client.fetch = async (url) =>
    url.endsWith("/sync")
      ? json({ status: "conflict", revision: 2 })
      : json(snapshot);
  assert.equal((await client.send("sport", "ref", {})).status, "conflict");
  assert.equal(client.pending().length, 0);
});
test("WEB-03/32 no write for collective or when storage fails", async () => {
  const { client } = await setup();
  let requests = 0;
  client.fetch = async () => {
    requests++;
    return json({});
  };
  client.snapshot.account = { roles: ["SG"], shared: true };
  await assert.rejects(() => client.send("sport", "ref", {}));
  assert.equal(requests, 0);
  client.snapshot.account = identity.account;
  client.storage.setItem = () => {
    throw Error("quota");
  };
  await assert.rejects(() => client.send("sport", "ref", {}), /stockage/i);
  assert.equal(requests, 0);
});
test("WEB-36 explicit server rejection allows corrected resubmission, unlike timeout", async () => {
  const { client } = await setup();
  client.saveDraft("finance", "new", { amount: 10 });
  client.fetch = async () => json({ detail: "Buts incohérents" }, 422);
  await assert.rejects(() => client.send("sport", "ref", {}), /incohérents/);
  assert.equal(client.pending().length, 0);
  assert.deepEqual(client.readDraft("finance", "new"), { amount: 10 });
});
test("WEB-37 corrupt/missing expiry is not a valid offline identity", () => {
  const storage = memory(),
    session = memory();
  session.setItem(
    "statoo-connection",
    JSON.stringify({
      api: "https://example.test",
      group: "g",
      token: "x",
      account: { id: "me" },
    }),
  );
  const c = new PortalClient({ storage, session });
  c.restore();
  assert.equal(c.connection, null);
});

test("WEB-39 late refresh or 401 cannot overwrite or disconnect another account", async () => {
  for (const status of [200, 401]) {
    const { client } = await setup();
    let resolve;
    client.fetch = () => new Promise((done) => (resolve = done));
    const old = client.refresh();
    client.connection = {
      ...client.connection,
      account: { id: "new", roles: ["MEMBER"] },
    };
    client.snapshot = { name: "New group", account: client.connection.account };
    resolve(
      json(status === 200 ? snapshot : { detail: "Old token expired" }, status),
    );
    try {
      await old;
    } catch {}
    assert.equal(client.connection?.account.id, "new");
    assert.equal(client.snapshot.name, "New group");
  }
});
test("WEB-30 server refusal refreshes revoked capabilities before further actions", async () => {
  const { client } = await setup();
  client.fetch = async (url) =>
    url.endsWith("/sync")
      ? json({ detail: "Droit insuffisant" }, 403)
      : json({
          ...snapshot,
          account: { id: "sport", roles: ["MEMBER"], shared: false },
        });
  await assert.rejects(() => client.send("sport", "ref", {}), /Droit/);
  assert.deepEqual(client.snapshot.account.roles, ["MEMBER"]);
});

test("WEB-32 a corrupted pending queue blocks new sends instead of losing operation identity", async () => {
  const { client, storage } = await setup();
  storage.setItem(client.prefix() + "pending", "{broken");
  let requests = 0;
  client.fetch = async () => {
    requests++;
    return json({});
  };
  await assert.rejects(() => client.send("sport", "ref", {}), /illisible/i);
  assert.equal(requests, 0);
});
