import test from "node:test";
import assert from "node:assert/strict";
import { PortalClient } from "../client.mjs";
import { standings } from "../summary.mjs";
import { prepareSport } from "../domain.mjs";

function memory() {
  const m = new Map();
  return {
    get length() {
      return m.size;
    },
    key: (i) => [...m.keys()][i],
    getItem: (k) => m.get(k) ?? null,
    setItem: (k, v) => m.set(k, v),
    removeItem: (k) => m.delete(k),
  };
}
const account = { id: "me", roles: ["SG", "TR", "ADMIN"], shared: false };
const snapshot = {
  name: "Groupe",
  account,
  members: [],
  documents: {},
  finances: { cash: 0 },
};
const json = (v, status = 200) =>
  new Response(JSON.stringify(v), {
    status,
    headers: { "Content-Type": "application/json" },
  });
async function setup() {
  const storage = memory(),
    session = memory();
  const c = new PortalClient({
    storage,
    session,
    fetch: async (url) =>
      url.endsWith("/auth/login")
        ? json({
            token: "test",
            group_id: "g",
            expires_at: "2099-01-01",
            account,
          })
        : json(snapshot),
  });
  await c.connect("https://example.test", "g", "a", "password");
  return { c, storage, session };
}
test("FIX-01 stale sport and finance bases cannot be silently published", async () => {
  for (const domain of ["sport", "finance"])
    for (const variant of ["revision", "generation", "deleted", "created"]) {
      const { c } = await setup();
      const original = {
        owner: "me",
        revision: 1,
        generation: 0,
        domain,
        occurrence_id: "ref",
        payload: {},
        candidates: [],
      };
      const latest = structuredClone(original);
      if (variant === "revision") latest.revision++;
      if (variant === "generation") latest.generation++;
      c.snapshot.documents["" + domain + ":ref"] =
        variant === "deleted" ? undefined : latest;
      let sends = 0;
      c.fetch = async () => {
        sends++;
        return json({ status: "accepted" });
      };
      await assert.rejects(
        () =>
          c.send(
            domain,
            "ref",
            {},
            variant === "created" ? undefined : original,
            "Correction",
          ),
        /brouillon|version|périm/i,
      );
      assert.equal(sends, 0);
      assert.equal(c.pending().length, 0);
    }
});
test("FIX-03 accepted mutation warns without repeating the write, clears warning on next success", async () => {
  const { c } = await setup();
  let writes = 0;
  c.fetch = async (_url, options) => {
    if (options.method === "POST") {
      writes++;
      return json({ ok: true });
    }
    throw Error("offline");
  };
  assert.equal((await c.mutate("/members", [])).ok, true);
  assert.match(c.refreshWarning, /enregistr|envoy/i);
  assert.equal(writes, 1);
  c.fetch = async (_url, options) =>
    options.method === "POST" ? json({ ok: true }) : json(snapshot);
  await c.mutate("/members", []);
  assert.equal(c.refreshWarning, null);
  c.fetch = async () => json({ detail: "Refus" }, 403);
  await assert.rejects(() => c.mutate("/members", []), /Refus/);
});
test("FIX-04 old response cannot overwrite cache after a newer failed refresh", async () => {
  const { c, storage } = await setup();
  const cached = storage.getItem(c.prefix() + "snapshot");
  const waits = [];
  c.fetch = () => new Promise((resolve) => waits.push(resolve));
  const old = c.refresh(),
    recent = c.refresh();
  waits[1](json({ detail: "Indisponible" }, 503));
  await assert.rejects(() => recent);
  waits[0](json({ ...snapshot, name: "Périmé" }));
  await old;
  assert.equal(c.snapshot.name, "Groupe");
  assert.equal(storage.getItem(c.prefix() + "snapshot"), cached);
});
test("FIX-09 blocked storage getters and methods do not crash restore or clear", () => {
  const denied = {
    getItem() {
      throw Error("Denied");
    },
    removeItem() {
      throw Error("Denied");
    },
    setItem() {
      throw Error("Denied");
    },
  };
  const old = Object.getOwnPropertyDescriptor(globalThis, "localStorage");
  const previous = Object.getOwnPropertyDescriptor(
    globalThis,
    "sessionStorage",
  );
  try {
    Object.defineProperty(globalThis, "localStorage", {
      configurable: true,
      get() {
        throw Error("Denied");
      },
    });
    Object.defineProperty(globalThis, "sessionStorage", {
      configurable: true,
      get() {
        throw Error("Denied");
      },
    });
    const c = new PortalClient();
    assert.doesNotThrow(() => c.restore());
    assert.match(c.storageWarning, /stockage/i);
    const d = new PortalClient({ storage: denied, session: denied });
    assert.doesNotThrow(() => d.restore());
    assert.doesNotThrow(() => d.clear());
  } finally {
    if (old) Object.defineProperty(globalThis, "localStorage", old);
    else delete globalThis.localStorage;
    if (previous) Object.defineProperty(globalThis, "sessionStorage", previous);
    else delete globalThis.sessionStorage;
  }
});
test("FIX-11 HTTP status survives HTML/invalid JSON and empty success is accepted", async () => {
  for (const status of [401, 403, 422, 503]) {
    const { c } = await setup();
    c.fetch = async () =>
      new Response("<html>error</html>", {
        status,
        headers: { "Content-Type": "text/html" },
      });
    await assert.rejects(
      () => c.refresh(),
      (e) =>
        e.status === status &&
        /serveur|indisponible|connexion|refus|champs/i.test(e.message),
    );
    if (status === 401) assert.equal(c.connection, null);
  }
  const { c } = await setup();
  c.fetch = async () =>
    new Response("{bad", {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  await assert.rejects(() => c.refresh(), /serveur|invalide|réessay/i);
  c.fetch = async () => new Response(null, { status: 204 });
  assert.deepEqual(await c.request("/empty"), {});
});
test("FIX-05 wins then appearances then name break points ties; friendlies add no win", () => {
  const members = ["Zaki", "Amine", "Baba"].map((name, i) => ({
    id: String(i),
    name,
  }));
  const doc = (id, player, result, is_ranked = 1, status = "CLOSED") => ({
    domain: "sport",
    payload: {
      session: { id, result, is_ranked, status },
      participations: [
        { player_id: String(player), team: "A", goals: 0, assists: 0 },
      ],
    },
  });
  const docs = {
    w: doc("w", 0, "A"),
    d1: doc("d1", 1, "DRAW"),
    d2: doc("d2", 1, "DRAW"),
    d3: doc("d3", 1, "DRAW"),
    f: doc("f", 1, "A", 0),
    draft: doc("draft", 1, "A", 1, "DRAFT"),
  };
  assert.deepEqual(
    standings({ members, documents: docs }).map((m) => m.name),
    ["Zaki", "Amine", "Baba"],
  );
});

test("FIX-06 sport closure uses configured group minimum, default six, draft and cancellation remain possible", () => {
  const members = Array.from({ length: 30 }, (_, i) => ({ id: String(i) }));
  const payload = (count) => ({
    session: {
      id: "s",
      played_at: "2026-10-15T20:00",
      session_type: "CLASSIC_2",
      score_a: 0,
      score_b: 0,
    },
    participations: members.slice(0, count).map((m, i) => ({
      player_id: m.id,
      session_id: "s",
      team: i % 2 ? "B" : "A",
    })),
  });
  assert.throws(
    () => prepareSport(payload(1), members, "CLOSED"),
    /minimum|joueurs/i,
  );
  for (const min of [2, 6, 30]) {
    assert.throws(
      () => prepareSport(payload(min - 1), members, "CLOSED", min),
      /minimum|joueurs/i,
    );
    assert.equal(
      prepareSport(payload(min), members, "CLOSED", min).participations.length,
      min,
    );
    for (const status of ["DRAFT", "CANCELLED"])
      assert.equal(
        prepareSport(payload(1), members, status, min).session.status,
        status,
      );
  }
});
