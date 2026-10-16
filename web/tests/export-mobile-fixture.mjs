// Synthetic cross-client contract fixture. No server or real group is accessed.
import { writeFileSync, mkdirSync } from "node:fs";
import { prepareSport, operation } from "../domain.mjs";
const members = ["a", "b", "c"].map((id) => ({
  id,
  name: id.toUpperCase(),
  is_active: 1,
}));
const payload = prepareSport(
  {
    session: {
      id: "pwa-s",
      team_id: "g",
      played_at: "2026-10-15T20:00:00",
      session_type: "TOURNAMENT_3",
      status: "DRAFT",
      is_ranked: true,
      allow_uneven_teams: false,
      team_names: {
        A: "Racing Atlas",
        B: "Union du Port",
        C: "Sporting Atlas",
      },
      team_colors: { A: 0xff3b82f6, B: 0xfff97316, C: 0xff22c55e },
      wins_a: 3,
      wins_b: 2,
      wins_c: 1,
    },
    participations: members.map((m, i) => ({
      id: "p" + m.id,
      player_id: m.id,
      session_id: "pwa-s",
      team: ["A", "B", "C"][i],
      goals: i + 1,
      assists: 0,
      yellow_cards: 0,
      red_cards: 0,
    })),
  },
  members,
  "CLOSED",
  3,
);
const op = operation("sport", "2026-10-15-1", payload);
const snapshot = {
  name: "PWA contract fixture",
  account: { id: "me", roles: ["MEMBER"], shared: true },
  members,
  documents: {
    "sport:2026-10-15-1": {
      domain: "sport",
      occurrence_id: "2026-10-15-1",
      owner: "sg",
      revision: 1,
      generation: 0,
      candidates: [],
      history: [],
      payload: op.payload,
    },
  },
  obligations: {},
  sport_settings: { min_players_per_session: 3 },
  financial_settings: { contribution: 100, late_penalty: 0 },
  finances: { cash: 0, members: {} },
};
mkdirSync(new URL("./fixtures/", import.meta.url), { recursive: true });
writeFileSync(
  new URL("./fixtures/mobile-snapshot.json", import.meta.url),
  JSON.stringify(snapshot, null, 2) + "\n",
);
