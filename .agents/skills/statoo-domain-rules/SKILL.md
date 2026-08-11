---
name: statoo-domain-rules
description: Business logic rules, session workflows, team splitting contracts, Supabase JSON backup/restore specifications, and delivery lot roadmap for Statoo 5v5.
---

# Statoo — Domain Rules & Specifications Skill

## Overview
This skill covers the domain rules, invariants, algorithms, backup logic, and delivery roadmap for Statoo 5v5.

## Core Business Invariants
1. **`participations` is the single source of truth**: No accumulated stats or standings stored in table columns.
2. **Match Scoring**: 1 session = 1 match. 3 points for a win, 1 point for a draw, 0 points for a loss.
3. **Session Closure Rules**:
   - `score_a` and `score_b` MUST be provided.
   - All attendees MUST be assigned to Team A or Team B.
   - No player can be in both teams (`UNIQUE(session_id, player_id)`).
   - Team size difference must be ≤ 1 (`|size_a - size_b| <= 1`), unless `allow_uneven_teams = 1`.
4. **Goal Mismatch Warning**:
   - If `SUM(goals_a) + unassigned_goals_a != score_a` OR `SUM(goals_b) + unassigned_goals_b != score_b`:
   - Display a non-blocking warning banner: *"Écart de buts — Équipe A : X marqués, Y attribués. Vous pouvez clore quand même."*
   - Closure remains enabled!
5. **Ranked vs Unranked Sessions**:
   - Points count ONLY for sessions with `status = 'CLOSED'` AND `is_ranked = 1`.
   - Goals, assists, and yellow/red cards count for ALL closed sessions (`is_ranked` = 0 or 1).
6. **Archiving vs Deleting Players**:
   - Players who have participations CANNOT be deleted (`ON DELETE RESTRICT`). They must be archived (`is_active = 0`).
   - Archived players are excluded from new session player selection, but remain visible in historical standings and session details.
   - Permanent deletion is ONLY available for players with 0 participations.

## Team Splitter Architecture
- Interface abstraction `TeamSplitter` in `lib/splitter/TeamSplitter.ts`.
- `RandomSplitter.ts`: Shuffles active selected players using Fisher-Yates, sets `split_mode = 'RANDOM'`.
- Manual team modifications (`TeamAssignment` ops `move`, `add`, `remove`): Updates player teams and switches `split_mode` to `'MANUAL'`.
- Note: Manual team adjustment is NOT a splitter implementation; it directly mutates `TeamAssignment`.

## Backup & Restore Specification
- **Snapshot Format**: JSON export containing `meta` (with `schema_version: "1"` at top), `players`, `sessions`, `participations`.
- **Filename Pattern**: `statoo-backup-YYYYMMDD-HHmmss.json`.
- **Destination**: Supabase Storage private bucket (RLS owner).
- **Trigger**: Automatic backup attempt immediately after session closure + manual backup trigger in settings.
- **Offline Handling**: Silent non-blocking failure, status marked as "Sauvegarde en attente", retried on next app launch with network connectivity.
- **Retention**: Keep 20 most recent backups; automatically delete older ones.
- **Restoration**: Complete local wipe + reimport. Rejection if backup `schema_version` > app supported schema version.

## Delivery Lots Roadmap (L1 to L6)
- **L1**: SQLite connection setup, schema migrations (`001_init.sql`, `002_views.sql`), Player CRUD & archiving.
- **L2**: Sessions creation, player selection, random drawing (`RandomSplitter`), manual composition editing.
- **L3**: Stat entry (`StatStepper`), unassigned goals, closure validation rules & warning banner.
- **L4**: Standings views, points & points-per-match tabs (with 50% eligibility threshold), global group statistics.
- **L5**: Supabase Storage JSON backup & restoration workflows.
- **L6**: Capacitor Android APK build setup, app icon/splash, device testing.
