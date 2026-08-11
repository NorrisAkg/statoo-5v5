# Statoo Agent Rules

Refer to [.agents/rules.md](file:///c:/Users/ky-solutions/projects/persos/statoo%205v5/.agents/rules.md) for full detailed guidelines.

## Quick Summary of Rules:
1. **French UI / English Code**: User interface in French, code/types/comments/commits in English.
2. **SQLite is Source of Truth**: All stats/standings are calculated via SQL views (`docs/002_views.sql`). No stored aggregations in JavaScript or database tables.
3. **Design Tokens & System**: Single dark mode ("Terrain de nuit"). Accent `#FFC94F` (Bib Yellow), Team B hatched 45°. Archivo Expanded for numbers (`tabular-nums`), Instrument Sans for body text. Touch targets ≥ 44px (52px for steppers).
4. **No Gamification**: Single organizer app. No player ratings, MVP votes, streaks, or badges.
5. **Session Workflow**: DRAFT -> CLOSED. Validate score, assignments, equal sizes (unless `allow_uneven_teams`). Automated JSON backup to Supabase Storage upon closing.
