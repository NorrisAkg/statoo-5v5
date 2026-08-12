# SPEC-03 — Sessions & Team Composition

- **ID**: SPEC-03
- **Feature**: Session Creation, Attendee Selection, Team Splitting Algorithms & Composition Editing
- **Target Lot**: Lot 2 (L2)
- **Status**: 📝 DRAFT
- **Primary Source**: `docs/statoo-cahier-des-charges.md` §6.2, `docs/statoo-design-system.md` §4.1, §4.6

---

## 1. Context & Goals

Setting up a match session starts by picking the date, selecting attendees, defining session parameters (ranked vs friendly, allow uneven teams), then choosing **how the teams are decided** — an immediate draw, or composing them by hand.

The goal of SPEC-03 is to implement:
- Session creation workflow (sets status to `DRAFT`), with two exits: draw now or compose by hand.
- Active player multi-selection grid for attendees, with select-all / select-none.
- Random team drawer (`RandomSplitter` implementation using Fisher-Yates shuffle).
- Interactive 2-column composition screen (Team A vs Team B), plus an *"À placer"* queue for attendees with no team yet.
- Click-to-move player assignment between Team A and Team B.
- Overwrite confirmation modal when re-triggering random split on an existing draft.

---

## 2. Domain Rules & Invariants

1. **Initial Status**: New sessions are always created with `status = 'DRAFT'`.
2. **Minimum attendance**: **6 attendees** (`MIN_ATTENDEES`), i.e. at least a 3v3. Below that the format stops being football and the ranking it feeds is meaningless, so this check is **blocking** — both buttons are disabled and `createSession` throws. It is deliberately stricter than the informative onboarding footnote (SPEC-08 §4.3). A 3v3 is an exceptional evening, not the target, and nothing forces a 5v5: the format is derived, never stored.
3. **Two creation paths**, chosen by the button pressed, never inferred:
   - *"Créer et tirer au sort"* → `RandomSplitter` runs immediately, teams are stored, `split_mode = 'RANDOM'`. The composition screen opens on a balanced draft.
   - *"Composer à la main"* → attendees are stored with `team = NULL`, `split_mode = 'MANUAL'`.
   Assigning every attendee to Team A as a placeholder is forbidden: it displays a bogus `"Nv0"` format and lies about `split_mode`.
4. **Unassigned attendees**: `participations.team` is nullable (schema v3). `NULL` means *present, not yet placed* and is reachable only on a `DRAFT`. Closure requires `unassigned_players = 0`, which `v_session_summary` derives — the rule "every attendee assigned to A or B" was trivially true while the column was `NOT NULL`.
5. **Split Mode**:
   - Manual composition and manual click-to-move edits set `split_mode = 'MANUAL'`.
   - Executing the random draw sets `split_mode = 'RANDOM'`.
   - If a manual adjustment occurs *after* a random draw, `split_mode` switches to `'RANDOM_ADJUSTED'`.
6. **Format Label**: The session format (e.g. `"5v5"`, `"6v5"`, `"4v4"`) is **never stored**; it is derived from `COUNT(team = 'A')` vs `COUNT(team = 'B')` in SQL view `v_session_summary`. Unassigned attendees count in neither, so the badge is hidden until at least one player is placed.
7. **Equal Hierarchy**: Team A and Team B have identical visual weight. Team A uses solid `#FFC94F` bib yellow; Team B uses 45° hatched pattern over `#1B2721` with `#556860` outline. This holds for the *"À placer"* A/B buttons too.
8. **Re-drawing Teams**: The *"Tirer au sort"* button is ALWAYS accessible during `DRAFT`. Triggering it requires explicit user confirmation via a bottom sheet modal (*"Remplacer la composition actuelle ?"*) whenever a team already holds someone. The draw covers **every** attendee, including those still in the *"À placer"* queue.
9. **A redraw preserves stats**: teams are `UPDATE`d, never deleted and reinserted, so goals, assists and cards already entered survive — which is what the confirmation sheet promises.

---

## 3. Data Specifications & Types

### 3.1 Interfaces
```ts
export type SplitMode = 'RANDOM' | 'RANDOM_ADJUSTED' | 'MANUAL'
export type SessionStatus = 'DRAFT' | 'CLOSED'
export type Team = 'A' | 'B'

export interface SessionDraft {
  id: string
  played_at: string
  status: SessionStatus
  split_mode: SplitMode
  allow_uneven_teams: boolean
  is_ranked: boolean
  notes?: string
}

export interface TeamAssignment {
  player_id: string
  name: string
  nickname?: string
  /** `null` = present but not yet placed. Only possible on a DRAFT. */
  team: Team | null
}

export interface TeamSplitter {
  split(players: { id: string; name: string }[]): { teamA: string[]; teamB: string[] }
}
```

---

## 4. UI / UX Specifications

### 4.1 New Session Screen (`/sessions/new`)
- **Section "QUAND"**: Date & Time pickers (defaults to `now`).
- **Section "PRÉSENTS"**: 2-column grid of selectable chips (44px target) showing player avatar initials and name. Pre-selects active players. *"Tous"* / *"Aucun"* text actions above the grid, and a live *"N sélectionné(s)"* count.
- **Section "OPTIONS"**:
  - *"Séance classée"* (Toggle switch, default: ON).
  - *"Autoriser des effectifs inégaux"* (Toggle switch, default: OFF).
- **Actions** — two, because the choice of *how* teams are decided belongs to the organizer and cannot be inferred:
  - Primary, full-width 56px `#FFC94F`: *"Créer et tirer au sort"* — the wide path.
  - Secondary, full-width 52px ghost (transparent, `--hairline-2` border): *"Composer à la main"*.
  - Both disabled below `MIN_ATTENDEES`. Only the pressed button shows a spinner.
- Below `MIN_ATTENDEES` and above zero, an inline note: *"Il faut au moins 6 joueurs présents pour créer une séance."*

### 4.2 Composition Draft View (`/sessions/[id]/composition`)
- **Header**: Empty dashed `ScoreBar` (40px) with `"— —"` score placeholder, date, format badge, `"Brouillon"` badge.
- **2-Column Layout**:
  - Left column: **ÉQUIPE A** (Solid `#FFC94F` team pill).
  - Right column: **ÉQUIPE B** (Hatched `#556860` team pill).
  - Separated by a thin vertical hairline (`pitch-700`).
- **Player Chips**: Avatar initials, name, and move button / drag handle.
- **Section "À PLACER"** (above the two columns, only while `unassigned.length > 0`): flat filet-separated list — 30px rounded-square initials avatar, name, then two 44px buttons `A` (solid yellow) and `B` (45° hatch). It reads as a queue to empty, not as a third team.
- **Bottom Actions**:
  - Full-width ghost button: `"Tirer au sort"`.
  - Sticky bottom action bar: Primary button `"Saisir les statistiques"`, **disabled while any attendee is unplaced**, with the hint *"Placez les N joueurs restants pour continuer."*
- The draw button and the split-mode badge carry a 🎲, matching `DrawConfirmModal`.

### 4.3 Overwrite Confirmation Bottom Sheet
- **Title**: *"Remplacer la composition actuelle ?"*
- **Description**: *"Le tirage écrase les équipes que vous avez ajustées à la main. Les statistiques déjà saisies sont conservées."*
- **Buttons**: `"Annuler"` (ghost) above `"Tirer au sort"` (destructive red `#F0503C`).

---

## 5. Technical Implementation Plan

### 5.1 Files & Modules
```
app/
  lib/
    splitter/
      TeamSplitter.ts      # Interface definition
      RandomSplitter.ts    # Fisher-Yates shuffle implementation
  pages/
    sessions/
      new.vue              # Creation form
      [id]/
        index.vue          # Session detail / draft wrapper
  components/
    session/
      TeamColumn.vue       # Single team roster column
      DrawConfirmModal.vue # Re-draw confirmation modal
```

### 5.2 Random Splitter Implementation (`RandomSplitter.ts`)
```ts
export class RandomSplitter implements TeamSplitter {
  split(players: { id: string; name: string }[]): { teamA: string[]; teamB: string[] } {
    const shuffled = [...players].sort(() => Math.random() - 0.5)
    const mid = Math.ceil(shuffled.length / 2)
    return {
      teamA: shuffled.slice(0, mid).map(p => p.id),
      teamB: shuffled.slice(mid).map(p => p.id)
    }
  }
}
```

---

## 6. Edge Cases & Error Handling

- **Uneven Attendance**: If 9 players are selected and `allow_uneven_teams` is false, `RandomSplitter` splits into 5 vs 4 (size difference = 1, valid). If size difference > 1, show validation warning during split.
- **Removing a Present Player**: If a player is removed from the session draft, delete their row from `participations`.
- **Below the minimum**: 5 or fewer attendees blocks creation. The two buttons are disabled and `createSession` throws even if called directly, so the rule cannot be bypassed by a stale UI state.
- **Draw over a partial hand composition**: allowed, and it redraws everyone — those already placed and those still queued. Confirmation is required as soon as one team is non-empty.
- **Unassigned player in a closed session**: unreachable through the UI, but `v_closed_participations` scores `team IS NULL` as `NULL` rather than 0. Without that explicit branch, `s.result = p.team` yields `NULL` (not false) and would silently fall through to the ELSE, recording a loss for a player who was never on a team.

---

## 7. Verification & Testing Plan

### Automated Tests
- Test `RandomSplitter` distributes odd and even numbers of players correctly.
- Test switching a player from Team A to Team B updates `split_mode` to `'RANDOM_ADJUSTED'`.
- Test the v2 -> v3 migration preserves every participation and every derived stat (see §7 of the migration notes in `docs/003_nullable_team.sql`).

### Manual Verification
- Create session -> select 10 players -> *"Créer et tirer au sort"* -> verify a 5v5 lands on the composition screen with `split_mode = 'RANDOM'` -> swap 1 player manually -> verify the format badge and `'RANDOM_ADJUSTED'`.
- Create session -> select 8 players -> *"Composer à la main"* -> verify all 8 sit in *"À placer"*, the format badge is hidden and *"Saisir les statistiques"* is disabled -> place all 8 -> verify the button enables and `split_mode` stays `'MANUAL'`.
- Select 5 players -> verify both buttons are disabled and the note shows.
- Enter stats on a drawn session, then redraw -> verify the goals entered are still there.
