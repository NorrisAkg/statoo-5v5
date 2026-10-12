# Architecture et modules

État observé le 12 octobre 2026, branche `refonte`, référence `40f13fc`. Description du code, sans certification de fonctionnement sur appareil.

## Organisation

Architecture feature-first inspirée de Clean Architecture : domain contient modèles et règles métier, data les interfaces et implémentations SQLite, application les providers/contrôleurs Riverpod, presentation les écrans et feuilles modales. Les interfaces de repositories sont généralement dans data ; toutes les fonctionnalités n'ont pas les quatre couches.

| Module | Responsabilité | Sources |
|---|---|---|
| core | Connexion, vues SQL, router, thème, widgets | `lib/core/data/app_database.dart`, `lib/core/router/app_router.dart` |
| onboarding | Introduction et premier lancement | `lib/features/onboarding/application/onboarding_provider.dart` |
| team | Groupes et sélection du groupe actif | `lib/features/team/application/team_provider.dart` |
| players | CRUD, archivage, fiche et historique | `lib/features/players/data/players_repository.dart` |
| sessions | Composition, scores, tournoi, clôture | `lib/features/sessions/application/sessions_provider.dart` |
| ranking | Points, ratio, buts, passes, discipline, MVP | `lib/features/ranking/data/ranking_repository.dart` |
| stats | Totaux du groupe | `lib/features/stats/data/stats_repository.dart` |
| settings | Réglages par groupe et backup JSON | `lib/features/settings/data/backup_service.dart` |
| home | Synthèse et accès aux parcours | `lib/features/home/presentation/home_screen.dart` |

## Démarrage et navigation

main.dart initialise Flutter, lit SharedPreferences et recherche le groupe actif avant runApp. Il injecte « onboarding vu » et « groupe existant » dans ProviderScope. La recherche ouvre SQLite et peut récupérer un groupe depuis les anciennes préférences.

Le router commence sur /splash puis applique les gardes onboarding/groupe. StatefulShellRoute.indexedStack conserve cinq branches, dans l'ordre du code : /, /seances, /joueurs, /classement, /stats. Détails, réglages et parcours initiaux utilisent le navigateur racine.

Sources : `lib/main.dart`, `lib/core/router/app_router.dart`, `lib/features/team/data/team_repository.dart`.

## Lecture et mutation

Les providers injectent les repositories et observent activeTeamIdProvider. Sans groupe, les lectures retournent généralement [] ou null ; les mutations exigent un groupe actif. SessionsController et PlayersNotifier invalident explicitement les données dérivées après écriture. Les invalidations ne sont pas déduites automatiquement des tables modifiées.

Sources : `lib/features/sessions/application/sessions_provider.dart`, `lib/features/players/application/players_provider.dart`, `lib/features/ranking/application/ranking_providers.dart`.

## Persistance et intégrations

AppDatabase.instance conserve une connexion ouverte à la demande. Repositories, requêtes paramétrées et transactions forment l'accès local. Les agrégats utilisent principalement les vues SQL ; moyenne, éligibilité et tri MVP sont complétés en Dart.

Intégrations natives : galerie (image_picker), sélection de fichiers (file_picker), partage (share_plus), répertoires temporaires (path_provider). Aucun client serveur métier ni Supabase n'est branché dans les sources examinées.

Sources : `lib/core/data/app_database.dart`, `lib/features/ranking/data/ranking_repository.dart`, `lib/features/settings/data/backup_service.dart`, `pubspec.yaml`.

## Limites

StatooRepository et StatsCalculator existent sans appel de production trouvé dans lib ; les tests utilisent le calculateur. Les chemins de calcul SQL/Dart doivent être surveillés pour éviter leur divergence. La fermeture SQLite à la mise en arrière-plan demandée par le CDC n'a pas été trouvée.

Sources : `lib/core/domain/statoo_repository.dart`, `lib/features/stats/domain/stats_calculator.dart`, `lib/core/data/app_database.dart`.
