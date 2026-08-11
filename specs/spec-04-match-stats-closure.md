# SPEC-04 — Match Stats & Session Closure

- **ID**: SPEC-04
- **Feature**: Score Entry, Per-Player Stat Steppers, Unassigned Goals, Validation & Session Closure
- **Target Lot**: Lot 3 (L3)
- **Status**: 📝 DRAFT
- **Primary Source**: `docs/statoo-cahier-des-charges.md` §6.2, `docs/statoo-design-system.md` §4.2, §4.5

---

## 1. Context & Goals

Once team composition is ready, the organizer inputs match scores, goals, assists, and cards per player during or right after the game.

The goal of SPEC-04 is to implement:
- Overall team score inputs (`score_a`, `score_b`).
- Accordion list of player stat entries using `StatStepper` (+/- counters for goals, assists, yellow cards, red cards).
- Unassigned goals inputs (`unassigned_goals_a`, `unassigned_goals_b`) for unclaimed/own goals.
- Closure validation rules (blocking errors vs non-blocking goal mismatch warning banner).
- Session closing execution (calculates `result`, updates status to `CLOSED`, triggers auto-backup).
- Session reopening (`status = 'DRAFT'`) and session deletion.

---

## 2. Domain Rules & Invariants

1. **Closure Blocking Controls**:
   - Both `score_a` and `score_b` MUST be specified and >= 0.
   - All selected attendees MUST be assigned to Team A or Team B.
   - Team size difference `|size_a - size_b| <= 1`, unless `allow_uneven_teams = 1`.
2. **Non-Blocking Goal Mismatch Warning**:
   - Condition: `SUM(goals_a) + unassigned_goals_a != score_a` OR `SUM(goals_b) + unassigned_goals_b != score_b`.
   - Action: Display warning banner: *"Écart de buts — Équipe A : X marqués, Y attribués. Vous pouvez clore quand même."*
   - Closing remains **fully enabled**.
3. **Closing Side Effects**:
   - Automatically derives `result` ('A' if `score_a > score_b`, 'B' if `score_b > score_a`, 'DRAW' if equal).
   - Sets `status = 'CLOSED'`.
   - Triggers automated JSON backup snapshot upload to Supabase Storage.
4. **Reopening Sessions**: A closed session can be reopened (`status = 'DRAFT'`). All rankings and standings dynamically recalculate immediately via SQL views.

---

## 3. Data Specifications & Types

### 3.1 Session Close Payload
```ts
export interface SessionClosePayload {
  sessionId: string
  scoreA: number
  scoreB: number
  unassignedGoalsA: number
  unassignedGoalsB: number
  participations: {
    id: string
    goals: number
    assists: number
    yellowCards: number
    redCards: number
  }[]
}
```

---

## 4. UI / UX Specifications

### 4.1 Stats Entry Screen (`/sessions/[id]/stats`)
- **Score Header**:
  - Team A Score (`StatStepper` or large 44px display input) vs Team B Score.
  - Filled `ScoreBar` (40px) preview showing goal ratio.
- **Player Accordion List**:
  - Collapsed row (44px): Avatar, Name, summary line (e.g. *"2 B · 1 P"*).
  - Expanded row: 4 `StatStepper` components:
    - `Buts` (Goals)
    - `Passes` (Assists)
    - `Cartons jaunes` (Yellow Cards)
    - `Cartons rouges` (Red Cards)
- **Unassigned Goals Section**: Steppers for `unassigned_goals_a` and `unassigned_goals_b` with helper copy *"Buts marqués sans buteur identifié (csc, oubli)."*
- **Warning Banner** (if goal mismatch detected): Dark red box (`flag-950` background, `flag-700` border) with informative copy.
- **Bottom Action**: Full-width primary button `"Clôturer la séance"` (56px, `#FFC94F`).

### 4.2 Closed Read-Only View (`/sessions/[id]`)
- Displays final 40px `ScoreBar`, large scores (`4 — 2`), player breakdown columns, unassigned goals count, and overflow menu containing `"Rouvrir la séance"` and `"Supprimer"`.

---

## 5. Technical Implementation Plan

### 5.1 Composable API (`useSessions.ts`)
```ts
export function useSessions() {
  async function updateSessionScores(id: string, scoreA: number, scoreB: number): Promise<void>
  async function updateParticipationStats(participationId: string, stats: Partial<ParticipationStats>): Promise<void>
  async function closeSession(id: string): Promise<{ success: boolean; warnings?: string[] }>
  async function reopenSession(id: string): Promise<void>
  async function deleteSession(id: string): Promise<void>
}
```

---

## 6. Edge Cases & Error Handling

- **Missing Scores**: If `score_a` or `score_b` is null when clicking close, display toast: *"Renseignez les deux scores pour clore."*
- **Network Offline on Close**: Session closes successfully in local SQLite DB. Supabase backup snapshot fails silently, logs pending backup, retries when back online.

---

## 7. Verification & Testing Plan

### Automated Tests
- Test closing validation rejects null scores or size difference > 1 without `allow_uneven_teams`.
- Test goal discrepancy banner condition matches `v_session_summary.has_goal_mismatch`.
- Test transaction rollbacks if updating any participation stat fails.

### Manual Verification
- Enter score 4-2 -> assign 3 goals to Team A -> check warning banner appears -> click "Clôturer la séance" -> verify session status becomes `CLOSED` and standings update.
