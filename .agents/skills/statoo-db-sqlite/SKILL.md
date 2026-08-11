---
name: statoo-db-sqlite
description: Expert skill for SQLite schema, SQL views, Capacitor SQLite integration, database migrations, and queries for Statoo 5v5.
---

# Statoo — SQLite & Data Access Skill

## Overview
This skill provides the authoritative database reference and implementation guidelines for Statoo.

## Data Model Reference

### Tables (`docs/001_init.sql`)
1. **`players`**
   - `id` (TEXT, PK): UUID or unique slug.
   - `name` (TEXT, NOT NULL): Player full name.
   - `nickname` (TEXT): Optional nickname.
   - `avatar_url` (TEXT): Optional avatar asset URI or path.
   - `is_active` (INTEGER 0/1, DEFAULT 1): 1 for active, 0 for archived.
   - `created_at`, `updated_at` (TEXT ISO timestamp).

2. **`sessions`**
   - `id` (TEXT, PK).
   - `played_at` (TEXT ISO timestamp, NOT NULL).
   - `status` ('DRAFT' | 'CLOSED', DEFAULT 'DRAFT').
   - `split_mode` ('RANDOM' | 'RANDOM_ADJUSTED' | 'MANUAL', DEFAULT 'MANUAL').
   - `allow_uneven_teams` (INTEGER 0/1, DEFAULT 0).
   - `is_ranked` (INTEGER 0/1, DEFAULT 1).
   - `score_a`, `score_b` (INTEGER, NULL in draft, >= 0 when closed).
   - `result` ('A' | 'B' | 'DRAW', derived check constraint).
   - `unassigned_goals_a`, `unassigned_goals_b` (INTEGER, DEFAULT 0).
   - `notes` (TEXT).
   - `created_at`, `updated_at`.

3. **`participations`** (Single source of truth)
   - `id` (TEXT, PK).
   - `session_id` (FK → `sessions.id` ON DELETE CASCADE).
   - `player_id` (FK → `players.id` ON DELETE RESTRICT).
   - `team` ('A' | 'B').
   - `goals`, `assists`, `yellow_cards`, `red_cards` (INTEGER >= 0, DEFAULT 0).
   - `UNIQUE (session_id, player_id)`.

4. **`meta`**
   - `key` (PK), `value` (TEXT) — holds `schema_version` (starts at '1').

### SQL Views Reference (`docs/002_views.sql`)
- **`v_closed_participations`**: Joins closed sessions with participations, calculates 3/1/0 points for ranked sessions (NULL if unranked).
- **`v_ranked_session_count`**: Counts total `CLOSED` & `is_ranked = 1` sessions (used for 50% eligibility threshold).
- **`v_player_stats`**: Computes `played`, `wins`, `draws`, `losses`, `points`, `points_per_match`, `win_rate`, `appearances`, `goals`, `assists`, `yellow_cards`, `red_cards`, `last_played_at`, `is_eligible`.
- **`v_standings`**: Default ranking view (total points DESC, points_per_match DESC, played DESC, goals+assists DESC, name ASC).
- **`v_standings_per_match`**: Alternative ranking (points_per_match DESC for players with `is_eligible = 1`).
- **`v_group_totals`**: Aggregate summary of sessions, ranked sessions, active/total players, total goals, assigned goals, assists, cards, goals per session.
- **`v_session_summary`**: Computes team sizes (`size_a`, `size_b`), derived format string (e.g. "5v5", "6v4"), accounted goals, and `has_goal_mismatch` (1 if accounted goals != score).

## Database Guidelines
- **Always run `PRAGMA foreign_keys = ON;`** when opening the SQLite connection.
- **Do not cache stats in JS**: Always query the views (`v_standings`, `v_player_stats`, etc.) to render UI lists.
- **Transactions**: Wrap multi-row operations (`sessions` + `participations`) in SQL transactions (`BEGIN TRANSACTION` / `COMMIT`).
- **Web vs Native**: Use `@capacitor-community/sqlite` native driver for Capacitor APK builds, and `jeep-sqlite` custom element for browser development.
