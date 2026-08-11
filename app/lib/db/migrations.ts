import { SQLiteDBConnection } from '@capacitor-community/sqlite'

// SQL Migration Statements embedded from docs/001_init.sql and docs/002_views.sql
const MIGRATION_001_INIT = `
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS players (
  id          TEXT PRIMARY KEY,
  name        TEXT NOT NULL,
  nickname    TEXT,
  avatar_url  TEXT,
  is_active   INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
  created_at  TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_players_active ON players (is_active, name);

CREATE TABLE IF NOT EXISTS sessions (
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

  CHECK (
    status = 'DRAFT'
    OR (score_a IS NOT NULL AND score_b IS NOT NULL AND result IS NOT NULL)
  ),

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

CREATE INDEX IF NOT EXISTS idx_sessions_played_at ON sessions (played_at DESC);
CREATE INDEX IF NOT EXISTS idx_sessions_ranked    ON sessions (status, is_ranked);

CREATE TABLE IF NOT EXISTS participations (
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

CREATE INDEX IF NOT EXISTS idx_participations_player  ON participations (player_id);
CREATE INDEX IF NOT EXISTS idx_participations_session ON participations (session_id, team);

CREATE TABLE IF NOT EXISTS meta (
  key    TEXT PRIMARY KEY,
  value  TEXT NOT NULL
);

INSERT OR IGNORE INTO meta (key, value) VALUES ('schema_version', '2');

-- Bring a v1 database up to v2: the settings table below is created
-- unconditionally, so the version can be bumped in the same pass.
UPDATE meta SET value = '2' WHERE key = 'schema_version' AND value = '1';

CREATE TABLE IF NOT EXISTS settings (
  key    TEXT PRIMARY KEY,
  value  TEXT NOT NULL
);

INSERT OR IGNORE INTO settings (key, value) VALUES
  ('group_name',           ''),
  ('default_format',       '5v5'),
  ('default_is_ranked',    '1'),
  ('eligibility_mode',     'PERCENT'),
  ('eligibility_value',    '50'),
  ('onboarding_completed', '0');
`

const MIGRATION_002_VIEWS = `
DROP VIEW IF EXISTS v_session_summary;
DROP VIEW IF EXISTS v_group_totals;
DROP VIEW IF EXISTS v_standings_per_match;
DROP VIEW IF EXISTS v_standings;
DROP VIEW IF EXISTS v_player_stats;
DROP VIEW IF EXISTS v_eligibility_threshold;
DROP VIEW IF EXISTS v_ranked_session_count;
DROP VIEW IF EXISTS v_closed_participations;

CREATE VIEW v_closed_participations AS
SELECT
  p.id,
  p.session_id,
  p.player_id,
  p.team,
  p.goals,
  p.assists,
  p.yellow_cards,
  p.red_cards,
  s.played_at,
  s.is_ranked,
  s.result,
  CASE
    WHEN s.is_ranked = 0        THEN NULL
    WHEN s.result = 'DRAW'      THEN 1
    WHEN s.result = p.team      THEN 3
    ELSE 0
  END AS points
FROM participations p
JOIN sessions s ON s.id = p.session_id
WHERE s.status = 'CLOSED';

CREATE VIEW v_ranked_session_count AS
SELECT COUNT(*) AS total
FROM sessions
WHERE status = 'CLOSED' AND is_ranked = 1;

CREATE VIEW v_eligibility_threshold AS
SELECT
  raw.required_raw,
  CAST(raw.required_raw AS INTEGER)
    + (CASE WHEN raw.required_raw > CAST(raw.required_raw AS INTEGER) THEN 1 ELSE 0 END)
    AS required_sessions
FROM (
  SELECT CASE
    WHEN (SELECT value FROM settings WHERE key = 'eligibility_mode') = 'SESSIONS'
      THEN CAST((SELECT value FROM settings WHERE key = 'eligibility_value') AS REAL)
    ELSE (SELECT total FROM v_ranked_session_count)
         * CAST((SELECT value FROM settings WHERE key = 'eligibility_value') AS REAL)
         / 100.0
  END AS required_raw
) raw;

CREATE VIEW v_player_stats AS
SELECT
  pl.id                                       AS player_id,
  pl.name,
  pl.nickname,
  pl.is_active,

  COUNT(cp.id) FILTER (WHERE cp.is_ranked = 1)                        AS played,
  COUNT(cp.id) FILTER (WHERE cp.is_ranked = 1 AND cp.points = 3)      AS wins,
  COUNT(cp.id) FILTER (WHERE cp.is_ranked = 1 AND cp.points = 1)      AS draws,
  COUNT(cp.id) FILTER (WHERE cp.is_ranked = 1 AND cp.points = 0)      AS losses,
  COALESCE(SUM(cp.points), 0)                                         AS points,

  ROUND(
    COALESCE(SUM(cp.points), 0) * 1.0
    / NULLIF(COUNT(cp.id) FILTER (WHERE cp.is_ranked = 1), 0)
  , 2)                                                                AS points_per_match,

  ROUND(
    COUNT(cp.id) FILTER (WHERE cp.is_ranked = 1 AND cp.points = 3) * 100.0
    / NULLIF(COUNT(cp.id) FILTER (WHERE cp.is_ranked = 1), 0)
  , 1)                                                                AS win_rate,

  COUNT(cp.id)                        AS appearances,
  COALESCE(SUM(cp.goals), 0)          AS goals,
  COALESCE(SUM(cp.assists), 0)        AS assists,
  COALESCE(SUM(cp.yellow_cards), 0)   AS yellow_cards,
  COALESCE(SUM(cp.red_cards), 0)      AS red_cards,

  MAX(cp.played_at)                   AS last_played_at,

  CASE
    WHEN COUNT(cp.id) FILTER (WHERE cp.is_ranked = 1)
         >= (SELECT required_sessions FROM v_eligibility_threshold)
    THEN 1 ELSE 0
  END                                 AS is_eligible,

  MAX(
    0,
    (SELECT required_sessions FROM v_eligibility_threshold)
      - COUNT(cp.id) FILTER (WHERE cp.is_ranked = 1)
  )                                   AS missing_sessions

FROM players pl
LEFT JOIN v_closed_participations cp ON cp.player_id = pl.id
GROUP BY pl.id;

CREATE VIEW v_standings AS
SELECT *
FROM v_player_stats
WHERE played > 0
ORDER BY
  points            DESC,
  points_per_match  DESC,
  played            DESC,
  (goals + assists) DESC,
  name              ASC;

CREATE VIEW v_standings_per_match AS
SELECT *
FROM v_player_stats
WHERE played > 0 AND is_eligible = 1
ORDER BY
  points_per_match  DESC,
  played            DESC,
  (goals + assists) DESC,
  name              ASC;

CREATE VIEW v_group_totals AS
SELECT
  (SELECT COUNT(*) FROM sessions WHERE status = 'CLOSED')                AS sessions_played,
  (SELECT total FROM v_ranked_session_count)                             AS ranked_sessions,
  (SELECT COUNT(*) FROM players WHERE is_active = 1)                     AS active_players,
  (SELECT COUNT(*) FROM players)                                         AS total_players,

  COALESCE(SUM(cp.goals), 0)          AS assigned_goals,
  COALESCE(SUM(cp.assists), 0)        AS assists,
  COALESCE(SUM(cp.yellow_cards), 0)   AS yellow_cards,
  COALESCE(SUM(cp.red_cards), 0)      AS red_cards,

  (SELECT COALESCE(SUM(score_a + score_b), 0)
     FROM sessions WHERE status = 'CLOSED')                              AS total_goals,

  ROUND(
    (SELECT COALESCE(SUM(score_a + score_b), 0) FROM sessions WHERE status = 'CLOSED') * 1.0
    / NULLIF((SELECT COUNT(*) FROM sessions WHERE status = 'CLOSED'), 0)
  , 2)                                                                   AS goals_per_session

FROM v_closed_participations cp;

CREATE VIEW v_session_summary AS
SELECT
  s.id                AS session_id,
  s.played_at,
  s.status,
  s.split_mode,
  s.is_ranked,
  s.allow_uneven_teams,
  s.score_a,
  s.score_b,
  s.result,

  COUNT(p.id) FILTER (WHERE p.team = 'A')  AS size_a,
  COUNT(p.id) FILTER (WHERE p.team = 'B')  AS size_b,
  COUNT(p.id)                              AS attendance,

  COUNT(p.id) FILTER (WHERE p.team = 'A') || 'v' ||
  COUNT(p.id) FILTER (WHERE p.team = 'B')  AS format,

  COALESCE(SUM(p.goals) FILTER (WHERE p.team = 'A'), 0)
    + s.unassigned_goals_a                 AS accounted_goals_a,
  COALESCE(SUM(p.goals) FILTER (WHERE p.team = 'B'), 0)
    + s.unassigned_goals_b                 AS accounted_goals_b,

  CASE
    WHEN s.status <> 'CLOSED' THEN 0
    WHEN COALESCE(SUM(p.goals) FILTER (WHERE p.team = 'A'), 0) + s.unassigned_goals_a <> s.score_a
      OR COALESCE(SUM(p.goals) FILTER (WHERE p.team = 'B'), 0) + s.unassigned_goals_b <> s.score_b
    THEN 1 ELSE 0
  END                                      AS has_goal_mismatch

FROM sessions s
LEFT JOIN participations p ON p.session_id = s.id
GROUP BY s.id;
`

export async function runMigrations(db: SQLiteDBConnection): Promise<void> {
  await db.execute(MIGRATION_001_INIT)
  await db.execute(MIGRATION_002_VIEWS)
}
