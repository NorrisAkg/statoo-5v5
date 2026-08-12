---
name: statoo-design-system
description: Design system specification, Tailwind CSS v4 tokens, Nuxt UI configuration, and UI component standards for Statoo 5v5.
---

# Statoo — Design System Skill

## Overview
This skill details the "Terrain de nuit" design system for Statoo, an Android mobile app built with Nuxt 4, Vue 3, Nuxt UI, and Tailwind CSS v4.

## Color Tokens & Design Theme

### 1. Palette
- **`pitch`** (Neutral - Night Pitch):
  - `50`: `#EAF0EC`, `100`: `#D3DED8`, `200`: `#B0C0B8`, `300`: `#8CA096`, `400`: `#6E837A`
  - `500`: `#556860`, `600`: `#3F4E48`, `700`: `#2A3831`, `800`: `#1B2721`, `900`: `#121B17`, `950`: `#0B120F`
- **`bib`** (Accent & Team A - High-Visibility Yellow):
  - `50`: `#FFF9EB`, `100`: `#FFEFC7`, `200`: `#FFE29E`, `300`: `#FFD470`, `400`: `#FFC94F`
  - `500`: `#F5B32E`, `600`: `#D9971C`, `700`: `#AE7614`, `800`: `#7C5310`, `900`: `#4E340A`, `950`: `#2B1D05`
- **`flag`** (Alert & Destructive / Red Card):
  - `50`: `#FFF1EE`, `100`: `#FFDCD5`, `200`: `#FFBCAF`, `300`: `#FF9585`, `400`: `#FF7361`
  - `500`: `#F0503C`, `600`: `#CB3A28`, `700`: `#A22C1E`, `800`: `#731F15`, `900`: `#47130D`, `950`: `#260907`

### 2. Semantic Roles
- Background: `pitch-950` (`#0B120F`)
- Cards & Lists: `pitch-900` (`#121B17`)
- Raised Surfaces / Inputs / Steppers: `pitch-800` (`#1B2721`)
- Borders / Hairlines: `pitch-700` (`#2A3831`)
- Primary Text: `pitch-50` (`#EAF0EC`)
- Muted Text: `pitch-300` (`#8CA096`)
- Primary Action / Team A / Rank 1: `bib-400` (`#FFC94F`)
- Alerts / Red Card / Destructive: `flag-400` / `flag-500`

### 3. Team Visual Representation
- **Team A**: Solid `#FFC94F` fill.
- **Team B**: 1px `#556860` outline with 45° diagonal hatching over `#1B2721`.
- **Equal Hierarchy**: Never use home/away layout or a second solid color for Team B.

## Key UI Components

1. **`ScoreBar`** (Signature Component):
   - Horizontal bar split proportionally to score.
   - Sizes: `xs` (2px), `sm` (6px), `lg` (40px).
   - Draft state: dashed outline with empty background.
   - Minimum 4px per side so a team with 0 goals remains visible.

2. **`StatStepper`** (Core Input Component):
   - `[-]` button (52px), value container (44px wide, Archivo Expanded, tabular-nums), `[+]` button (52px).
   - Dimmed `[-]` button when value is 0 (never hidden to maintain layout alignment).
   - No virtual keyboard popups during match stat entry!

3. **`PlayerRow`**:
   - Avatar (36px circular initials on `#1B2721`), Name (15px) + Nickname (13px muted), right-aligned stats (J / PTS / BUTS).
   - Archived players displayed in `text-muted` with 50% opacity avatar and "Archivé" badge.

4. **`StandingsTable`**:
   - Columns: Rank, Player, **J** (always visible), V, N, D, PTS, PTS/M.
   - Ranks 1-3 carry a medal (🥇🥈🥉) in place of the rank number; rank 1 also uses `#FFC94F`. The medal replaces the digit rather than sitting beside it, so the 18px rank column does not widen.
   - Right-aligned numbers in `Archivo Expanded` with `tabular-nums`.
   - Strict horizontal layout (no horizontal scrollbar).

5. **Navigation Bar**:
   - Fixed bottom tab bar (64px height) with 5 tabs: **Accueil**, **Joueurs**, **Séances**, **Classement**, **Stats**.
