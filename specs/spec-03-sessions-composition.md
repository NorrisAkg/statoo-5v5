# SPEC-03 — Sessions & Team Composition

- **ID**: SPEC-03
- **Feature**: Session Creation, Attendee Selection, Team Splitting Algorithms & Composition Editing
- **Target Lot**: Lot 2 (L2)
- **Status**: 📝 DRAFT
- **Primary Source**: `docs/statoo-cahier-des-charges.md` §6.2, `docs/statoo-design-system.md` §4.1, §4.6

---

## 1. Context & Goals

Setting up a match session starts by picking the date, selecting attendees, defining session parameters (ranked vs friendly, allow uneven teams), drawing teams randomly, and manually adjusting assignments if needed.

The goal of SPEC-03 is to implement:
- Session creation workflow (sets status to `DRAFT`).
- Active player multi-selection grid for attendees.
- Random team drawer (`RandomSplitter` implementation using Fisher-Yates shuffle).
- Interactive 2-column composition screen (Team A vs Team B).
- Drag-and-drop / click-to-move player assignment between Team A and Team B.
- Overwrite confirmation modal when re-triggering random split on an existing draft.

---

## 2. Domain Rules & Invariants

1. **Initial Status**: New sessions are always created with `status = 'DRAFT'`.
2. **Split Mode**:
   - Initial manual composition or manual drag-and-drop edits set `split_mode = 'MANUAL'`.
   - Executing the random draw sets `split_mode = 'RANDOM'`.
   - If a manual adjustment occurs *after* a random draw, `split_mode` switches to `'RANDOM_ADJUSTED'`.
3. **Format Label**: The session format (e.g. `"5v5"`, `"6v5"`, `"4v4"`) is **never stored**; it is derived from `COUNT(team = 'A')` vs `COUNT(team = 'B')` in SQL view `v_session_summary`.
4. **Equal Hierarchy**: Team A and Team B have identical visual weight. Team A uses solid `#FFC94F` bib yellow; Team B uses 45° hatched pattern over `#1B2721` with `#556860` outline.
5. **Re-drawing Teams**: The *"Tirer au sort"* button is ALWAYS accessible during `DRAFT`. Triggering it requires explicit user confirmation via a bottom sheet modal (*"Remplacer la composition actuelle ?"*).

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
  team: Team
}

export interface TeamSplitter {
  split(players: { id: string; name: string }[]): { teamA: string[]; teamB: string[] }
}
```

---

## 4. UI / UX Specifications

### 4.1 New Session Screen (`/sessions/new`)
- **Section "QUAND"**: Date & Time pickers (defaults to `now`).
- **Section "PRÉSENTS"**: 2-column grid of selectable chips (44px target) showing player avatar initials and name. Pre-selects active players.
- **Section "OPTIONS"**:
  - *"Séance classée"* (Toggle switch, default: ON).
  - *"Autoriser des effectifs inégaux"* (Toggle switch, default: OFF).
- **Action**: Full-width primary button `"Créer la séance"` (56px, `#FFC94F`).

### 4.2 Composition Draft View (`/sessions/[id]/composition`)
- **Header**: Empty dashed `ScoreBar` (40px) with `"— —"` score placeholder, date, format badge, `"Brouillon"` badge.
- **2-Column Layout**:
  - Left column: **ÉQUIPE A** (Solid `#FFC94F` team pill).
  - Right column: **ÉQUIPE B** (Hatched `#556860` team pill).
  - Separated by a thin vertical hairline (`pitch-700`).
- **Player Chips**: Avatar initials, name, and move button / drag handle.
- **Bottom Actions**:
  - Full-width ghost button: `"Tirer au sort"`.
  - Sticky bottom action bar: Primary button `"Saisir les statistiques"`.

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

---

## 7. Verification & Testing Plan

### Automated Tests
- Test `RandomSplitter` distributes odd and even numbers of players correctly.
- Test switching a player from Team A to Team B updates `split_mode` to `'RANDOM_ADJUSTED'`.

### Manual Verification
- Create session -> select 10 players -> click "Tirer au sort" -> verify 5v5 distribution -> swap 1 player manually -> verify format badge and split mode updates.
