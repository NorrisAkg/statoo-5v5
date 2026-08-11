# SPEC-02 — Players Management

- **ID**: SPEC-02
- **Feature**: Player Creation, Edition, Archiving, Hard Deletion Constraints, and Player Profile
- **Target Lot**: Lot 1 (L1)
- **Status**: 📝 DRAFT
- **Primary Source**: `docs/statoo-cahier-des-charges.md` §6.1, `docs/statoo-design-system.md` §4.3

---

## 1. Context & Goals

The administrator needs to manage the roster of players in the group. Players can be active or archived.

The goal of SPEC-02 is to implement:
- Player list view (Active players sorted by name, archived section collapsed).
- Player creation form (Name, optional nickname, optional avatar URL).
- Player editing modal/screen.
- Archiving action (`is_active = 0`) to hide inactive players from new match selections without altering past history.
- Hard delete option **only available** when the player has zero participations.
- Player profile view with synthesis stats, raw stats, and match history.

---

## 2. Domain Rules & Invariants

1. **Required Fields**: `name` is required. `nickname` and `avatar_url` are optional.
2. **Duplicate Name Handling**: A warning message appears if another player has the exact same name, but creation is NOT blocked (*homonyms exist*).
3. **Archiving vs Deletion**:
   - Archiving sets `is_active = 0`. Archived players are hidden from attendee selection in new sessions, but remain visible in standings and historical statistics.
   - Hard deletion (`DELETE FROM players WHERE id = ?`) is strictly forbidden if the player has any rows in `participations` (`ON DELETE RESTRICT`). The delete button MUST be hidden (not disabled) if `appearances > 0`.
4. **Ordering**: Active players are sorted alphabetically by `name`. Archived players are listed in a collapsed accordion section at the bottom.

---

## 3. Data Specification & Types

### 3.1 Interfaces
```ts
export interface Player {
  id: string
  name: string
  nickname?: string | null
  avatar_url?: string | null
  is_active: boolean // 1 or 0 in DB
  created_at: string
  updated_at: string
}

export interface PlayerStats {
  player_id: string
  name: string
  nickname?: string | null
  is_active: number
  played: number
  wins: number
  draws: number
  losses: number
  points: number
  points_per_match: number
  win_rate: number
  appearances: number
  goals: number
  assists: number
  yellow_cards: number
  red_cards: number
  last_played_at?: string | null
  is_eligible: number
}
```

---

## 4. UI / UX Specifications

### 4.1 Player List View (`/players`)
- **Header**: Title "Joueurs", action button `+` (New player).
- **Search Input**: Search by `name` or `nickname` (44px height).
- **Active Section**: List of `PlayerRow` components (Avatar with initials or image, Name, Nickname, summary columns: J / PTS / BUTS).
- **Archived Section**: Collapsed section titled *"Archivés (N)"* with chevron toggle. Archived rows rendered with dimmed text (`pitch-300`), 50% opacity avatar, and an *"Archivé"* badge.

### 4.2 New / Edit Player Modal (`/players/new` or bottom sheet)
- **Fields**:
  - `Nom` (Required, text input 52px).
  - `Surnom` (Optional, text input 52px).
  - `Photo` (Avatar preview + upload/choose trigger).
- **Duplicate Name Warning**: Non-blocking red text under input: *"Un joueur porte déjà ce nom. Vous pouvez continuer."*
- **Action Buttons**:
  - `Enregistrer` (Primary button, 56px yellow `#FFC94F` at the bottom).
  - `Annuler` (Ghost button above primary button).

### 4.3 Player Profile (`/players/[id]`)
- **Header**: Back arrow, avatar (56px), name, nickname, edit action.
- **Synthesis Card**: `SÉANCES`, `PTS/MATCH`, `% VICTOIRES` in large 32px numbers, with record line (`11 V · 3 N · 4 D`).
- **Raw Stats Block**: Total goals, assists, yellow cards, red cards, total appearances.
- **Match History List**: Anti-chronological list of played sessions with mini `ScoreBar`, date, match score, and individual contribution (e.g. *"2 buts · 1 passe"*).

---

## 5. Technical Implementation Plan

### 5.1 Components & Pages
- `app/pages/players/index.vue`: Main list screen.
- `app/pages/players/[id].vue`: Player detail profile.
- `app/components/player/PlayerFormModal.vue`: Modal bottom sheet for creation/edition.
- `app/components/ui/PlayerRow.vue`: Reusable row component.
- `app/composables/usePlayers.ts`: Player CRUD operations.

### 5.2 Composable API (`usePlayers.ts`)
```ts
export function usePlayers() {
  const activePlayers = ref<PlayerStats[]>([])
  const archivedPlayers = ref<PlayerStats[]>([])
  
  async function fetchPlayers(): Promise<void>
  async function createPlayer(data: { name: string; nickname?: string; avatar_url?: string }): Promise<string>
  async function updatePlayer(id: string, data: Partial<Player>): Promise<void>
  async function toggleArchivePlayer(id: string, archive: boolean): Promise<void>
  async function deletePlayer(id: string): Promise<boolean>
  async function getPlayerProfile(id: string): Promise<{ stats: PlayerStats; history: any[] }>
}
```

---

## 6. Edge Cases & Error Handling

- **Attempting to delete a player with matches**: Database throws `FOREIGN KEY constraint failed`. Catch error gracefully and display toast: *"Impossible de supprimer un joueur ayant déjà joué des séances."*
- **Empty Roster**: Display empty state invitation screen: *"Ajoutez les joueurs du groupe pour commencer."* with a `"Nouveau joueur"` primary button.

---

## 7. Verification & Testing Plan

### Automated Tests
- Test player creation, edition, and soft-archiving.
- Verify search filter matches both `name` and `nickname`.
- Verify hard delete works for player with 0 matches and fails for player with 1+ matches.

### Manual Verification
- Open Player screen -> create 3 players -> archive 1 player -> check list layout and archived accordion behavior.
