# SPEC-05 — Standings & Group Statistics

- **ID**: SPEC-05
- **Feature**: Standings Tables (Points & Efficiency), Secondary Rankings & Group Totals Dashboard
- **Target Lot**: Lot 4 (L4)
- **Status**: 📝 DRAFT
- **Primary Source**: `docs/002_views.sql`, `docs/statoo-cahier-des-charges.md` §6.3, §6.4, `docs/statoo-design-system.md` §4.4

---

## 1. Context & Goals

The standings page is the core product feature viewed after every match night. It displays player rankings and global group statistics.

The goal of SPEC-05 is to implement:
- Default standings view (Total Points tab).
- Efficiency standings view (Points-per-Match tab, gated by the configurable participation threshold — default 50%).
- Secondary rankings cards (Top Goalscorers, Top Assist Providers, Discipline/Cards).
- Global group statistics dashboard (`v_group_totals`).

---

## 2. Domain Rules & Invariants

1. **Zero JS Calculations**: All ranking numbers, points per match, win rates, and threshold eligibility flags MUST be read directly from SQL views (`v_standings`, `v_standings_per_match`, `v_group_totals`).
2. **Default Standings Sorting**:
   - Primary: `points` DESC
   - Tie-breaker 1: `points_per_match` DESC
   - Tie-breaker 2: `played` DESC
   - Tie-breaker 3: `(goals + assists)` DESC
   - Tie-breaker 4: `name` ASC
3. **Efficiency Standings Sorting & Eligibility Threshold**:
   - The threshold is **configurable**, not hardcoded. `v_eligibility_threshold.required_sessions` derives it from `settings` (SPEC-08) and is the single source of truth:
     - `eligibility_mode = 'PERCENT'` (default, `eligibility_value = 50`): a share of `v_ranked_session_count.total`, so the bar moves with the group. Rounded **up** — 10.5 required means 11.
     - `eligibility_mode = 'SESSIONS'`: a fixed session count set by the organizer at onboarding (screen 25).
   - A player is eligible when `played` (in ranked closed sessions) >= `required_sessions`. The flag is `v_player_stats.is_eligible`; never recompute it in JS.
   - Main table displays eligible players sorted by `points_per_match` DESC.
   - Players below the threshold are listed in a separate bottom block titled *"SOUS LE SEUIL"* with exact missing count: *"Éric — il manque 3 séances"*, read from `v_player_stats.missing_sessions`.
4. **Secondary Rankings Scope**: Goalscorers, assist providers, and cards count across ALL closed sessions (ranked or unranked/friendly).
5. **No Visual Badges / Medals**: Rank 1 is indicated solely by `#FFC94F` colored rank number. No trophies, crowns, or medals.
6. **No Horizontal Scroll**: `StandingsTable` MUST fit screen width without horizontal scrolling. `J` (Played) column is ALWAYS visible.

---

## 3. Data Specifications & Types

### 3.1 Views Consumed
- `v_standings`: Consumes `v_player_stats` where `played > 0` ordered by total points.
- `v_standings_per_match`: Consumes `v_player_stats` where `played > 0` and `is_eligible = 1` ordered by points per match.
- `v_eligibility_threshold`: `required_sessions` — used verbatim in the footnote *"Il faut N séances pour figurer au classement."* (screen 12).
- `v_group_totals`: Aggregated counts (`sessions_played`, `ranked_sessions`, `active_players`, `total_players`, `total_goals`, `assigned_goals`, `unassigned_goals`, `assists`, `yellow_cards`, `red_cards`, `goals_per_session`). `unassigned_goals` is the "Écart" row — derived, never subtracted in JS.

### 3.2 Secondary Ranking Views (to add to `002_views.sql`)
Each reads `v_player_stats` (all closed sessions, friendlies included), filters out the zero rows and limits to 5:
- `v_top_scorers` — ordered by `goals` DESC, `name` ASC.
- `v_top_assists` — ordered by `assists` DESC, `name` ASC.
- `v_top_cards` — ordered by `red_cards` DESC, `yellow_cards` DESC, `name` ASC; exposes both counts.

---

## 4. UI / UX Specifications

### 4.1 Standings Screen (`/standings`)
- **Segmented Control**: Tab selector between `"Points"` and `"Pts/match"`.
- **Standings Table**:
  - Headers: `(Rank)` · `JOUEUR` · `J` · `V` · `N` · `D` · `PTS` · `PTS/M`.
  - Column `PTS` in active bright text (`pitch-50`), all other numeric columns in muted text (`pitch-300`).
  - Column numbers in `Archivo Expanded` with `font-variant-numeric: tabular-nums`.
- **Footnote** (Points tab, screen 12): *"Seules les séances classées comptent. Il faut N séances pour figurer au classement."* where N is `required_sessions`.
- **Under Threshold Block** (in Pts/match tab, screen 13):
  - Divider with header `"SOUS LE SEUIL"`.
  - Dimmed rows displaying player name and text *"il manque N séances"*.

### 4.2 Secondary Rankings (`/standings`, third tab "Secondaires")
Screen 14 is reached through a third segment of the control — `Points` · `Pts/match` · `Secondaires` — rather than by scrolling past the table, which would bury it under a long roster.
- 3 Stacked Cards:
  1. **MEILLEURS BUTEURS**: Rank, Avatar, Name, Goals count.
  2. **MEILLEURS PASSEURS**: Rank, Avatar, Name, Assists count.
  3. **DISCIPLINE (CARTONS)**: Yellow card indicator (3x10px yellow bar + count) & Red card indicator (red bar + count).
- Helper note: *"Ces classements comptent toutes les séances, amicales incluses."*

### 4.3 Group Statistics Screen (`/stats`)
- 2-Column grid of KPI tiles:
  - `SÉANCES JOUÉES`, `DONT CLASSÉES`, `JOUEURS ACTIFS`, `JOUEURS AU TOTAL`, `BUTS TOTAUX`, `BUTS PAR SÉANCE`.
- **Attribution Card**: `Buts marqués` / `Buts attribués à un joueur` / `Écart` — the gap in `--danger-text` when non-zero. Footnote *"Buts marqués sans buteur identifié."*
- **Discipline Card**: `Passes décisives`, `Cartons jaunes`, `Cartons rouges`.

---

## 5. Technical Implementation Plan

### 5.1 Composable API (`useStandings.ts`)
```ts
export function useStandings() {
  const standingsPoints = ref<PlayerStats[]>([])
  const standingsPerMatch = ref<PlayerStats[]>([])
  const ineligiblePlayers = ref<PlayerStats[]>([])
  const requiredSessions = ref<number>(0)
  const topScorers = ref<PlayerStats[]>([])
  const topAssists = ref<PlayerStats[]>([])
  const topCards = ref<PlayerStats[]>([])
  const groupTotals = ref<GroupTotals | null>(null)

  async function fetchStandings(): Promise<void>
  async function fetchSecondaryRankings(): Promise<void>
  async function fetchGroupTotals(): Promise<void>
}
```

---

## 6. Edge Cases & Error Handling

- **Zero Closed Sessions**: Display empty state: *"Le classement apparaîtra après la première séance close."*
- **No Eligible Players**: If 0 players reach the threshold, the Pts/match table is empty — show the notice with the current session count and `required_sessions`, and render every player in the "SOUS LE SEUIL" block rather than a blank screen.
- **Threshold above the sessions played**: with `eligibility_mode = 'SESSIONS'` and a value larger than the number of ranked sessions, nobody can ever qualify. Legal state, same handling as above.

---

## 7. Verification & Testing Plan

### Automated Tests
- Test sorting order of `v_standings` and `v_standings_per_match` SQL views.
- Test 50% eligibility calculation threshold formula.

### Manual Verification
- View Standings screen -> switch between Points and Pts/match tabs -> verify column alignment and `tabular-nums` formatting.
