import test from "node:test";
import assert from "node:assert/strict";
import { standings } from "../summary.mjs";
test("only accepted closed sport contributes to points; friendlies count goals", () => {
  const snapshot = {
    members: [{ id: "a", name: "Alice" }],
    documents: {
      first: {
        domain: "sport",
        payload: {
          session: { status: "CLOSED", is_ranked: 1, result: "A" },
          participations: [{ player_id: "a", team: "A", goals: 2, assists: 1 }],
        },
      },
      friendly: {
        domain: "sport",
        payload: {
          session: { status: "CLOSED", is_ranked: 0, result: "B" },
          participations: [{ player_id: "a", team: "A", goals: 1, assists: 0 }],
        },
      },
      draft: {
        domain: "sport",
        payload: {
          session: { status: "DRAFT" },
          participations: [
            { player_id: "a", team: "A", goals: 99, assists: 99 },
          ],
        },
      },
    },
  };
  assert.deepEqual(standings(snapshot)[0], {
    id: "a",
    name: "Alice",
    points: 3,
    matches: 1,
    goals: 3,
    assists: 1,
  });
});
