# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Statoo 5v5** — offline-first mobile app (Nuxt 4 + Capacitor) for a single organizer to track 5-a-side football sessions: players, team draws, match stats, standings. Local SQLite is the only datastore; Supabase Storage is used solely for JSON backups (not yet implemented).

Two delivery channels from the same web build: an **Android APK** via Capacitor (native SQLite) and an **installable PWA** for iOS, where the App Store is the only alternative ([spec-09](specs/spec-09-pwa-delivery.md)). The PWA needs the shell hosted over HTTPS — session data still never leaves the device.

## Commands

```bash
npm run dev        # Nuxt dev server (SPA, ssr: false)
npm run build      # production build
npm run generate   # static generation -> .output/public, what the PWA deploys
npm run preview
npm run icons      # regenerate the PWA/app icons into public/
```

`postinstall` runs `nuxt prepare` and copies `sql-wasm.wasm` into `public/` and `public/assets/` — the web SQLite driver breaks without it, so re-run `npm install` if those files go missing.

There is no test runner, linter, or type-check script configured.

## Architecture

### Data layer (the important part)

Three-layer stack, no ORM:

- [app/lib/db/connection.ts](app/lib/db/connection.ts) — module-level singleton connection. Branches on `Capacitor.getPlatform()`: native SQLite on Android, `jeep-sqlite` custom element + `initWebStore()` in the browser. Enables `PRAGMA foreign_keys = ON` on every open.
- [app/lib/db/migrations.ts](app/lib/db/migrations.ts) — the schema and views are **embedded as template strings**, mirroring [docs/001_init.sql](docs/001_init.sql) and [docs/002_views.sql](docs/002_views.sql). Changing the schema means editing **both** the `.sql` doc and the embedded string. Views are `DROP`ped and recreated on every app start, so view changes apply without a migration step; table changes do not (only `CREATE TABLE IF NOT EXISTS`).
- [app/lib/db/queries.ts](app/lib/db/queries.ts) — all SQL lives here as exported functions taking `db` as first arg. Composables never write raw SQL.

Composables ([useDb](app/composables/useDb.ts), [usePlayers](app/composables/usePlayers.ts), [useSessions](app/composables/useSessions.ts)) hold module-level reactive state and call into `queries.ts`. `useDb().initDb()` is invoked once from [app/app.vue](app/app.vue); the router/layout is not rendered until it resolves, so `getDb()` is safe inside pages.

**Every write must be followed by `saveWebStore()`** (from `connection.ts`) — on web, SQLite lives in memory and is only persisted to IndexedDB by that call. Forgetting it silently loses data on reload.

### Zero stored aggregates

`participations` is the single source of truth. Points, standings, win rates, the `"5v5"` format string, the ranking eligibility threshold, and the goal-mismatch flag are **always** derived by SQL views — never computed and stored in JS or in table columns. When adding a stat, extend a view (`v_player_stats`, `v_standings`, `v_group_totals`, `v_session_summary`, …) rather than accumulating in a composable.

### Session lifecycle

`DRAFT → CLOSED` (reopenable). Scoring: win 3 / draw 1 / loss 0, counted only when `status = 'CLOSED' AND is_ranked = 1`. Raw stats (goals, assists, cards) count for all closed sessions regardless of `is_ranked`. Closure requires non-null scores, all attendees assigned to A or B, and `|size_a - size_b| <= 1` unless `allow_uneven_teams = 1`. A goal mismatch (`SUM(goals) + unassigned != score`) raises a **non-blocking** warning banner — closing is still allowed.

Team splitting goes through the `TeamSplitter` interface ([app/lib/splitter/](app/lib/splitter/)); `RandomSplitter` is Fisher–Yates and sets `split_mode = 'RANDOM'`. A manual swap afterwards upgrades it to `'RANDOM_ADJUSTED'`. Manual editing is not a splitter implementation.

Players with participations can only be archived (`is_active = 0`), never deleted — the FK is `ON DELETE RESTRICT`.

### Settings

Organizer preferences live in the `settings` key/value table (schema v2, seeded with defaults by migration 001): `group_name`, `default_format`, `default_is_ranked`, `eligibility_mode`, `eligibility_value`, `onboarding_completed`. A new preference is a new row, never a new column.

The Pts/match eligibility threshold is **configurable, and interpreted only in SQL**: `v_eligibility_threshold` turns `eligibility_mode` + `eligibility_value` into `required_sessions` (a share of the ranked sessions played when `PERCENT` — the default, 50% — or a fixed count when `SESSIONS`, always rounded up). `v_player_stats` reads it for `is_eligible` and `missing_sessions`. Never re-derive the threshold in JS. See [spec-08](specs/spec-08-onboarding-settings.md).

## Conventions

- **French UI, English code.** All user-facing strings, labels, and error messages are French (copied verbatim from the specs); identifiers, types, comments, and commit messages are English. Conventional Commits.
- **Dark-first, with a light theme that follows the OS** ("Terrain de nuit"). There is no in-app toggle and no stored theme preference — only `prefers-color-scheme`. Palettes live in [app/assets/css/main.css](app/assets/css/main.css) as Tailwind v4 `@theme` tokens and are mapped to Nuxt UI roles in [app.config.ts](app.config.ts): `pitch` (neutral), `bib` (`#FFC94F`, primary + Team A), `flag` (error/red cards).
- **Components reference role tokens, never raw hex or raw palette classes.** `--ground`, `--surface`, `--hairline`, `--text-muted`, `--accent-text`… are defined in `main.css` and swapped wholesale under `@media (prefers-color-scheme: light)`; the substitution table is in [spec-07](specs/spec-07-design-system-ui.md) §2.2. Two rules survive the swap: the Team A yellow `#FFC94F` is identical in both themes and is **a fill only** — as text, a number or an icon the accent becomes `--accent-text` (`#8A5E00` in light, where the yellow drops to 1.6:1).
- **Team A/B are visually equal**: Team A is solid `bib-400`; Team B is the `.bg-team-b-hatch` 45° hatch. Never give Team B a second solid color, and never use a home/away hierarchy.
- Fonts: Archivo Expanded (`.font-display`) for titles and all numbers, with `.tnum` for tabular figures in columns; Instrument Sans for body.
- Touch targets ≥ 44px, 52px for `StatStepper` +/− buttons. Stat entry must never open a virtual keyboard.
- **No gamification** — no ratings, MVP votes, badges, streaks, trophies, or medals. Rank 1 is highlighted with color only.
- Layout is a fixed 480px-max mobile frame with a 64px bottom nav ([app/layouts/default.vue](app/layouts/default.vue)). The scroll container already reserves that height **plus `env(safe-area-inset-bottom)`** for the iPhone home indicator, so pages no longer add their own `pb-[64px]`.

## Reference documents

- [specs/](specs/) — eight numbered functional specs (SPEC-01…08) mapped to delivery lots L1–L6, with the exact French UI copy. Consult the relevant spec before implementing a feature.
- [docs/statoo-cahier-des-charges.md](docs/statoo-cahier-des-charges.md) — original requirements; [docs/statoo-design-system.md](docs/statoo-design-system.md) — the design rationale.
- [docs/design-mockup-template.html](docs/design-mockup-template.html) — **the current visual reference**: 25 screens in dark, then the same 25 in light, plus the substitution table. Supersedes the older `design-mockup.html` (7 screens).
- [.agents/rules.md](.agents/rules.md) and [.agents/skills/](.agents/skills/) — condensed rule set duplicated from the above.

## Known gaps

- Lot L5 (Supabase backup/restore) is unimplemented — no `lib/backup/`. On iOS this is the *only* real guarantee against storage eviction, so it is not optional there.
- Lot **L6a** (Android APK) is unimplemented: no `capacitor.config.ts`, no `android/`, and `@capacitor/cli` is not even installed despite `@capacitor/core` and `@capacitor/android` being there. The machine is ready (JDK 17, SDK with platforms 31–36).
- Lot **L6b** (PWA) is built but **never verified on a device**: manifest, service worker, icons and safe-area handling exist and the assets serve correctly locally, but nobody has installed it on an iPhone. The `appId` for the APK is also still undecided.
- `nanoid` and `localforage` are imported in source but absent from `package.json` (resolved transitively). Add them explicitly before touching dependency versions.
- `closeSession()` in `queries.ts` writes score-derived `result` but does not wrap the multi-table stat update in a transaction, contrary to the stated invariant.
- The **layout** of the earlier Tailwind pages (home, players, settings) still does not match the template screens — cards where the mockup uses flat filet-separated lists, 56px round avatars instead of 36px rounded squares. Their colors are on the role tokens, so only the geometry is left to redo.
- `composition.vue` uses 🎲 emoji on its draw button and split-mode badge, against the no-gamification rule, and its layout diverges from screen 7.
- SPEC-08 (settings table, `v_eligibility_threshold`) is specified and **the schema is in place**, but the onboarding screens, `useSettings.ts` and the Réglages wiring are not written yet. `settings` rows currently just sit at their defaults.
- L4 is complete (standings, "SOUS LE SEUIL", secondary rankings, group stats), all read from views through `useStandings.ts`. `/standings` and its two components are the only screens already written against the role tokens — the rest of the app still hardcodes hex.
