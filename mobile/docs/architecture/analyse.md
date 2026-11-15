# Analyse de l'application Flutter Statoo (`mobile/`)

État constaté le 14/11/2026, branche `staging`, commit `2a9a3c7`. Sauf mention contraire, les chemins sont relatifs à `mobile/lib/`. Les déductions sont marquées **[déduit]**. Cette analyse complète `docs/ai/ARCHITECTURE.md` et `docs/architecture.md` à la racine, ce dernier datant du 12/10 (voir « Contradictions »).

## 1. Architecture

**Découpage.** Feature-first inspiré de Clean Architecture : `core/{data,domain,media,router,theme,utils,widgets}` et `features/<nom>/{domain,data,application,presentation}`.
- 8 features ont les 4 couches.
- `home` n'a que `presentation/`.
- `onboarding` n'a que `application/` et `presentation/`.

**Le domaine est pur** (aucun import Flutter, Riverpod ou data). Seules 4 entités utilisent freezed : `Player`, `Session`, `Participation` et `stats_models`. Les autres sont des classes Dart simples.

**Violations constatées de la règle de dépendance :**
- `settings/data/backup_service.dart:5-6,19` : la couche data importe Flutter et Riverpod, et déclare un provider.
- `finance/data/finance_repository.dart:7,36-41` : la couche data dépend de `shared/data` et fait des appels HTTP.
- `shared/presentation/shared_group_screen.dart` (1 723 l.) : SQL brut (l.143-160, 1161-1166) et appels HTTP directs depuis la présentation.
  - Même chose pour `add_manager_bottom_sheet.dart:122` et `finance/presentation/finances_screen.dart:95`.
- `sessions/application/sessions_provider.dart:5-10` importe 6 autres features. `core/domain/statoo_repository.dart` importe des features (core → features) et n'est pas utilisé.

## 2. Points d'entrée

- **`main.dart:24-52`.**
  - Lit `hasSeenOnboarding` dans SharedPreferences.
  - Charge l'équipe active et appelle `SharedService.load()`, qui relit le jeton et lance la synchro automatique.
  - Crée un `ProviderScope` avec 4 overrides.
  - `MyApp` ferme SQLite sur `paused` et `detached`, et invalide 19 providers sur `shared.onChanged` (l.87, réassigné à chaque `build()`).
- **`main_web.dart`.** Positionne `databaseFactory = databaseFactoryFfiWeb` (SQLite WASM : `web/sqlite3.wasm`, `web/sqflite_sw.js`), puis appelle `main()`.
- **Router** (`core/router/app_router.dart`).
  - `/splash`, puis `/onboarding` ou `/bienvenue` selon l'état.
  - Shell de 5 onglets : `/`, `/seances`, `/joueurs`, `/classement`, `/stats`.
  - Routes racine : `/finances`, `/groupe-partage`, `/seances/:id/finances`, `/creer-equipe`, `/ajouter-joueurs-initiaux`, `/reglages`, `/joueurs/:id`, `/seances/nouvelle`, `/seances/:id`.
- **Configuration.** Un seul `--dart-define`, `STATOO_API`, avec pour défaut `https://statoo-api.onrender.com` (**production**). Il est défini deux fois : `shared/presentation/shared_group_screen.dart:56-58` et `recovery_request_sheet.dart:109-111`.

## 3. Modèle de données (`core/data/app_database.dart`)

- **Schéma v8**, fichier `statoo.db`. Le numéro de version est écrit deux fois (l.15 et l.62).
- **Tables.**
  - `teams`, `players` (`team_id` FK CASCADE).
  - `sessions` : `status` est `DRAFT` ou `CLOSED` (CHECK), `session_type` est `CLASSIC_2` ou `TOURNAMENT_3`. Champs `score_*`, `wins_*`, `unassigned_goals_*`, `result`, `draw_points`, `allow_uneven_teams`, `is_ranked`, `team_names` et `team_colors` (JSON).
  - `participations` : `UNIQUE(session_id, player_id)`, `player_id` RESTRICT.
  - `meta` : magasin clé-valeur.
- **Triggers multi-tenant.** `trg_participations_same_team_insert/update` (l.251-278) empêchent de lier une participation à un joueur et une séance de groupes différents.
- **7 vues** : `v_player_match_results`, `v_standings`, `v_standings_per_match`, `v_top_scorers`, `v_top_assists`, `v_top_cards`, `v_group_totals`. `_ensureViews` les recrée si elles manquent à l'ouverture.
- **Migrations `onUpgrade`** (l.76-196) :
  - v4 : `team_id` ;
  - v5 : CLOSED sans score devient DRAFT ;
  - v6 : tournoi ;
  - v7 : reconstruction de `sessions` ;
  - v8 : noms et couleurs des équipes ;
  - puis `foreign_key_check`.
  - Fixtures de test : seulement v6 et v7.
- **`meta` sert de stockage métier.** On y trouve `active_session_id_<team>`, `active_team_id` (dupliqué dans SharedPreferences), les **points financiers** `finance_point_<g>_<id>` (pas de table dédiée), `outbox_<opId>`, `shared_*`, `live_stats_*`, `mvp_weights_*`, `min_players_per_session_*` et `team_short_name_*`.
- **Backup** (`settings/data/backup_service.dart`).
  - Format JSON v2 : groupes, joueurs (photos en data-URI), séances, participations et **toute la table `meta`**.
  - Restauration complète en une transaction.
  - Fusion refusée si le backup contient des finances ou un groupe partagé.

## 4. Domaine métier

**Vocabulaire du code.** Groupe = `team` / `team_id` · séance = `Session` · participation · joueur = `Player` (« member » côté API) · équipes A/B/C · tournoi 3 équipes · point financier, échéance, cotisation (`contribution`), pénalité, dépense, don · joueur du mois (MVP) · groupe partagé · gestionnaire · code de récupération.

**Clôture** (`sessions/domain/session_close_rules.dart:41-105`) : 6 bloqueurs.
- `missingScore`, `duplicatePlayer`.
- `unevenTeams` : écart > 1, **sauf si `allow_uneven_teams`** est actif.
- `goalsMismatch`, `assistsExceedGoals`, `selfAssist`.
- La validation est refaite dans la transaction (`sessions/data/sessions_repository.dart:742-825`).

**Initialisation du score.** Une séance classique est créée à 0-0 avec un résultat nul (`sessions_provider.dart:223-233`, `TODO(cdc)`). En pratique, le bloqueur « score absent » ne s'applique donc qu'au tournoi.

**Buts et score** (`sessions/domain/goal_score_sync.dart`). Un but attribué consomme d'abord les buts non attribués. Le score ne baisse jamais automatiquement.

**Classement.**
- Points 3/1/0 sur les séances closes et classées ; nuls de tournoi = `draw_points`.
- Ordre : points > victoires > matchs > nom.
- Le ratio exige au moins 50 % des séances classées.

**MVP mensuel.** Poids par défaut dans `ranking/domain/mvp_weights.dart` (10/3/0, +2, +1, −0,5, −1). Le calcul existe en SQL (`ranking/data/ranking_repository.dart:293-323`) **et** en Dart (`MvpCalculator`), et les deux divergent sur le nul.

**Finance.**
- À la création d'une séance, un point financier est créé avec une ligne par membre actif (`sessions_repository.dart:403-411`).
- `FinancialPoint.validate` (`finance/domain/financial_point.dart:91-119`).
- Après validation, toute correction exige un motif.

## 5. Authentification, rôles, multi-tenant

- **Deux modes.** Un groupe local sans compte, ou un « groupe partagé » relié à l'API (`shared/data/shared_service.dart:112-160`). L'API doit être en HTTPS, sauf localhost, 127.0.0.1 et 10.0.2.2.
- **Secrets.**
  - Le jeton est dans `flutter_secure_storage` (clé `statoo_connection`).
  - Les mots de passe du compte collectif et des gestionnaires sont conservés côté admin (`shared/data/collective_access.dart`).
  - Sur le web, ce stockage repose sur localStorage **[déduit]**.
- **Rôles** (`shared_service.dart:39-49`).
  - Même matrice que le backend.
  - `requireWrite` est absent des réglages MVP, du minimum de joueurs et de `saveTeam` **[déduit]**.
  - Aucun rafraîchissement de jeton.
- **`team_id`.** Filtre `WHERE team_id = ?` dans les repositories, triggers SQL, `_assertPlayersInTeam` (`sessions_repository.dart:432-451`).

## 6. Communication

- **Client HTTP.** `core/data/shared_http.dart` avec une variante native (`dart:io`) et une variante navigateur (`package:http`). Timeout de 90 s.
- **Erreurs.** `SharedApiException(status, detail)` et `SharedNetworkException`. `jsonDecode` n'est pas protégé : une réponse HTML de 502 lève une `FormatException`.
- **17 endpoints consommés.**
  - `/auth/login`, `/auth/recover`, `/auth/logout`.
  - `POST /groups`, `GET /groups/{g}`, `/sync`, `PUT /financial-settings`.
  - Gestion des comptes : `POST /accounts`, `/accounts/{id}/password` et `/password/verify`, `/shared-access/verify`, `PUT /accounts/{id}/roles`, `PUT /members`.
  - Ouverture et arbitrage : `/opening`, `/opening/approve`, `/documents/…/resolve` et `/transfer`.
  - Détail et contrat : `docs/architecture/vue-densemble.md` à la racine.
- **Outbox** (`shared_service.dart:350-680`).
  - Événements `outbox_<id>` dans `meta`.
  - Synchro toutes les 45 s : GET snapshot, POST de chaque événement, nouveau GET.
  - Statuts : `accepted`, `conflict`, `rejected` (400/403/404/409/410/422), `blocked` (409 `active_session_conflict`), `pending`.
  - Référence : `docs/outbox-sync.md`.
- **Import du snapshot** (l.714-1002). Les séances reçues sont insérées telles quelles ; une séance `CANCELLED` côté serveur est traitée à part (l.939).

## 7. Tests

- 107 fichiers sous `test/`, dont 2 dossiers non suivis par git (`test/features/ranking/{application,domain}`).
- **Volume.**
  - Comptage statique : 452 `test(` et 279 `testWidgets(`.
  - Exécution : voir l'étape 6 du rapport d'onboarding.
- **Couverture.** Forte sur `shared` et `sessions`, faible sur `stats`, `onboarding` et `players`. Pas d'`integration_test/`, pas de golden.

## 8. Dette

- **Un seul TODO** : `sessions_provider.dart:223`.
- **Code mort** : `core/domain/statoo_repository.dart`, `core/widgets/placeholder_screen.dart`, `AppDatabase.seedDemoData`. `stats/domain/stats_calculator.dart` n'est utilisé que par les tests.
- **Fichiers de plus de 1 000 lignes** : `shared_group_screen.dart`, `standings_screen.dart`, `session_detail_screen.dart`, `new_session_screen.dart`, `shared_service.dart`.
- **pubspec.**
  - `cupertino_icons` n'est pas utilisé.
  - `flutter_lints` et `very_good_analysis` cohabitent.
  - La description est « A new Flutter project. ».
- **Travail en cours non suivi (FEAT-01, export CSV du classement).** `ranking/domain/standings_csv_formatter.dart`, `ranking/application/{file_export_platform,stats_export_service}.dart`.
  - Aucun écran ne les appelle encore.
  - Le formateur ne neutralise pas l'injection de formules (`=`, `+`, `-`, `@`).

## 9. Risques

- **Schéma divergent.** Sur une base neuve, `sessions.team_id` est nullable (l.318) ; sur une base migrée depuis une version antérieure à v7, il est `NOT NULL` (l.146). `meta.schema_version` vaut encore `'1'`.
- **Index.** Aucun index secondaire sur `team_id` ou `player_id`. Les vues sont recalculées à chaque lecture.
- **Confiance totale dans le snapshot serveur** à l'import.
- **Backup non chiffré** contenant tout `meta`.
- **URL par défaut de production** : un build sans `--dart-define` pointe vers la production.

## Contradictions avec la documentation existante (le code fait foi)

| Affirmation | Source | Code |
|---|---|---|
| 4 couches étanches dans toutes les features | `AGENTS.md` §4 | home et onboarding incomplets ; violations listées au §1 |
| « Entités pures freezed » | `AGENTS.md` §4 | 4 entités freezed seulement |
| Clôture bloquante sur 3 cas « sans dérogation » | `AGENTS.md` §5 | 6 bloqueurs ; dérogation `allow_uneven_teams` |
| `participations` = unique source de vérité statistique | `AGENTS.md` §5 | Scores, victoires et buts non attribués sont dans `sessions` |
| « calculs de reliquat » | `AGENTS.md` §6 | Le terme « reliquat » est absent de `lib/` (solde, avance, dette) |
| Statuts `DRAFT/CLOSED/CANCELLED` | `docs/ai/GLOSSAIRE.md` | SQLite n'accepte que `DRAFT/CLOSED` ; `CANCELLED` n'existe que dans le protocole de synchro |
| « Aucun client serveur métier » | `docs/architecture.md` (12/10) | Obsolète : `shared_service.dart` |
| « Fermeture SQLite en arrière-plan non trouvée » | `docs/architecture.md` | Obsolète : `app_database.dart:37-42` |
