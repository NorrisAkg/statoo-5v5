# SPEC-08 — First Launch, Onboarding & Settings

- **ID**: SPEC-08
- **Feature**: Splash screen, 3-step onboarding, `settings` table and the preferences it feeds
- **Target Lot**: Lot 1 (L1) — the `settings` table blocks L4 and L5
- **Status**: 📝 DRAFT
- **Primary Source**: `docs/design-mockup-template.html` screens 16, 22, 23, 24, 25

---

## 1. Context & Goals

Screens 22–25 of the design template introduce a first-launch flow that no earlier spec covers. It is not decorative: it captures four values that other features already need.

- The **group name** names the backup files and is the confirmation phrase of the destructive restore (SPEC-06, screen 17).
- The **eligibility threshold** gates the Pts/match standings (SPEC-05, screens 12–13), which until now hardcoded 50%.
- The **default format** and **default ranked flag** pre-fill every new session (SPEC-03, screen 6).

The goal of SPEC-08 is to implement:
- The `settings` key/value table and its typed accessor.
- The splash screen (22) and the 3-step onboarding (23, 24, 25).
- The data blocks of the Réglages screen (16) that read from it.

---

## 2. Domain Rules & Invariants

1. **Key/value storage**: preferences live in `settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)`. A new preference is a new row, never a new column — this keeps the backup JSON shape stable.
2. **Always seeded**: migration 001 inserts every key with its default (`INSERT OR IGNORE`), so a read never returns `undefined` and the app is fully usable if onboarding is skipped.
3. **Onboarding is skippable, not repeatable**: `onboarding_completed` flips to `'1'` on "Terminer" *or* "Plus tard", and the flow never shows again. Everything it sets stays editable in Réglages.
4. **Defaults are pre-fills, not constraints**: `default_format` and `default_is_ranked` only seed the "Nouvelle séance" form. They never constrain a session already created, and never take part in any calculation — the `"5v5"` label of a session remains derived from the actual team sizes by `v_session_summary`.
5. **The threshold is read from SQL, never from JS**: `v_eligibility_threshold` is the only place the setting is interpreted. See SPEC-05 §2.3.
6. **Tone**: onboarding may be warm and playful — an illustration, an emoji, a small completion flourish are all fine. What it must not do is invent data: no score, no unlockable reward, nothing stored beyond the `settings` rows it is there to write.
7. **Nothing leaves the device**: the group name is local. It appears in backup filenames (SPEC-06) but is not an account or an identifier.

---

## 3. Data Specification & Types

### 3.1 `settings` keys

| Key | Values | Default | Consumed by |
|---|---|---|---|
| `group_name` | free text | `''` | SPEC-06 (backup name, restore confirmation), screen 16 |
| `default_format` | `'4v4'` \| `'5v5'` \| `'6v6'` | `'5v5'` | SPEC-03 (new session form) |
| `default_is_ranked` | `'0'` \| `'1'` | `'1'` | SPEC-03 |
| `eligibility_mode` | `'PERCENT'` \| `'SESSIONS'` | `'PERCENT'` | SPEC-05 |
| `eligibility_value` | integer as text | `'50'` | SPEC-05 |
| `onboarding_completed` | `'0'` \| `'1'` | `'0'` | this spec |

Schema version moves to **2**. `meta.schema_version` is bumped in the same pass that creates the table.

### 3.2 Types (`app/types/index.ts`)

`Settings` exposes the typed, parsed shape (booleans as `boolean`, `eligibility_value` as `number`); `EligibilityThreshold` mirrors `v_eligibility_threshold`.

### 3.3 View

`v_eligibility_threshold` — see `docs/002_views.sql`. Returns `required_raw` (exact) and `required_sessions` (rounded **up**, the value the UI shows).

---

## 4. UI / UX Specifications

### 4.1 Splash (screen 22)
- Full-bleed `--ground`. Wordmark **Statoo** in Archivo Expanded, subtitle *"Journal personnel · hors ligne"* in `--text-muted`.
- Shown while `initDb()` resolves. Replaces the current spinner in `app.vue`.
- If init fails, the existing error card takes over — the splash never hangs silently.

### 4.2 Onboarding 1 · Le groupe (screen 23)
- Title *"Le groupe"*, body *"Le nom sert à retrouver vos sauvegardes. Il reste sur l'appareil."*
- Field *"Nom du groupe"*, placeholder *"Les Mardis"*.
- Primary *"Continuer"*, disabled while the field is empty.

### 4.3 Onboarding 2 · Les joueurs (screen 24)
- Title *"Les joueurs"*, body *"Un prénom suffit. Vous pourrez en ajouter à tout moment."*
- Field *"Prénom"* + `+` button; each add appends to a list headed *"Ajoutés · N"* with 28px initials avatars.
- Footnote *"Il faut au moins six joueurs pour créer une séance."* — informative here, never blocking. The blocking check lives in SPEC-03 §2 rule 2 (`MIN_ATTENDEES = 6`), and applies to attendees of a session, not to the roster being built here.
- Secondary *"Plus tard"* / primary *"Continuer"*. Players created here are ordinary `players` rows.

### 4.4 Onboarding 3 · Le format (screen 25)
- Title *"Le format"*, body *"Ces valeurs pré-remplissent chaque nouvelle séance. Elles restent modifiables séance par séance."*
- *"Effectif par défaut"*: segmented `4v4` / `5v5` / `6v6`.
- *"Classement"*: toggle *"Séance classée par défaut"*, hint *"Les amicales se décochent à la création"*.
- *"Séances requises"* — hint *"Pour figurer au classement"* — stepper `− N +`. Writing a value here sets `eligibility_mode = 'SESSIONS'`; leaving it untouched keeps `PERCENT` / `50`. The stepper is initialised with the current `required_sessions` so the two modes read continuously.
- Primary *"Terminer"* → writes settings, sets `onboarding_completed = '1'`, `saveWebStore()`, redirects to `/`.

### 4.5 Réglages (screen 16)
- **Données** group displays `Version du schéma` (from `meta`), `Séances` and `Joueurs` counts (from `v_group_totals`) — currently hardcoded.
- The onboarding values are editable here. Same copy, same controls.

---

## 5. Technical Implementation Plan

### 5.1 Composable API (`useSettings.ts`)
```ts
export function useSettings() {
  const settings = ref<Settings | null>(null)
  const requiredSessions = ref<number>(0)

  async function loadSettings(): Promise<void>
  async function updateSetting<K extends keyof Settings>(key: K, value: Settings[K]): Promise<void>
  async function completeOnboarding(payload: Partial<Settings>): Promise<void>
}
```
Module-level reactive state, like the other composables. Every write goes through `queries.ts` and is followed by `saveWebStore()`.

### 5.2 Routing
- `app/pages/onboarding/index.vue` — the 3 steps as local state, not 3 routes, so "Précédent" keeps what was typed.
- A route middleware redirects to `/onboarding` while `onboarding_completed = '0'`, and away from it once set.

---

## 6. Edge Cases & Error Handling

- **Empty group name**: legal after "Plus tard". SPEC-06 must then fall back to a date-only backup filename and disable the type-to-confirm restore, which cannot work without a phrase.
- **Threshold set to 0**: everyone is eligible; the "SOUS LE SEUIL" block disappears. Legal.
- **Restore overwrites settings**: a backup carries the `settings` table, so restoring replaces the group name too. Consistent with the destructive-restore contract (SPEC-06) — state it in the confirmation copy.
- **Onboarding interrupted** (app killed mid-flow): `onboarding_completed` stays `'0'`, the flow restarts, and any players already created are still there.

---

## 7. Verification & Testing Plan

### Manual Verification
- Fresh install → splash → 3 steps → home. Re-launch: onboarding does not reappear.
- Set `Séances requises` to 12 with 6 ranked sessions played → Pts/match table empty, all players listed under "SOUS LE SEUIL" with correct missing counts.
- Leave the threshold untouched → mode stays `PERCENT`, `required_sessions` tracks 50% of ranked sessions and rounds up.
- Change `default_format` → the next "Nouvelle séance" pre-selects it; an existing session is unaffected.
