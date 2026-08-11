-- Statoo — schema v1
-- SQLite (@capacitor-community/sqlite)
-- schema_version: 1

PRAGMA foreign_keys = ON;

-- ---------------------------------------------------------------------------
-- players
-- ---------------------------------------------------------------------------
CREATE TABLE players (
  id          TEXT PRIMARY KEY,
  name        TEXT NOT NULL,
  nickname    TEXT,
  avatar_url  TEXT,
  is_active   INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
  created_at  TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX idx_players_active ON players (is_active, name);

-- ---------------------------------------------------------------------------
-- sessions
-- ---------------------------------------------------------------------------
CREATE TABLE sessions (
  id                  TEXT PRIMARY KEY,
  played_at           TEXT NOT NULL,

  status              TEXT NOT NULL DEFAULT 'DRAFT'
                        CHECK (status IN ('DRAFT', 'CLOSED')),
  split_mode          TEXT NOT NULL DEFAULT 'MANUAL'
                        CHECK (split_mode IN ('RANDOM', 'RANDOM_ADJUSTED', 'MANUAL')),

  allow_uneven_teams  INTEGER NOT NULL DEFAULT 0 CHECK (allow_uneven_teams IN (0, 1)),
  is_ranked           INTEGER NOT NULL DEFAULT 1 CHECK (is_ranked IN (0, 1)),

  score_a             INTEGER CHECK (score_a IS NULL OR score_a >= 0),
  score_b             INTEGER CHECK (score_b IS NULL OR score_b >= 0),
  result              TEXT CHECK (result IS NULL OR result IN ('A', 'B', 'DRAW')),

  unassigned_goals_a  INTEGER NOT NULL DEFAULT 0 CHECK (unassigned_goals_a >= 0),
  unassigned_goals_b  INTEGER NOT NULL DEFAULT 0 CHECK (unassigned_goals_b >= 0),

  notes               TEXT,
  created_at          TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at          TEXT NOT NULL DEFAULT (datetime('now')),

  -- A closed session must carry a complete result.
  CHECK (
    status = 'DRAFT'
    OR (score_a IS NOT NULL AND score_b IS NOT NULL AND result IS NOT NULL)
  ),

  -- `result` is derived data kept for query simplicity: keep it truthful.
  CHECK (
    result IS NULL
    OR score_a IS NULL
    OR score_b IS NULL
    OR result = CASE
                  WHEN score_a > score_b THEN 'A'
                  WHEN score_b > score_a THEN 'B'
                  ELSE 'DRAW'
                END
  )
);

CREATE INDEX idx_sessions_played_at ON sessions (played_at DESC);
CREATE INDEX idx_sessions_ranked    ON sessions (status, is_ranked);

-- ---------------------------------------------------------------------------
-- participations — the single source of truth
-- ---------------------------------------------------------------------------
CREATE TABLE participations (
  id            TEXT PRIMARY KEY,
  session_id    TEXT NOT NULL REFERENCES sessions (id) ON DELETE CASCADE,
  player_id     TEXT NOT NULL REFERENCES players (id) ON DELETE RESTRICT,

  team          TEXT NOT NULL CHECK (team IN ('A', 'B')),

  goals         INTEGER NOT NULL DEFAULT 0 CHECK (goals >= 0),
  assists       INTEGER NOT NULL DEFAULT 0 CHECK (assists >= 0),
  yellow_cards  INTEGER NOT NULL DEFAULT 0 CHECK (yellow_cards >= 0),
  red_cards     INTEGER NOT NULL DEFAULT 0 CHECK (red_cards >= 0),

  created_at    TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at    TEXT NOT NULL DEFAULT (datetime('now')),

  UNIQUE (session_id, player_id)
);

CREATE INDEX idx_participations_player  ON participations (player_id);
CREATE INDEX idx_participations_session ON participations (session_id, team);

-- ---------------------------------------------------------------------------
-- updated_at triggers
-- ---------------------------------------------------------------------------
CREATE TRIGGER trg_players_updated_at
AFTER UPDATE ON players FOR EACH ROW
BEGIN
  UPDATE players SET updated_at = datetime('now') WHERE id = OLD.id;
END;

CREATE TRIGGER trg_sessions_updated_at
AFTER UPDATE ON sessions FOR EACH ROW
BEGIN
  UPDATE sessions SET updated_at = datetime('now') WHERE id = OLD.id;
END;

CREATE TRIGGER trg_participations_updated_at
AFTER UPDATE ON participations FOR EACH ROW
BEGIN
  UPDATE participations SET updated_at = datetime('now') WHERE id = OLD.id;
END;

-- ---------------------------------------------------------------------------
-- meta — schema version, read by the backup exporter
-- ---------------------------------------------------------------------------
CREATE TABLE meta (
  key    TEXT PRIMARY KEY,
  value  TEXT NOT NULL
);

INSERT INTO meta (key, value) VALUES ('schema_version', '2');

-- ---------------------------------------------------------------------------
-- settings — organizer preferences captured at onboarding (SPEC-08).
-- Key/value so a new preference never needs a table migration.
--
--   group_name            free text, names the backups and confirms a restore
--   default_format        pre-fills a new session: '4v4' | '5v5' | '6v6'
--   default_is_ranked     '0' | '1', pre-checks "Séance classée"
--   eligibility_mode      'PERCENT' | 'SESSIONS' — how the Pts/match threshold
--                         is expressed. PERCENT is relative to the number of
--                         ranked closed sessions and moves with the group.
--   eligibility_value     '50' when PERCENT, a session count when SESSIONS
--   onboarding_completed  '0' | '1', gates the first-launch flow
-- ---------------------------------------------------------------------------
CREATE TABLE settings (
  key    TEXT PRIMARY KEY,
  value  TEXT NOT NULL
);

INSERT INTO settings (key, value) VALUES
  ('group_name',           ''),
  ('default_format',       '5v5'),
  ('default_is_ranked',    '1'),
  ('eligibility_mode',     'PERCENT'),
  ('eligibility_value',    '50'),
  ('onboarding_completed', '0');
