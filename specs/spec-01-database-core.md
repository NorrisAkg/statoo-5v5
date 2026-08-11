# SPEC-01 — Database Core & Migrations

- **ID**: SPEC-01
- **Feature**: Local SQLite Storage, Schema Migrations & Transaction Infrastructure
- **Target Lot**: Lot 1 (L1)
- **Status**: 📝 DRAFT
- **Primary Source**: `docs/001_init.sql`, `docs/002_views.sql`, `docs/statoo-cahier-des-charges.md` §3, §4, §8

---

## 1. Context & Goals

Statoo is an offline-first mobile web application running on Android via Capacitor. The local SQLite database is the **single source of truth** for all app data. 

The goal of SPEC-01 is to establish a robust, reliable data access layer that:
- Opens a single persistent SQLite database connection on startup using `@capacitor-community/sqlite` (with `jeep-sqlite` fallback in web dev mode).
- Runs automated sequential SQL migrations based on `meta.schema_version`.
- Enforces strict relational integrity (`PRAGMA foreign_keys = ON;`).
- Provides a transaction execution helper for multi-table updates.

---

## 2. Domain Rules & Invariants

1. **Foreign Keys Enabled**: Every database connection MUST execute `PRAGMA foreign_keys = ON;` immediately upon opening.
2. **Schema Version Tracking**: The current version is stored in `meta.value` where `key = 'schema_version'`.
3. **Sequential Migrations**: Migration scripts (`001_init.sql`, `002_views.sql`) must run strictly in order.
4. **Single Source of Truth**: All analytical queries MUST be read from SQL views (`v_player_stats`, `v_standings`, `v_group_totals`, `v_session_summary`). No aggregate columns exist in storage tables.
5. **Atomic Transactions**: Multi-statement mutations (creating sessions, saving participations, closing sessions, wiping for restore) MUST run inside an explicit transaction block (`BEGIN TRANSACTION ... COMMIT / ROLLBACK`).

---

## 3. Data Specifications & Types

### 3.1 SQLite Tables
- **`players`**: `id` (PK, TEXT), `name` (TEXT, NOT NULL), `nickname` (TEXT), `avatar_url` (TEXT), `is_active` (INTEGER 0/1, DEFAULT 1), `created_at`, `updated_at`.
- **`sessions`**: `id` (PK, TEXT), `played_at` (TEXT, NOT NULL), `status` ('DRAFT'|'CLOSED'), `split_mode` ('RANDOM'|'RANDOM_ADJUSTED'|'MANUAL'), `allow_uneven_teams` (0/1), `is_ranked` (0/1), `score_a`, `score_b`, `result` ('A'|'B'|'DRAW'), `unassigned_goals_a`, `unassigned_goals_b`, `notes`, `created_at`, `updated_at`.
- **`participations`**: `id` (PK, TEXT), `session_id` (FK), `player_id` (FK), `team` ('A'|'B'), `goals`, `assists`, `yellow_cards`, `red_cards`, `created_at`, `updated_at`. `UNIQUE(session_id, player_id)`.
- **`meta`**: `key` (PK, TEXT), `value` (TEXT).

### 3.2 SQL Views
- `v_closed_participations`: Participations filtered by closed sessions with derived point values (3/1/0/NULL).
- `v_ranked_session_count`: Count of closed ranked sessions.
- `v_player_stats`: Comprehensive player statistics with 50% eligibility computation (`is_eligible`).
- `v_standings`: Default standings sorted by points.
- `v_standings_per_match`: Alternative standings for eligible players sorted by points per match.
- `v_group_totals`: Aggregated stats across the entire group.
- `v_session_summary`: Session format ("5v5"), attendee counts, and goal mismatch warning flag (`has_goal_mismatch`).

---

## 4. UI / UX Specifications

- **Startup Loading Screen**: While SQLite is initializing and applying pending migrations, display a minimal dark screen with an inline spinner and the text: *"Initialisation de la base de données..."*.
- **Initialization Error State**: If database initialization fails, display a clear recovery card with a retry button.

---

## 5. Technical Implementation Plan

### 5.1 Files Structure
```
app/
  composables/
    useDb.ts               # Exposes database connection and query helpers
  lib/
    db/
      connection.ts        # Handles Capacitor SQLite & jeep-sqlite setup
      migrations.ts        # Reads and applies 001_init.sql, 002_views.sql
      queries.ts           # Type-safe wrapper functions for views & tables
db/
  migrations/
    001_init.sql
    002_views.sql
```

### 5.2 Composable API (`useDb.ts`)
```ts
interface UseDb {
  isInitialized: Ref<boolean>
  initDb: () => Promise<void>
  execute: (sql: string, params?: any[]) => Promise<void>
  query<T>(sql: string, params?: any[]): Promise<T[]>
  transaction<T>(callback: (db: DatabaseConnection) => Promise<T>): Promise<T>
}
```

---

## 6. Edge Cases & Error Handling

- **Web Browser Dev Mode**: Automatically initialize `jeep-sqlite` custom element if running on web platform.
- **App Backgrounding**: Close or suspend SQLite connection cleanly when Capacitor app pauses; reopen on resume.
- **Corrupted Schema**: If `meta` table is missing, initialize schema from version 0 to current version safely.

---

## 7. Verification & Testing Plan

### Automated Checks
- Test SQL migration execution on clean database instance.
- Verify `PRAGMA foreign_keys` enforcement by attempting to insert a participation with a non-existent `player_id` (must throw constraint error).
- Test cascading deletion on `sessions` -> `participations`.
- Test restricted deletion on `players` -> `participations` (must throw constraint error).

### Manual Verification
- Launch app in web dev mode (`npm run dev`) -> verify `jeep-sqlite` initializes without errors.
- Launch app on Android emulator/device -> verify native Capacitor SQLite plugin connects cleanly.
