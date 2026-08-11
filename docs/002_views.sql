-- Statoo — aggregation views
-- Every number below is derived. Nothing is ever stored as a running total.

-- ---------------------------------------------------------------------------
-- Base: one row per participation in a closed session, with its point value.
-- Points only exist for ranked sessions; goals/assists/cards always count.
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- Moving denominator for the eligibility threshold.
-- ---------------------------------------------------------------------------
CREATE VIEW v_ranked_session_count AS
SELECT COUNT(*) AS total
FROM sessions
WHERE status = 'CLOSED' AND is_ranked = 1;

-- ---------------------------------------------------------------------------
-- How many ranked sessions a player must have played to appear in the
-- Pts/match standings. Read from settings (SPEC-08), never hardcoded:
--   PERCENT  -> a share of the ranked sessions played so far (default 50%)
--   SESSIONS -> a fixed count set by the organizer
-- Rounded up: 10.5 required sessions means 11.
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- Per-player stats. One row per player, including archived ones.
-- ---------------------------------------------------------------------------
CREATE VIEW v_player_stats AS
SELECT
  pl.id                                       AS player_id,
  pl.name,
  pl.nickname,
  pl.is_active,

  -- Ranked-only figures
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

  -- Raw stats: every closed session counts, ranked or not
  COUNT(cp.id)                        AS appearances,
  COALESCE(SUM(cp.goals), 0)          AS goals,
  COALESCE(SUM(cp.assists), 0)        AS assists,
  COALESCE(SUM(cp.yellow_cards), 0)   AS yellow_cards,
  COALESCE(SUM(cp.red_cards), 0)      AS red_cards,

  MAX(cp.played_at)                   AS last_played_at,

  -- Eligible for the points-per-match ranking
  CASE
    WHEN COUNT(cp.id) FILTER (WHERE cp.is_ranked = 1)
         >= (SELECT required_sessions FROM v_eligibility_threshold)
    THEN 1 ELSE 0
  END                                 AS is_eligible,

  -- Feeds the "SOUS LE SEUIL" block: "Éric — il manque 3 séances"
  MAX(
    0,
    (SELECT required_sessions FROM v_eligibility_threshold)
      - COUNT(cp.id) FILTER (WHERE cp.is_ranked = 1)
  )                                   AS missing_sessions

FROM players pl
LEFT JOIN v_closed_participations cp ON cp.player_id = pl.id
GROUP BY pl.id;

-- ---------------------------------------------------------------------------
-- Default standings: total points. Tie-break pts/match, then J, then G+A.
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- Alternative standings: efficiency, gated by the configured threshold.
-- ---------------------------------------------------------------------------
CREATE VIEW v_standings_per_match AS
SELECT *
FROM v_player_stats
WHERE played > 0 AND is_eligible = 1
ORDER BY
  points_per_match  DESC,
  played            DESC,
  (goals + assists) DESC,
  name              ASC;

-- ---------------------------------------------------------------------------
-- Secondary rankings (screen 14). These count EVERY closed session, friendlies
-- included — unlike the standings above, which are ranked-only. Top 5, and a
-- player with nothing to show never appears.
-- ---------------------------------------------------------------------------
CREATE VIEW v_top_scorers AS
SELECT player_id, name, nickname, is_active, goals
FROM v_player_stats
WHERE goals > 0
ORDER BY goals DESC, name ASC
LIMIT 5;

CREATE VIEW v_top_assists AS
SELECT player_id, name, nickname, is_active, assists
FROM v_player_stats
WHERE assists > 0
ORDER BY assists DESC, name ASC
LIMIT 5;

-- Reds outrank yellows: one red is worse than any number of yellows.
CREATE VIEW v_top_cards AS
SELECT player_id, name, nickname, is_active, yellow_cards, red_cards
FROM v_player_stats
WHERE yellow_cards > 0 OR red_cards > 0
ORDER BY red_cards DESC, yellow_cards DESC, name ASC
LIMIT 5;

-- ---------------------------------------------------------------------------
-- Global totals for the group.
-- ---------------------------------------------------------------------------
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

  -- Actual goals include the ones nobody claimed
  (SELECT COALESCE(SUM(score_a + score_b), 0)
     FROM sessions WHERE status = 'CLOSED')                              AS total_goals,

  -- Goals with no identified scorer (own goals, forgotten entries).
  -- Clamped: a session may be closed with more scorers than goals.
  MAX(
    0,
    (SELECT COALESCE(SUM(score_a + score_b), 0) FROM sessions WHERE status = 'CLOSED')
      - COALESCE(SUM(cp.goals), 0)
  )                                                                      AS unassigned_goals,

  ROUND(
    (SELECT COALESCE(SUM(score_a + score_b), 0) FROM sessions WHERE status = 'CLOSED') * 1.0
    / NULLIF((SELECT COUNT(*) FROM sessions WHERE status = 'CLOSED'), 0)
  , 2)                                                                   AS goals_per_session

FROM v_closed_participations cp;

-- ---------------------------------------------------------------------------
-- Session summary: team sizes (the "format"), goal consistency check.
-- ---------------------------------------------------------------------------
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

  -- Derived format label, e.g. "5v5", "6v4"
  COUNT(p.id) FILTER (WHERE p.team = 'A') || 'v' ||
  COUNT(p.id) FILTER (WHERE p.team = 'B')  AS format,

  COALESCE(SUM(p.goals) FILTER (WHERE p.team = 'A'), 0)
    + s.unassigned_goals_a                 AS accounted_goals_a,
  COALESCE(SUM(p.goals) FILTER (WHERE p.team = 'B'), 0)
    + s.unassigned_goals_b                 AS accounted_goals_b,

  -- Non-blocking warning flag for the UI
  CASE
    WHEN s.status <> 'CLOSED' THEN 0
    WHEN COALESCE(SUM(p.goals) FILTER (WHERE p.team = 'A'), 0) + s.unassigned_goals_a <> s.score_a
      OR COALESCE(SUM(p.goals) FILTER (WHERE p.team = 'B'), 0) + s.unassigned_goals_b <> s.score_b
    THEN 1 ELSE 0
  END                                      AS has_goal_mismatch

FROM sessions s
LEFT JOIN participations p ON p.session_id = s.id
GROUP BY s.id;
