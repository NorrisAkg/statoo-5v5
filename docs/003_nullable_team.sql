-- Statoo — migration 003: participations.team becomes nullable
-- schema_version: 2 -> 3
--
-- A session created with "Composer à la main" stores its attendees before any
-- team is chosen, so `team` needs a NULL state. SQLite cannot drop a NOT NULL
-- or rewrite a CHECK in place, hence the table rebuild.
--
-- Applied ONLY when the stored schema_version is '2'; the guard lives in
-- app/lib/db/migrations.ts because plain SQL has no conditional execution.
-- Fresh installs get the nullable column straight from 001 and never run this.
--
-- No PRAGMA foreign_keys toggle: nothing references `participations`, so the
-- drop and rename are safe with foreign keys enabled — and the pragma would be
-- a no-op anyway inside the transaction that `db.execute()` opens.
--
-- PREREQUISITE: every view must already be dropped. ALTER TABLE ... RENAME
-- re-parses the whole schema, so a view left pointing at the dropped
-- `participations` aborts the rename with "no such table: main.participations".
-- 002_views.sql recreates them right after.

CREATE TABLE participations_v3 (
  id            TEXT PRIMARY KEY,
  session_id    TEXT NOT NULL REFERENCES sessions (id) ON DELETE CASCADE,
  player_id     TEXT NOT NULL REFERENCES players (id) ON DELETE RESTRICT,

  team          TEXT CHECK (team IS NULL OR team IN ('A', 'B')),

  goals         INTEGER NOT NULL DEFAULT 0 CHECK (goals >= 0),
  assists       INTEGER NOT NULL DEFAULT 0 CHECK (assists >= 0),
  yellow_cards  INTEGER NOT NULL DEFAULT 0 CHECK (yellow_cards >= 0),
  red_cards     INTEGER NOT NULL DEFAULT 0 CHECK (red_cards >= 0),

  created_at    TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at    TEXT NOT NULL DEFAULT (datetime('now')),

  UNIQUE (session_id, player_id)
);

INSERT INTO participations_v3
  (id, session_id, player_id, team, goals, assists, yellow_cards, red_cards, created_at, updated_at)
SELECT
  id, session_id, player_id, team, goals, assists, yellow_cards, red_cards, created_at, updated_at
FROM participations;

DROP TABLE participations;

ALTER TABLE participations_v3 RENAME TO participations;

-- The rename carries no indexes, so they are recreated here.
CREATE INDEX IF NOT EXISTS idx_participations_player  ON participations (player_id);
CREATE INDEX IF NOT EXISTS idx_participations_session ON participations (session_id, team);

-- trg_participations_updated_at is deliberately NOT recreated: the embedded
-- schema in app/lib/db/migrations.ts never installed the updated_at triggers
-- declared in 001, and queries.ts writes updated_at explicitly as an ISO
-- string. Recreating the trigger here would silently overwrite those with
-- datetime('now') and change the stored format.

UPDATE meta SET value = '3' WHERE key = 'schema_version';
