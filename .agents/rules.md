# Statoo — Project Guidelines & Rules

## 1. Code & Language Conventions
- **Language**: All source code, identifiers, database schema definition, types, internal documentation, and git commit messages MUST be in **English**.
- **UI Copy**: User-facing text, labels, messages, and placeholders MUST be in **French** (exact copy from the specifications).
- **Commits**: Follow Conventional Commits format (`feat:`, `fix:`, `chore:`, `refactor:`, `docs:`).
- **Simplicity**: No over-engineering (no DDD, no event sourcing, no CQRS).

## 2. Database & Data Architecture (Invariants)
- **Local SQLite DB is Source of Truth**: Powered by `@capacitor-community/sqlite` (native driver on Android, `jeep-sqlite` in web dev).
- **Zero Stored Aggregates**: `participations` is the single source of truth for player stats. Points, totals, standings, percentages, formats (e.g., "5v5"), and goal mismatch flags are ALWAYS derived dynamically via SQL views (`v_player_stats`, `v_standings`, `v_group_totals`, `v_session_summary`, etc.).
- **Session Rules**:
  - Win = 3 pts, Draw = 1 pt, Loss = 0 pts.
  - Points are calculated ONLY for closed, ranked sessions (`status = 'CLOSED'` AND `is_ranked = 1`).
  - Raw stats (goals, assists, yellow/red cards) count for ALL closed sessions (`is_ranked` 0 or 1).
  - Closing requires: non-null scores (`score_a`, `score_b`, derived `result`), all attendees assigned to Team A or B, no player in both teams (`UNIQUE(session_id, player_id)`), team size difference ≤ 1 (unless `allow_uneven_teams = 1`).
  - Goal consistency check (`SUM(goals) + unassigned != score`) triggers a non-blocking warning banner, but closing is still allowed.
- **PRAGMA foreign_keys = ON** on every connection open.
- **Transactions**: All multi-table updates (session creation, stat updates, closing, restoration) MUST run inside SQL transactions.

## 3. Design System & UI Principles ("Terrain de nuit")
- **Dark Theme Only**: Single dark theme based on night pitch aesthetic (`pitch-950`: `#0B120F` base).
- **Color Palette**:
  - `pitch` (neutral): `#0B120F` to `#EAF0EC`.
  - `bib` (accent / Team A): High-visibility bib yellow (`#FFC94F`).
  - `flag` (error / red cards / destructive): `#F0503C`.
- **Team Equality**: Team A (solid `#FFC94F` fill) and Team B (45° hatched pattern over `#1B2721` with `#556860` outline). Never use a second solid color for Team B.
- **Signature Component**: `ScoreBar` (horizontal bar split proportionally to score).
- **Typography**:
  - Titles & Numbers: **Archivo Expanded** (700 weight, `tabular-nums` for columns).
  - UI Text: **Instrument Sans**.
- **Touch Targets**: Minimum 44px for buttons, 52px for `StatStepper` (+/- counters).
- **Tone**: The app may be fun — emoji, expressive icons, illustrated empty states, medals on the standings, micro-animations are all allowed. Only data mechanics stay out: no player ratings, no MVP vote, no stored badge, streak or level (single-user app, and no stored aggregates).

## 4. Backup & Restoration
- **Automated Backup**: JSON snapshot sent to private Supabase Storage bucket automatically after every session closure.
- **Restoration**: Destructive complete local wipe + reimport. Forbidden if backup `schema_version` > app supported schema version.
