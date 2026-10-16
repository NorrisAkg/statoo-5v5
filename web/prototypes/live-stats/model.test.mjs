import test from "node:test";
import assert from "node:assert/strict";
import {
  createDemo,
  record,
  undo,
  stats,
  setClosed,
  restore,
} from "./model.mjs";
test("LIVE-01/02 goal and assist are atomic; anonymous goals remain unattributed", () => {
  let s = createDemo("classic");
  const original = JSON.stringify(s);
  s = record(s, { type: "goal", team: "A", player: "a1", assist: "a2" });
  assert.equal(stats(s).A.goals, 1);
  assert.equal(stats(s).players.a1.goals, 1);
  assert.equal(stats(s).players.a2.assists, 1);
  assert.equal(s.events.length, 1);
  assert.equal(JSON.stringify(createDemo("classic")), original);
  s = record(s, { type: "goal", team: "A", player: null });
  assert.equal(stats(s).A.unassigned, 1);
  assert.equal(stats(s).A.goals, 2);
});
test("LIVE-03 invalid selections never change state", () => {
  const s = createDemo("classic");
  for (const action of [
    { type: "goal", team: "D", player: "a1" },
    { type: "goal", team: "A", player: "b1" },
    { type: "goal", team: "A", player: "a1", assist: "a1" },
    { type: "goal", team: "A", player: null, assist: "a1" },
  ])
    assert.throws(() => record(s, action));
  assert.equal(s.events.length, 0);
});
test("LIVE-04/05/06 tournament wins, goals and cards remain independent and undoable", () => {
  let s = createDemo("tournament");
  s = record(s, { type: "win", team: "C", delta: 1 });
  s = record(s, { type: "goal", team: "C", player: "c1" });
  s = record(s, { type: "yellow", team: "C", player: "c1" });
  assert.equal(stats(s).C.wins, 1);
  assert.equal(stats(s).C.goals, 1);
  assert.equal(stats(s).players.c1.yellow, 1);
  s = undo(s);
  assert.equal(stats(s).players.c1.yellow, 0);
  assert.equal(stats(s).C.goals, 1);
  s = undo(undo(s));
  assert.equal(stats(s).C.wins, 0);
  assert.equal(stats(s).C.goals, 0);
  assert.deepEqual(undo(s), s);
  assert.throws(() => record(s, { type: "win", team: "C", delta: -1 }));
  assert.throws(() =>
    record(createDemo("classic"), { type: "win", team: "A", delta: 1 }),
  );
});
test("LIVE-07/08/10 closed sessions preserve data and corrupted persisted sessions are rejected", () => {
  let s = record(createDemo("classic"), {
    type: "red",
    team: "B",
    player: "b1",
  });
  s = setClosed(s, true);
  assert.equal(stats(s).players.b1.red, 1);
  assert.throws(() => record(s, { type: "goal", team: "A", player: "a1" }));
  assert.throws(() => undo(s));
  assert.deepEqual(restore(JSON.stringify(s), "classic"), s);
  assert.throws(() => restore("{broken", "classic"));
  assert.throws(() => restore(JSON.stringify(s), "tournament"));
  assert.equal(setClosed(s, false).closed, false);
});
