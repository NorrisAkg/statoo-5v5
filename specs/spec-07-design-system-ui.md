# SPEC-07 — Design System & UI Components

- **ID**: SPEC-07
- **Feature**: Tokens Implementation, Nuxt UI Integration, Custom UI Components & Layout Systems
- **Target Lot**: Cross-cutting (L1 through L6)
- **Status**: 📝 DRAFT
- **Primary Source**: `docs/statoo-design-system.md`, `docs/statoo-prompt-claude-design.md`, `docs/statoo-prompt-stitch.md`

---

## 1. Context & Goals

Statoo uses a distinct dark design theme ("Terrain de nuit") inspired by night football fields under floodlights. Dark is the base and the reference; a **light theme follows the OS setting** (`prefers-color-scheme`) as a pure value swap — same grid, same sizes, same components. There is **no in-app theme toggle**, so no theme preference is stored.

The goal of SPEC-07 is to implement:
- CSS token system in Tailwind CSS v4 (`assets/css/main.css`), split into literal palettes and **role tokens**.
- Nuxt UI theme configuration (`app.config.ts`).
- Font loading via `@nuxt/fonts` (**Archivo Expanded** for display/numbers, **Instrument Sans** for UI text).
- 4 custom core UI components:
  1. `ScoreBar` (Signature proportional score bar).
  2. `StatStepper` (Touch-optimized +/- counter).
  3. `PlayerRow` (Standard roster list item).
  4. `StandingsTable` (Dense, tabular-nums standings grid).
- Bottom navigation tab bar and modal sheets layout.

---

## 2. Domain Tokens & Invariants

### 2.1 CSS Theme Tokens (`app/assets/css/main.css`)
```css
@import "tailwindcss";
@import "@nuxt/ui";

@theme {
  /* Pitch - Neutral dark green-black */
  --color-pitch-50:  #EAF0EC;
  --color-pitch-100: #D3DED8;
  --color-pitch-200: #B0C0B8;
  --color-pitch-300: #8CA096;
  --color-pitch-400: #6E837A;
  --color-pitch-500: #556860;
  --color-pitch-600: #3F4E48;
  --color-pitch-700: #2A3831;
  --color-pitch-800: #1B2721;
  --color-pitch-900: #121B17;
  --color-pitch-950: #0B120F;

  /* Bib - High-visibility yellow (Accent / Team A) */
  --color-bib-50:  #FFF9EB;
  --color-bib-100: #FFEFC7;
  --color-bib-200: #FFE29E;
  --color-bib-300: #FFD470;
  --color-bib-400: #FFC94F;
  --color-bib-500: #F5B32E;
  --color-bib-600: #D9971C;
  --color-bib-700: #AE7614;

  /* Flag - Alert / Red Card / Destructive */
  --color-flag-400: #FF7361;
  --color-flag-500: #F0503C;
  --color-flag-700: #A22C1E;
  --color-flag-950: #260907;

  /* Typography */
  --font-display: 'Archivo Expanded', system-ui, sans-serif;
  --font-sans: 'Instrument Sans', system-ui, sans-serif;
}
```

### 2.2 Role Tokens & Light Substitutions

The palettes above stay literal. Components MUST reference **role tokens** (`var(--surface)`, `bg-surface`, `text-muted`…), never a raw hex or a raw `pitch-*` / `bib-*` class — that is what makes the light theme a value swap. Substitution table transcribed from `docs/design-mockup-template.html` § *Substitutions*:

| Role | Token | Dark | Light |
|---|---|---|---|
| Page background | `--ground` | `#0B120F` | `#F2F5F3` |
| Surface (cards) | `--surface` | `#121B17` | `#FFFFFF` |
| Surface 2 (inputs, sheets) | `--surface-2` | `#1B2721` | `#E8EDEA` |
| Hairline | `--hairline` | `#2A3831` | `#D3DCD7` |
| Strong border / disabled | `--hairline-2` | `#3F4E48` | `#AFBCB5` |
| Primary text | `--text` | `#EAF0EC` | `#16211C` |
| Label text | `--text-strong` | `#D3DED8` | `#33443C` |
| Secondary text | `--text-muted` | `#8CA096` | `#5B6E66` |
| Faint text / placeholder | `--text-faint` | `#556860` | `#8FA098` |
| **Team A fill** | `--team-a` | `#FFC94F` | `#FFC94F` *(unchanged)* |
| Team B hatch line | `--hatch-line` | `#8CA096` | `#5B6E66` |
| Accent as text/number/icon | `--accent-text` | `#FFC94F` | `#8A5E00` |
| Alert as text | `--danger-text` | `#FF7361` | `#B02E1D` |
| Destructive fill | `--danger-solid` | `#F0503C` | `#D2402C` |

Two invariants carried over from the template:

1. **The Team A yellow never moves.** `#FFC94F` reads identically in both themes so the A/B pairing stays stable. It is a fill only.
2. **The yellow is never text on light.** `#FFC94F` on `#F2F5F3` is 1.6:1. Every text, number, icon or link use of the accent switches to `#8A5E00` (5.7:1) via `--accent-text`. Same reasoning for `--danger-text`.

Team B hatching keeps the same density in both themes (`repeating-linear-gradient(45deg, …)` at 2px/8px); only the line color changes.

### 2.3 Nuxt UI Config (`app.config.ts`)
```ts
export default defineAppConfig({
  ui: {
    colors: {
      primary: 'bib',
      neutral: 'pitch',
      error: 'flag',
      warning: 'bib',
    },
  },
})
```

---

## 3. Custom UI Components Specification

### 3.1 `ScoreBar.vue`
- Props: `scoreA: number`, `scoreB: number`, `status: 'DRAFT' | 'CLOSED'`, `size: 'xs' | 'sm' | 'md' | 'lg'`.
- Left side: Solid `#FFC94F` fill.
- Right side: 45° diagonal hatching over `#1B2721` with `#556860` outline.
- Widths proportional to `scoreA / (scoreA + scoreB)`, minimum 4px per team.
- Draft state: Empty dashed border.

### 3.2 `StatStepper.vue`
- Props: `modelValue: number`, `min?: number`, `max?: number`, `label?: string`.
- Layout: `[-]` button (52px target), value display (44px, Archivo Expanded, `tabular-nums`), `[+]` button (52px target).
- `[-]` button dimmed at 0, never hidden or shifted.

### 3.3 `PlayerRow.vue`
- Props: `name: string`, `nickname?: string`, `avatarUrl?: string`, `isActive?: boolean`, `stats?: { played: number; points: number; goals: number }`.
- Avatar: 36px circular initials on `pitch-800`.
- Archived state: 50% avatar opacity, dimmed text, *"Archivé"* eyebrow badge.

### 3.4 `StandingsTable.vue`
- Props: `players: PlayerStats[]`, `activeTab: 'points' | 'perMatch'`, `ineligiblePlayers?: PlayerStats[]`.
- Displays compact tabular grid with `tabular-nums` formatting. Fits 390px mobile viewport without horizontal scrolling.

---

## 4. Layout & Navigation Specifications

- **Bottom Navigation Bar**: Height 64px, 5 items (Accueil, Joueurs, Séances, Classement, Stats).
- **Modal Sheets**: Bottom sheet with 14px top rounded corners, drag handle, backdrop blur disabled for performance. Primary action button placed at the very bottom. Sheets are hand-rolled (`Teleport` + `Transition` + `--scrim`), **not** `UModal`: the Nuxt UI shell paints its backdrop and panel from the literal palettes mapped in `app.config.ts`, which do not follow the light theme.

---

## 5. Technical Implementation Plan

### 5.1 Directory Layout
```
app/
  assets/css/
    main.css               # Tailwind v4 theme definitions
  components/
    ui/
      ScoreBar.vue
      StatStepper.vue
      PlayerRow.vue
      StandingsTable.vue
  layouts/
    default.vue            # Mobile frame & bottom tab bar
```

---

## 6. Verification & Testing Plan

### Visual & Accessibility Verification
- Contrast check, dark: Text `#EAF0EC` on `#0B120F` >= 7:1.
- Contrast check, light: Text `#16211C` on `#F2F5F3` >= 7:1; `--accent-text` and `--danger-text` >= 4.5:1 on both `--ground` and `--surface`.
- Theme sweep: toggle the OS appearance and walk the 25 screens. No raw hex may survive in a component — grep for `#` in `app/components/` and `app/pages/` should return nothing but comments.
- Touch target check: All steppers and main buttons >= 44px / 52px.
- Hatching check: Verify Team B hatching renders cleanly across browser and mobile WebView, in both themes.
