import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import {
  capabilities,
  prepareSport,
  prepareFinance,
  newReference,
  teamSummary,
  operation,
  responsibleRoles,
} from "../domain.mjs";

const members = ["a", "b", "c"].map((id) => ({
  id,
  name: id.toUpperCase(),
  is_active: 1,
}));
const snapshot = () => ({
  members,
  financial_settings: { contribution: 100 },
  documents: {},
  obligations: {},
});
const sport = (extra = {}) => ({
  session: {
    id: "s",
    team_id: "g",
    played_at: "2026-10-15T20:00:00",
    status: "DRAFT",
    session_type: "CLASSIC_2",
    is_ranked: 1,
    score_a: 2,
    score_b: 0,
    team_names: { A: "Racing Atlas", B: "Union du Port", C: "Sporting Atlas" },
    team_colors: { A: 0xff3b82f6, B: 0xfff97316, C: 0xff22c55e },
    ...extra,
  },
  participations: [
    {
      id: "p",
      player_id: "a",
      session_id: "s",
      team: "A",
      goals: 1,
      assists: 0,
    },
    {
      id: "p2",
      player_id: "b",
      session_id: "s",
      team: "B",
      goals: 0,
      assists: 0,
    },
  ],
});

test("WEB-03/04 capabilities are explicit and collective is always read only", () => {
  for (const role of [
    "MEMBER",
    "CENSOR",
    "ADMIN",
    "SG",
    "SGA",
    "TR",
    "TGA",
    "PDT",
    "VP",
  ]) {
    const c = capabilities({ roles: [role], shared: false });
    assert.equal(c.sport, ["ADMIN", "PDT", "VP", "SG", "SGA"].includes(role));
    assert.equal(c.finance, ["TR", "TGA"].includes(role));
    assert.equal(c.admin, role === "ADMIN");
    assert.equal(c.arbitrate, ["PDT", "VP"].includes(role));
    assert.equal(c.settings, ["ADMIN", "TR", "TGA"].includes(role));
  }
  assert.equal(
    Object.values(capabilities({ roles: responsibleRoles, shared: true })).some(
      Boolean,
    ),
    false,
  );
});
test("WEB-07/08/09 sport close computes result and unassigned goals without mutating input", () => {
  const p = sport();
  const result = prepareSport(p, members, "CLOSED", 2);
  assert.equal(result.session.result, "A");
  assert.equal(result.session.unassigned_goals_a, 1);
  assert.equal(p.session.status, "DRAFT");
});
test("WEB-09 tournament draws and no-victory rejection", () => {
  for (const [wins, result] of [
    [[3, 1, 0], "A"],
    [[0, 4, 1], "B"],
    [[1, 0, 5], "C"],
    [[2, 2, 1], "DRAW_AB"],
    [[1, 2, 2], "DRAW_BC"],
    [[2, 1, 2], "DRAW_AC"],
    [[2, 2, 2], "DRAW_ALL"],
  ]) {
    const p = sport({
      session_type: "TOURNAMENT_3",
      wins_a: wins[0],
      wins_b: wins[1],
      wins_c: wins[2],
      score_a: null,
      score_b: null,
    });
    assert.equal(prepareSport(p, members, "CLOSED", 2).session.result, result);
  }
  assert.throws(
    () =>
      prepareSport(
        sport({
          session_type: "TOURNAMENT_3",
          wins_a: 0,
          wins_b: 0,
          wins_c: 0,
        }),
        members,
        "CLOSED",
        2,
      ),
    /victoire/i,
  );
});
test("WEB-10 rejects invalid sports inputs", () => {
  for (const value of [-1, 1.2, NaN])
    assert.throws(() =>
      prepareSport(sport({ score_a: value }), members, "CLOSED", 2),
    );
  for (const mutate of [
    (p) => p.participations.push({ ...p.participations[0] }),
    (p) => (p.participations[0].player_id = "unknown"),
    (p) => (p.participations[0].team = "C"),
    (p) => (p.participations[0].assists = 2),
    (p) => (p.session.team_colors.B = p.session.team_colors.A),
    (p) => (p.session.played_at = "bad"),
  ]) {
    const p = sport();
    mutate(p);
    assert.throws(() => prepareSport(p, members, "CLOSED", 2));
  }
  const p = sport({ score_a: 0 });
  assert.throws(() => prepareSport(p, members, "CLOSED", 2), /buts/i);
});
test("WEB-06 summaries isolate session scorers, decode names/colors, include third team", () => {
  const p = sport({
    session_type: "TOURNAMENT_3",
    team_names: JSON.stringify({ A: "Atlas", B: "Union", C: "Racing" }),
  });
  p.participations.push(
    { session_id: "other", team: "A", player_id: "b", goals: 99 },
    { session_id: "s", team: "C", player_id: "c", goals: 2 },
  );
  const teams = teamSummary(p, members);
  assert.equal(teams.length, 3);
  assert.equal(teams[2].name, "Racing");
  assert.deepEqual(
    teams[0].scorers.map((s) => s.name),
    ["A"],
  );
  assert.equal(teams[2].scorers[0].goals, 2);
});
test("WEB-13 reference finds next free identity across sport and finance", () => {
  const s = snapshot();
  s.documents["sport:2026-10-15-1"] = { occurrence_id: "2026-10-15-1" };
  s.obligations["2026-10-15-2"] = {};
  assert.equal(newReference(s, "2026-10-15T20:00"), "2026-10-15-3");
});
test("WEB-22/23 finance preserves historical roster, rate and movement ids", () => {
  const p = {
    played_at: "2026-10-15T20:00:00",
    rate: 75,
    cancelled: false,
    lines: [
      {
        member_id: "a",
        contribution: 200,
        penalty_due: 5,
        penalty_paid: 0,
        reason: "Retard",
      },
    ],
    expenses: [{ id: "water", label: "Eau", amount: 20 }],
    donations: [],
  };
  const result = prepareFinance(p, ["a"]);
  assert.equal(result.rate, 75);
  assert.equal(result.expenses[0].id, "water");
  assert.equal(p.lines[0].contribution, 200);
  assert.throws(() => prepareFinance(p, ["a", "b"]), /membres/i);
});
test("WEB-24 rejects fractional, negative, duplicate, cancelled movements and missing reason", () => {
  const baseline = {
    played_at: "2026-10-15",
    rate: 100,
    cancelled: false,
    lines: [
      {
        member_id: "a",
        contribution: 0,
        penalty_due: 0,
        penalty_paid: 0,
        reason: "",
      },
    ],
    expenses: [],
    donations: [],
  };
  for (const mutate of [
    (p) => (p.lines[0].contribution = -1),
    (p) => (p.rate = 1.2),
    (p) => (p.lines[0].penalty_due = 1),
    (p) => p.expenses.push({ id: "x", label: "", amount: 2 }),
    (p) => {
      p.cancelled = true;
      p.lines[0].contribution = 1;
    },
    (p) => p.lines.push({ ...p.lines[0] }),
  ]) {
    const p = structuredClone(baseline);
    mutate(p);
    assert.throws(() => prepareFinance(p, ["a"]));
  }
});
test("WEB-12/28 operation carries immutable revision/generation and correction reason", () => {
  const doc = { revision: 3, generation: 2 };
  assert.throws(() => operation("sport", "ref", sport(), doc, ""), /motif/i);
  const result = operation("sport", "ref", sport(), doc, "Correction");
  assert.equal(result.base_revision, 3);
  assert.equal(result.generation, 2);
  assert.ok(result.operation_id);
});
test("WEB-38 legacy session appearance gets stable defaults when editing", () => {
  const p = sport();
  delete p.session.team_names;
  delete p.session.team_colors;
  const result = prepareSport(p, members, "CLOSED", 2);
  assert.equal(result.session.team_names.A, "Équipe A");
  assert.equal(result.session.team_colors.A, 0xff3b82f6);
});

test("WEB-41 sport wire format is compatible with mobile SQLite imports", () => {
  const payload = prepareSport(
    sport({ is_ranked: true, allow_uneven_teams: false }),
    members,
    "CLOSED",
    2,
  );
  const op = operation("sport", "ref", payload);
  assert.equal(typeof op.payload.session.team_names, "string");
  assert.equal(typeof op.payload.session.team_colors, "string");
  assert.equal(JSON.parse(op.payload.session.team_names).A, "Racing Atlas");
  assert.equal(op.payload.session.is_ranked, 1);
  assert.equal(op.payload.session.allow_uneven_teams, 0);
  assert.equal(typeof payload.session.team_names, "object");
});

test("WEB-41 checked-in mobile fixture stays identical to current PWA serialization", () => {
  const snapshot = JSON.parse(
    readFileSync(
      new URL("./fixtures/mobile-snapshot.json", import.meta.url),
      "utf8",
    ),
  );
  const document = Object.values(snapshot.documents)[0];
  const payload = prepareSport(document.payload, snapshot.members, "CLOSED", 2);
  assert.deepEqual(
    operation("sport", document.occurrence_id, payload).payload,
    document.payload,
  );
});
test("WEB-07 team catalogue matches the mobile catalogue without duplicate names", () => {
  const names = JSON.parse(
    readFileSync(new URL("../team-names.json", import.meta.url), "utf8"),
  );
  const dart = readFileSync(
    new URL(
      "../../mobile/lib/features/sessions/domain/session_team_names.dart",
      import.meta.url,
    ),
    "utf8",
  );
  const block = dart.slice(
    dart.indexOf("const sessionTeamNames"),
    dart.indexOf("];", dart.indexOf("const sessionTeamNames")),
  );
  assert.deepEqual(
    names,
    [...block.matchAll(/'([^']+)'/g)].map((match) => match[1]),
  );
  assert.equal(new Set(names).size, names.length);
  assert.ok(names.length >= 100);
});
