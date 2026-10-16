import test from "node:test";
import assert from "node:assert/strict";
import { PortalClient } from "../client.mjs";
import {
  integer,
  prepareSport,
  prepareFinance,
  newReference,
  operation,
} from "../domain.mjs";

const memory = () => {
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
};
const account = { id: "me", roles: ["ADMIN", "SG", "TR"], shared: false };
const snapshot = {
  name: "Validation",
  account,
  members: [],
  documents: {},
  finances: { cash: 0, members: {} },
};
const json = (v) =>
  new Response(JSON.stringify(v), {
    headers: { "Content-Type": "application/json" },
  });
function setup() {
  let writes = 0;
  const client = new PortalClient({
    storage: memory(),
    session: memory(),
    fetch: async (url, options) => {
      if (options.method !== "GET") writes++;
      return json(
        url.endsWith("/auth/login") || url.endsWith("/groups")
          ? {
              group_id: "g",
              token: "synthetic",
              expires_at: "2099-01-01",
              account,
            }
          : url.endsWith("/groups/g")
            ? snapshot
            : { ok: true },
      );
    },
  });
  return { client, writes: () => writes };
}
const structured = (e) =>
  Array.isArray(e.issues) && e.issues.length > 0 && !e.message.startsWith("[");

test("ZOD-01 login rejects invalid credentials before network with structured French errors", async () => {
  for (const [group, user, password] of [
    ["", "admin", "password"],
    ["g", " ", "password"],
    ["g", "a".repeat(101), "password"],
    ["g", "admin", "short"],
    ["g", "admin", "x".repeat(201)],
  ]) {
    const x = setup();
    await assert.rejects(
      () => x.client.connect("https://example.test", group, user, password),
      structured,
    );
    assert.equal(x.writes(), 0);
  }
  const x = setup();
  await x.client.connect(
    "https://example.test",
    "#historic-group",
    " admin ",
    " password ",
  );
  assert.equal(x.writes(), 1);
});
test("ZOD-01 registration checks names, passwords, roster and limits before network", async () => {
  const valid = {
    name: "Groupe",
    username: "admin",
    password: "password",
    shared_username: "members",
    shared_password: "password",
    members: [{ id: "legacy-id", name: "Alice", is_active: 1 }],
  };
  for (const change of [
    { name: " " },
    { name: "x".repeat(101) },
    { password: "short" },
    { shared_password: "x".repeat(201) },
    { members: [] },
    {
      members: Array.from({ length: 1001 }, (_, i) => ({
        id: String(i),
        name: "A",
      })),
    },
  ]) {
    const x = setup();
    await assert.rejects(
      () =>
        x.client.connect("https://example.test", "", "", "", {
          ...valid,
          ...change,
        }),
      structured,
    );
    assert.equal(x.writes(), 0);
  }
  const x = setup();
  await x.client.connect("https://example.test", "", "", "", valid);
  assert.equal(x.writes(), 1);
});
test("ZOD-02/03/05 every administrative payload is validated before network", async () => {
  const cases = [
    ["/members", [{ id: "a", name: " " }]],
    [
      "/accounts",
      {
        username: "a",
        password: "password",
        member_id: "a",
        roles: ["MEMBER"],
      },
    ],
    [
      "/accounts",
      {
        username: "a",
        password: "password",
        member_id: "a",
        roles: ["UNKNOWN"],
      },
    ],
    ["/accounts/me/roles", { roles: ["SG"], reason: " " }],
    ["/shared-access", { group_id: "g", username: "a", password: "short" }],
    ["/sport-settings", { min_players_per_session: 31 }],
    ["/sport-settings", { min_players_per_session: true }],
    ["/financial-settings", { contribution: -1, late_penalty: 0 }],
    ["/opening", { cash: 0, start_date: "2026-02-30", members: {} }],
    [
      "/opening",
      {
        cash: 0,
        members: { a: { contribution_balance: -10, penalty_debt: -1 } },
      },
    ],
    ["/opening/approve", { proposal: { cash: -1, members: {} } }],
    [
      "/documents/sport/ref/resolve",
      { revision: 1, candidate_id: "", reason: "x" },
    ],
    [
      "/documents/sport/ref/transfer",
      { revision: -1, account_id: "a", reason: "x" },
    ],
    [
      "/documents/finance/ref/transfer",
      { revision: 1, account_id: "a", reason: "x".repeat(301) },
    ],
  ];
  for (const [path, body] of cases) {
    const x = setup();
    await x.client.connect("https://example.test", "g", "a", "password");
    const before = x.writes();
    await assert.rejects(() => x.client.mutate(path, body), structured);
    assert.equal(x.writes(), before, path);
  }
});
test("ZOD-03 controlled numeric conversion rejects empty, booleans, null and invalid numbers", () => {
  for (const value of [
    "",
    " ",
    null,
    true,
    false,
    NaN,
    Infinity,
    -1,
    1.5,
    1e12 + 1,
  ])
    assert.throws(() => integer(value, "Montant"), structured);
  for (const value of [0, "0", " 12 ", 1e12])
    assert.equal(integer(value), Number(value));
  assert.equal(integer("-12", "Avance", true), -12);
});
test("ZOD-04 invalid structures and calendar dates produce validation errors, never TypeError", () => {
  for (const payload of [
    null,
    {},
    { session: {}, participations: {} },
    { session: null, participations: [] },
  ])
    assert.throws(() => prepareSport(payload, []), structured);
  for (const payload of [
    null,
    {},
    {
      played_at: "2026-10-16",
      rate: 0,
      lines: {},
      expenses: [],
      donations: [],
    },
  ])
    assert.throws(() => prepareFinance(payload, []), structured);
  for (const day of ["2026-02-30", "2026-13-01", "not-a-date"])
    assert.throws(
      () => newReference({ documents: {}, obligations: {} }, day),
      structured,
    );
});
test("ZOD-05 valid signed balances and member metadata survive validation unchanged", async () => {
  const x = setup();
  await x.client.connect("https://example.test", "g", "a", "password");
  for (const [path, body] of [
    [
      "/opening",
      {
        cash: 0,
        start_date: "2024-02-29",
        members: { a: { contribution_balance: -12, penalty_debt: 0 } },
      },
    ],
    ["/sport-settings", { min_players_per_session: 2 }],
    ["/sport-settings", { min_players_per_session: 30 }],
    [
      "/members",
      [
        {
          id: "legacy",
          name: "Alice",
          nickname: "A",
          created_at: "2020-01-01",
        },
      ],
    ],
  ])
    assert.equal((await x.client.mutate(path, body, "PUT")).ok, true);
});
test("ZOD-02 operation reference and correction reason keep structured validation", () => {
  for (const ref of ["", "a/b", "x".repeat(151)])
    assert.throws(() => operation("sport", ref, {}), structured);
  assert.throws(
    () =>
      operation(
        "sport",
        "ref",
        {},
        { revision: 1, generation: 0 },
        "x".repeat(301),
      ),
    structured,
  );
});
