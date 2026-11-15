# mobile/ — application Flutter Statoo

Ce fichier complète le `CLAUDE.md` et l'`AGENTS.md` racine. Il s'agit de l'app de référence fonctionnelle : la même base de code sert Android, iOS et le web (`lib/main_web.dart`). L'analyse détaillée est dans [docs/architecture/analyse.md](docs/architecture/analyse.md).

## Stack (vérifiée le 14/11/2026)
- Flutter 3.47.5 / Dart 3.13.4. SDK dans `~/development/flutter/bin`, **absent du PATH bash** : préfixer avec `export PATH=$HOME/development/flutter/bin:$PATH`.
- Riverpod 3 (providers écrits à la main, sauf router et thème), GoRouter 18, freezed (4 entités), sqflite et sqflite_common_ffi_web (WASM).
- `package:http` et `dart:io`, `flutter_secure_storage`, `very_good_analysis`.

## Commandes (depuis `mobile/`)
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart analyze lib test        # 14/11 : 0 erreur, 0 warning, 71 infos
flutter test                 # 15/11 : 1482/1482 sur fix/mobile-red-tests (staging 2a9a3c7 : 16 échecs, corrigés sur cette branche)
flutter run --dart-define=STATOO_API=<url>
flutter build web --release --target lib/main_web.dart --no-web-resources-cdn --dart-define=STATOO_API=<url>   # nécessite d'abord : dart run sqflite_common_ffi_web:setup
```
- Sans `--dart-define=STATOO_API`, l'app vise **l'API de production** (`https://statoo-api.onrender.com`).

## Architecture locale
- `lib/core/` : `data/app_database.dart` (schéma SQLite v8, 7 vues `v_*`, triggers multi-tenant, migrations `onUpgrade`), `router/app_router.dart`, `theme/`, `widgets/`.
- `lib/features/<nom>/{domain,data,application,presentation}` : finance, home (présentation seule), onboarding, players, ranking, sessions, settings, shared, stats, team.
- `features/shared/` : groupe partagé, client API, outbox (`shared_service.dart`), comptes, récupération.
- La table `meta` sert de magasin clé-valeur métier : séance active, points financiers, outbox, réglages. Voir l'analyse, §3.

## Conventions
- Lire [`docs/design-system.md`](../docs/design-system.md) avant toute UI : Poppins, `context.colors`, clair/sombre, 320 et 393 dp, texte agrandi, `remixicon`.
- Imports relatifs dans `lib/`, `package:statoo` dans `test/`.
- Toute requête porte un `team_id`. Après une mutation, invalider explicitement les providers dérivés.
- Avant de toucher `app_database.dart`, une vue `v_*` ou le format du backup : skill `db-migration`.
- Pour une nouvelle feature : skill `new-feature`.
- TDD et revue obligatoires : voir `AGENTS.md` §1.

## Interdits
- Éditer à la main les fichiers `*.g.dart` et `*.freezed.dart` (un hook `.claude/hooks/guard-generated.js` les protège).
- Accéder à SQLite ou HTTP depuis `presentation/` dans du code neuf (dette existante dans `shared_group_screen.dart`).
- Importer Flutter ou Riverpod dans `domain/`.
- Modifier une règle de clôture ou de classement sans aligner `backend/app/main.py` et `web/domain.mjs` (triple implémentation).
- Lancer des e2e ou un build sans `--dart-define` vers une API de test.
