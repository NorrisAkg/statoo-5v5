# Statoo

Application mobile Flutter (Android + iOS, portrait) de suivi de matchs de foot à 5 entre amis : séances, compositions, scores, stats individuelles, classement. Hors-ligne, SQLite local, multi-groupes. UI entièrement en français.

La branche `refonte` porte la réécriture Flutter ; l'historique antérieur (Nuxt 3 / Capacitor) est obsolète, ne pas s'en inspirer.

## Sources de vérité

- **Fonctionnel** : `docs/Statoo_Cahier_des_Charges_v1.1.pdf` (CDC) prime — règles métier, données, validations, calculs.
- **Design** : `statoo-captures/*` prime sur le CDC — couleurs, disposition, libellés. Signaler toute divergence.
- `specs/prompt-agent-flutter-statoo.md` : brief initial (design system chiffré, écrans, données de démo). `docs/analysis.md` : analyse initiale, en partie dépassée (Supabase abandonné au profit d'un backup fichier local ; un thème clair existe désormais).
- Conflit insoluble : ne pas deviner, poser un `// TODO(cdc):` et choisir l'option la plus simple et réversible.
- `GEMINI.md` et `.agents/` servent à un autre agent ; ce fichier-ci fait foi pour Claude.

## Commandes

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # après toute modif @riverpod / @freezed / @JsonSerializable
dart analyze <fichiers>          # ciblé, ~4 s — à privilégier
flutter analyze                  # projet entier, lent
flutter test                     # ~30 s, 19 tests
flutter test test/features/<feature>/
flutter run
```

État de base connu (2026-09-25) : `dart analyze lib test` remonte **70 infos préexistantes** ; 59 fichiers sur 75 ne sont pas au format `dart format`. Ne compter que les infos **introduites** par un changement, et **ne pas reformater en masse** des fichiers non touchés (diffs illisibles).

## Architecture

Feature-first inspirée Clean Architecture :

```
lib/core/        data/ (AppDatabase), router/, theme/, widgets/, domain/
lib/features/<f>/domain/        entités freezed, calculs purs — aucune dépendance Flutter ni Riverpod
lib/features/<f>/data/          interface abstraite + implémentation Sqlite<Nom>Repository
lib/features/<f>/application/   providers Riverpod, contrôleurs (ex. SessionsController)
lib/features/<f>/presentation/  écrans *_screen.dart, *_bottom_sheet.dart
```

Features : home, onboarding, team, players, sessions, ranking, stats, settings.

- **Router** (`core/router/app_router.dart`) : `go_router`, `StatefulShellRoute.indexedStack` pour les 5 onglets (`/`, `/joueurs`, `/seances`, `/classement`, `/stats`). Écrans poussés hors onglets via `parentNavigatorKey: _rootNavigatorKey`. Routes en français. Redirections : splash → onboarding → `/creer-equipe` → app.
- **Providers** : style majoritaire = providers manuels typés explicitement (`final FutureProvider<X> fooProvider = ...`), `Notifier`/`AsyncNotifier` pour l'état mutable. `@riverpod` n'est utilisé que dans le router et le thème. Suivre le style du fichier voisin.
- **Mutations** : passent par un contrôleur (`SessionsController`) qui invalide explicitement tous les providers dérivés (classements, stats, totaux). Toute nouvelle écriture doit invalider ce qui en dépend.
- **Bootstrap** (`main.dart`) : préférences et présence d'équipe lues avant `runApp`, injectées par `overrideWith`.
- **Imports relatifs** dans `lib/` (`prefer_relative_imports`), `package:statoo/...` dans `test/`.

## Données et règles métier

- SQLite (`sqflite`), une seule connexion `AppDatabase.instance`, `PRAGMA foreign_keys = ON`.
- Tables : `teams`, `players`, `sessions`, `participations`, `meta`. **`participations` est la seule source de vérité** : aucun cumul stocké.
- Agrégats via vues SQL (`v_player_match_results`, `v_standings`, `v_standings_per_match`, `v_top_scorers`, `v_top_assists`, `v_top_cards`, `v_group_totals`), recréées à chaque ouverture.
- Barème 3 / 1 / 0. Classement = séances `status = 'CLOSED'` **et** `is_ranked = 1`.
- Clôture bloquante : score manquant, joueur en double, écart d'effectif > 1 (sauf `allow_uneven_teams`). Non bloquante avec avertissement : somme des buts ≠ score.
- Joueur ayant joué : archivé (`is_active = 0`), jamais supprimé.
- **Multi-tenant** : tout est scopé par `team_id`. Les providers lisent `activeTeamIdProvider` et renvoient `null` / `[]` s'il est absent ; les écritures lèvent `StateError`. Session active dans `meta` sous `active_session_id_<teamId>`. Une requête sans filtre `team_id` sur une donnée de groupe est un bug.
- Backup/restore JSON (`features/settings/data/backup_service.dart`), modes fusion et écrasement.

## UI

- Couleurs uniquement via `context.colors` (`AppColorsExtension`, `core/theme/app_colors.dart`) ; thèmes clair et sombre (`AppTheme.lightTheme` / `darkTheme`). Pas de `Color(0x…)` en dur hors illustrations de l'onboarding.
- Police Inter (`google_fonts`), icônes `remixicon` (jamais Material Icons à la place).
- Dates avec `intl`, locale `fr_FR` (`9 sept.`, `mer. 9 sept. 2026 · 20h30`).
- Réutiliser `core/widgets/` (`AppCard`, `StatusBadge`, `InitialAvatar`, `PrimaryButton`, `Stepper3`…) avant d'en créer.
- Pas de système l10n : les libellés français sont écrits directement dans les widgets.

## Workflow

- Après une implémentation, faire relire par l'agent `statoo-reviewer` avant de commiter.
- Commits : skill `smart-commit` (messages en anglais, Conventional Commits, scope = feature).
- Ne jamais éditer `*.g.dart` / `*.freezed.dart` à la main (hook bloquant) : regénérer.
