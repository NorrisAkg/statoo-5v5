# Audit Statoo — 05. Architecture et qualité du code

- **Domaine** : architecture, découpage en couches, dépendances, taille du code, duplications, code mort, conventions.
- **Date** : 14/11/2026. Arbre de travail de `fix/mobile-red-tests` (HEAD `2a9a3c7`, plus modifications non commitées).
- **Méthode** : statique. Greps sur les imports, scripts Python locaux (graphe d'imports Dart, composantes fortement connexes, longueur des fonctions par appariement d'accolades pour Dart/JS et par AST pour Python), lecture de code, exploitation de `docs/audit/raw/dart-analyze.log`. Aucune suite relancée.
- **Limites** : la longueur des fonctions Dart/JS est mesurée par une heuristique (en-tête de déclaration indenté de 0 à 4 espaces, appariement d'accolades hors chaînes et commentaires `//`) ; les bornes citées ont été vérifiées par sondage (`_buildStep2`, `build` de `add_team_players_screen`, `sportEditor`, `financeEditor`, `_createViews`, `_management`). Les règles métier dupliquées sont seulement localisées ici ; leur cohérence relève du domaine A.

## 1. Synthèse

Le domaine mobile est réellement pur : aucun fichier `domain/` n'importe Flutter, Riverpod, sqflite ni une autre couche, et les imports de `lib/` sont tous relatifs (0 `package:statoo/`, 416 imports relatifs). `dart analyze` ne remonte que 71 infos, dont 11 dans `lib/`. En revanche, l'architecture se dégrade fortement autour de deux blocs : la feature `shared` (écran qui exécute du SQL et des appels HTTP bruts, service de 1 003 lignes mêlant HTTP, SQLite, synchronisation et droits) et le backend, dont toute l'API tient dans une fermeture `create_app` de 638 lignes, sur un agrégat JSON par groupe, avec un verrou `threading.Lock` global qui sérialise toutes les requêtes, PostgreSQL compris. Les 10 features mobiles forment un graphe très couplé (110 imports inter-features, 12 paires de dépendances mutuelles). Onze fichiers dépassent 900 lignes et une quarantaine de fonctions dépassent 100 lignes, jusqu'à 631 lignes pour une seule méthode `build` d'étape. La matrice des rôles existe en six copies (deux par application). Le code mort reste limité (environ 420 lignes) mais inclut une troisième implémentation du barème utilisée uniquement en test.

**Note proposée : 2,5/5.** Fondations saines (domaine pur, conventions d'import, analyse statique propre), mais règle « muter via le contrôleur » non respectée dans `shared` et `finance`, backend monolithique non découpable sans refonte, et fichiers d'écran géants dans les zones à risque élevé (`sessions/`).

## 2. Tableau récapitulatif

| ID | Sévérité | Titre | Fichier principal | Effort |
|---|---|---|---|---|
| ARC-001 | Majeur | Backend monolithique : 23 routes en fermetures dans une `create_app` de 638 lignes | `backend/app/main.py:244` | L |
| ARC-002 | Majeur | Verrou `threading.Lock` global et inconditionnel sur toutes les requêtes | `backend/app/main.py:284` | S |
| ARC-003 | Majeur | Feature `shared` : la présentation fait du SQL direct et des requêtes HTTP brutes | `mobile/lib/features/shared/presentation/shared_group_screen.dart:143` | L |
| ARC-004 | Majeur | Matrice des rôles en six copies, aucune source unique côté mobile | `mobile/lib/features/shared/data/shared_service.dart:39` | M |
| ARC-005 | Majeur | Fichiers et fonctions géants dans les zones à risque | `mobile/lib/features/sessions/presentation/new_session_screen.dart:645` | L |
| ARC-006 | Mineur | Couplage fort entre features : 110 imports, 12 dépendances mutuelles | `mobile/lib/features/sessions/application/sessions_provider.dart:3-12` | M |
| ARC-007 | Mineur | Finance : l'UI mute le repository sans contrôleur et déclare un provider | `mobile/lib/features/finance/presentation/financial_point_screen.dart:112` | M |
| ARC-008 | Mineur | Règle d'écart d'effectif réimplémentée dans deux écrans | `mobile/lib/features/sessions/presentation/new_session_screen.dart:158` | S |
| ARC-009 | Mineur | Code mort, dont un calculateur de barème utilisé seulement en test | `mobile/lib/features/stats/domain/stats_calculator.dart` | S |
| ARC-010 | Mineur | Endpoints backend sans client | `backend/app/main.py:590` | XS |
| ARC-011 | Mineur | Couche data et `core` qui violent la règle de dépendance | `mobile/lib/features/settings/data/backup_service.dart:5-6,19` | S |
| ARC-012 | Mineur | Cycle d'imports entre deux fichiers de `shared/presentation` | `mobile/lib/features/shared/presentation/add_manager_bottom_sheet.dart:13` | XS |
| ARC-013 | Mineur | Conventions déclarées non suivies (freezed, Riverpod généré) | `AGENTS.md` §4, `.claude/rules/domain.md` | M |
| ARC-014 | Mineur | Aucun garde-fou automatique de l'architecture | `mobile/analysis_options.yaml` | S |
| ARC-015 | Mineur | `docs/ai/ARCHITECTURE.md` décrit une architecture qui n'existe pas | `docs/ai/ARCHITECTURE.md:46` | XS |
| ARC-016 | Info | Analyse statique : 71 infos, 11 `// ignore` dans `lib/` | `docs/audit/raw/dart-analyze.log` | XS |

## 3. Constats

### ARC-001 — Backend monolithique : 23 routes en fermetures dans une `create_app` de 638 lignes
- Sévérité : Majeur / Domaine : architecture backend / Statut : confirmé
- Preuve :
  - `python3 -I` + `ast` sur `backend/app/*.py` : `create_app` fait **638 lignes** (`main.py:244`), suivie de `validate_sport` 91 l. (`:903`), `sync` 73 l. (`:753`), `register` 70 l. (`:350`), `recover` 61 l. (`:444`).
  - `grep -c "@app\.\(get\|post\|put\)" main.py` → 23 décorateurs de route, tous indentés dans `create_app` (de `:268` à `:861`). Les dépendances (`db` `:298`, `authenticate` `:302`, `scoped` `:315`, `require` `:321`), les limiteurs (`attempts` `:285` et suivants) et le verrou sont des variables locales capturées.
  - `main.py` = 996 des 1 160 lignes de `backend/app/` ; pas de `APIRouter`, ni couche service ou repository.
  - `backend/app/models.py:11-14` : `Group(id, state: JSON)`. Chaque mutation lit `copy.deepcopy(group.state)` (`main.py:309`) puis réécrit l'agrégat entier (`group.state = state`, 16 occurrences de `:500` à `:878`).
  - Schéma créé par `Base.metadata.create_all` au démarrage (`main.py:256`), aucun outil de migration.
- Impact : impossible de tester une règle sans monter l'application FastAPI ; tout changement touche le même fichier et la même fonction ; la forme de l'agrégat JSON n'est décrite nulle part par un schéma, donc toute évolution de structure exige un code de migration ad hoc dans les routes. Le coût de chaque requête croît avec la taille de l'agrégat (copie profonde et réécriture complète) [déduit].
- Recommandation : extraire les fermetures en `APIRouter` par domaine (auth, comptes, documents, sync), injecter `engine`, verrou et limiteurs via `app.state` ou des dépendances ; décrire l'agrégat par des modèles Pydantic ; prévoir Alembic avant la prochaine évolution de schéma.
- Effort : L

### ARC-002 — Verrou `threading.Lock` global et inconditionnel sur toutes les requêtes
- Sévérité : Majeur / Domaine : architecture backend / Statut : confirmé
- Preuve : `backend/app/main.py:282-284` (« Also serialize SQLite development transactions. PostgreSQL uses row locks across workers. ») puis `:298-300` :
  ```python
  def db():
      with lock, Session(engine) as session, session.begin():
          yield session
  ```
  Le verrou n'est conditionné à aucun dialecte. `render.yaml:8` lance `uvicorn app.main:app` sans `--workers`, donc un seul processus.
- Impact : en production (PostgreSQL), toutes les requêtes de tous les groupes, lectures comprises (`authenticate` dépend de `db`), sont exécutées une par une, y compris pendant les allers-retours réseau vers Neon. Le commentaire contredit le code. Une requête lente bloque tous les tenants [déduit].
- Recommandation : n'acquérir le verrou que si `engine.dialect.name == "sqlite"` ; s'appuyer sur `with_for_update()` (déjà présent `:308`) pour PostgreSQL. Ajouter un test qui vérifie que deux groupes distincts ne se bloquent pas.
- Effort : S

### ARC-003 — Feature `shared` : la présentation fait du SQL direct et des requêtes HTTP brutes
- Sévérité : Majeur / Domaine : couches mobile / Statut : confirmé
- Preuve :
  - SQL dans un écran : `shared_group_screen.dart:10` importe `core/data/app_database.dart` ; `:143-158` `AppDatabase.instance.database` puis `db.query('teams'…)`, `db.query('players'…)`, `db.query('meta'…)` ; idem `:1161-1166`.
  - HTTP construit dans l'UI : 7 appels `service.request('POST'|'PUT', '/groups/${…}/…')` dans la présentation (`shared_group_screen.dart:474, 677, 773, 882, 954, 1167` ; `add_manager_bottom_sheet.dart:122`).
  - `ref.read/watch(sharedServiceProvider)` : 22 accès depuis `presentation/`, le service étant un objet mutable avec callback `onChanged` (`shared_service.dart:54`) et un compteur `SharedRevision` manuel (`shared_providers.dart:12-17`).
  - `SharedService` (`shared/data/shared_service.dart`, 1 003 lignes) mélange HTTP (`request` `:99`), SQLite (`importSnapshot` `:714`, 289 lignes), stockage sécurisé (import `flutter_secure_storage` `:5`), file d'opérations (`enqueue` `:350`), synchronisation (`synchronize` `:542`, 139 lignes) et droits (`permits` `:39`).
  - Les données circulent en `Map<String, dynamic>` : 37 occurrences dans `shared_service.dart`, 29 dans `shared_group_screen.dart`.
  - Inventaire des imports `presentation → data` : 12 imports, dont `app_database.dart`, `shared/data/collective_access.dart` (×3), `registration_operation.dart`, `manager_password.dart`, `settings/data/backup_service.dart` (×2), `core/data/shared_http_error.dart` (×2), `core/data/occurrence_registry.dart`.
- Impact : viole `.claude/rules/presentation.md` (« Muter via le contrôleur de la feature, jamais le repository directement ») et la règle de dépendance d'`AGENTS.md` §4. Les chemins d'API sont dispersés dans les widgets, ce qui rend la parité avec `web/client.mjs` et les tests de contrat difficiles ; aucune entité typée ne protège contre une évolution du format serveur.
- Recommandation : introduire un `SharedController` (Notifier) et un `SharedApi` typé dans `shared/data` ; déplacer la construction du payload d'inscription dans `data` ; découper `SharedService` (client HTTP, synchroniseur, importeur de snapshot, politique de droits en `domain`).
- Effort : L

### ARC-004 — Matrice des rôles en six copies, aucune source unique côté mobile
- Sévérité : Majeur / Domaine : duplication transverse / Statut : confirmé
- Preuve (liste des rôles autorisés à l'édition sport `ADMIN, PDT, VP, SG, SGA` et finance `TR, TGA`) :
  - backend : `main.py:30-33` (`ROLES`, `AUTHORS`) et `main.py:518` (`{"PDT", "VP"}` en dur) ;
  - web : `web/domain.mjs:41-50` (`capabilities`) et **à nouveau** en dur dans `web/app.mjs:2824` (`transferEditor`) au lieu d'appeler `capabilities` ;
  - mobile : `shared/data/shared_service.dart:39-48` (`permits`) et **à nouveau** dans `shared/presentation/shared_group_screen.dart:896-898` ; libellés des rôles dans `shared_group_screen.dart:30-40`, réutilisés par `add_manager_bottom_sheet.dart:410`.
  - Aucun fichier `shared/domain/` ne définit les rôles côté mobile.
- Impact : `CLAUDE.md` annonce trois copies des règles ; le code en compte deux par application pour les rôles. Une modification de la matrice doit toucher six endroits ; un oubli dans la copie d'UI produit une liste de candidats au transfert différente des droits réels [déduit].
- Recommandation : mobile, créer `shared/domain/roles.dart` (enum + matrice) consommé par `SharedService` et l'écran ; web, faire passer `transferEditor` par `capabilities` ; backend, une constante unique. À terme, générer les trois copies depuis une table commune ou la vérifier par un test de parité. Détail métier : domaine A.
- Effort : M

### ARC-005 — Fichiers et fonctions géants dans les zones à risque
- Sévérité : Majeur / Domaine : maintenabilité / Statut : confirmé (longueurs de fonctions : heuristique vérifiée par sondage)
- Preuve : `wc -l` hors code généré, top 15 :

  | Lignes | Fichier |
  |---|---|
  | 2 944 | `web/app.mjs` |
  | 1 723 | `mobile/lib/features/shared/presentation/shared_group_screen.dart` |
  | 1 692 | `mobile/lib/features/ranking/presentation/standings_screen.dart` |
  | 1 492 | `mobile/lib/features/sessions/presentation/session_detail_screen.dart` |
  | 1 316 | `mobile/lib/features/sessions/presentation/new_session_screen.dart` |
  | 1 175 | `mobile/lib/features/onboarding/presentation/onboarding_screen.dart` |
  | 1 005 | `mobile/lib/features/settings/presentation/settings_screen.dart` |
  | 1 003 | `mobile/lib/features/shared/data/shared_service.dart` |
  | 996 | `backend/app/main.py` |
  | 960 | `mobile/lib/features/finance/presentation/finances_screen.dart` |
  | 929 | `mobile/lib/features/finance/presentation/financial_point_screen.dart` |
  | 922 | `mobile/lib/features/home/presentation/home_screen.dart` |
  | 906 | `mobile/lib/features/sessions/data/sessions_repository.dart` |
  | 843 | `mobile/lib/features/sessions/presentation/live_stats_panel.dart` |
  | 808 | `mobile/lib/core/data/app_database.dart` |

  Fonctions de plus de 100 lignes : environ 40 (Dart + JS) et 1 en Python. Les plus longues :

  | Lignes | Fonction |
  |---|---|
  | 638 | `create_app` — `backend/app/main.py:244` |
  | 631 | `_buildStep2` — `new_session_screen.dart:645` |
  | 628 | `sportEditor` — `web/app.mjs:1468` |
  | 500 | `build` — `team/presentation/add_team_players_screen.dart:88` |
  | 346 | `build` — `sessions/presentation/add_late_players_bottom_sheet.dart:197` |
  | 320 | `auth` — `web/app.mjs:665` |
  | 308 | `build` — `team/presentation/create_team_screen.dart:143` |
  | 294 | `build` — `settings/presentation/settings_screen.dart:34` |
  | 289 | `importSnapshot` — `shared/data/shared_service.dart:714` |
  | 288 | `build` — `shared/presentation/add_manager_bottom_sheet.dart:179` |
  | 284 | `financeEditor` — `web/app.mjs:2097` |
  | 282 | `_createViews` — `core/data/app_database.dart:368` |
  | 257 | `build` — `sessions/presentation/live_stats_panel.dart:130` |
  | 256 | `transaction` (restauration) — `settings/data/backup_service.dart:157` |
  | 255 | `_management` — `shared/presentation/shared_group_screen.dart:1400` |

  `web/app.mjs` : 56 fonctions de premier niveau et 5 variables globales mutables (`let`, dont `tab` `:30`, `sessionFilters` `:37`, `onboardingStep` `:582`).
- Impact : les fichiers `sessions/` sont classés « zone sensible à risque élevé » (`AGENTS.md` §6) ; une méthode `build` de 631 lignes mêle validations, appels de contrôleur et rendu, ce qui rend les tests de widget fragiles et les revues lentes.
- Recommandation : découper par étape et par carte en widgets dédiés (`StatelessWidget`/`ConsumerWidget`) ; extraire les validations vers le domaine (voir ARC-008). Côté web, le portail étant gelé (déclaré), ne pas investir sauf reprise.
- Effort : L

### ARC-006 — Couplage fort entre features : 110 imports, 12 dépendances mutuelles
- Sévérité : Mineur / Domaine : dépendances mobile / Statut : confirmé
- Preuve : script de graphe d'imports sur `mobile/lib/features` : 110 imports inter-features répartis sur 45 arêtes orientées entre 10 features. Par couches source → cible : présentation → application 58, application → application 18, présentation → domaine 15, présentation → présentation 11, présentation → data 3, domaine → domaine 2, data → domaine 2, data → data 1.
  Paires mutuelles (A importe B et B importe A) : finance↔shared, finance↔sessions, stats↔team, players↔team, players↔shared, settings↔shared, settings↔team, sessions↔shared, sessions↔stats, sessions↔team, sessions↔settings, ranking↔team.
  Exemple : `sessions/application/sessions_provider.dart:5-10` importe 6 features (finance, players, ranking, shared, stats, team). `team/presentation/create_team_screen.dart` importe settings (application, data, presentation), sessions, stats, ranking et players.
  Au niveau fichier, le graphe est acyclique sauf ARC-012.
- Impact : impossible d'isoler une feature ; une mutation dans `sessions` doit connaître les providers de 6 autres features pour invalider [déduit]. Pas de bloquant aujourd'hui, mais frein à toute extraction en package.
- Recommandation : centraliser les invalidations croisées (bus d'événements ou provider « révision de groupe » dans `core/`) ; déplacer `team_provider` (groupe actif), dépendance la plus partagée, dans `core/`.
- Effort : M

### ARC-007 — Finance : l'UI mute le repository sans contrôleur et déclare un provider
- Sévérité : Mineur / Domaine : couches mobile / Statut : confirmé
- Preuve :
  - `finance/presentation/financial_point_screen.dart:112-122` : `ref.read(financeRepositoryProvider)` puis `getPoint`, `isValidated`, `prepare` ; `:255-260` `savePoint(...)` puis invalidations manuelles de `financialPointsProvider` et `financialTotalsProvider`.
  - `finance/presentation/finances_screen.dart:139-147` : `createPeriod` directement sur le repository.
  - `settings/presentation/financial_defaults_section.dart:101` : idem.
  - `finance/presentation/finances_screen.dart:22` déclare `financialPeriodsProvider` dans la couche présentation.
  - `finance/application/` ne contient aucun Notifier de mutation (seulement `finance_providers.dart`).
- Impact : violation de `.claude/rules/presentation.md` ; la liste des invalidations après écriture est recopiée dans chaque écran, avec risque d'oubli (rafraîchissement incomplet de l'accueil ou des totaux) [déduit].
- Recommandation : créer un `FinanceController` (Notifier) qui encapsule `savePoint`, `createPeriod`, `saveDefaults` et leurs invalidations ; déplacer `financialPeriodsProvider` dans `application/`.
- Effort : M

### ARC-008 — Règle d'écart d'effectif réimplémentée dans deux écrans
- Sévérité : Mineur / Domaine : logique métier dans l'UI / Statut : confirmé
- Preuve : la règle « écart > 1 interdit sans dérogation » existe dans le domaine (`sessions/domain/session_close_rules.dart:62`, `uneven = (teamACount - teamBCount).abs() > 1;`) et est recopiée dans la présentation : `sessions/presentation/new_session_screen.dart:158` et `sessions/presentation/add_late_players_bottom_sheet.dart:157, 528, 534`. Le minimum de joueurs est aussi testé dans l'écran (`new_session_screen.dart:109-114`).
- Impact : trois expressions de la même règle côté mobile seul ; une évolution (par exemple 3 équipes) doit être portée dans chaque écran.
- Recommandation : exposer une fonction pure `teamBalanceError(counts, allowUneven)` dans `sessions/domain/` et l'appeler depuis les deux écrans ; la tester une fois.
- Effort : S

### ARC-009 — Code mort, dont un calculateur de barème utilisé seulement en test
- Sévérité : Mineur / Domaine : code mort / Statut : confirmé
- Preuve : graphe d'imports (fichiers de `lib/` jamais importés, hors points d'entrée et imports conditionnels) puis `grep` sur `lib/` et `test/` :
  - `core/domain/statoo_repository.dart` (10 l.) : aucune référence.
  - `core/widgets/placeholder_screen.dart` (43 l.) et `core/widgets/stepper3.dart` (53 l.) : aucune référence.
  - `AppDatabase.seedDemoData` (`core/data/app_database.dart:652`, 156 l.) : seule occurrence dans `lib/` = sa définition.
  - `features/stats/domain/stats_calculator.dart` (61 l.) : importé uniquement par `test/features/stats/stats_calculator_test.dart:4` et `test/features/sessions/tournament_3_teams_test.dart:11`. Le barème réellement utilisé est dans les vues SQL (`_createViews`, `app_database.dart:368`) ; une autre copie existe dans `web/summary.mjs:35-38`. Les tests du calculateur valident donc un code que l'application n'exécute pas.
  - Non commités : `features/ranking/application/stats_export_service.dart` (102 l.) et `file_export_platform.dart`, importés seulement par leur test (export CSV non branché, cohérent avec `00-cadrage.md` §2).
  - `core/data/shared_http_browser.dart` n'est pas mort : import conditionnel (`core/data/shared_http.dart:3`).
- Impact : environ 425 lignes sans usage ; risque de croire le barème couvert par `stats_calculator_test.dart` alors que les vues SQL ne le sont que par d'autres tests [déduit].
- Recommandation : supprimer `statoo_repository`, `placeholder_screen`, `stepper3`, `seedDemoData` ; soit supprimer `StatsCalculator`, soit en faire l'oracle d'un test qui compare ses résultats à ceux des vues SQL.
- Effort : S

### ARC-010 — Endpoints backend sans client
- Sévérité : Mineur / Domaine : code mort backend / Statut : confirmé
- Preuve : recherche des chemins dans `mobile/lib` et `web/*.mjs` :
  - `PUT /groups/{id}/account/password` (`main.py:590`) : aucun appelant mobile ni web.
  - `PUT /groups/{id}/account/recovery-code` (`main.py:612`) : aucun appelant.
  - `PUT /groups/{id}/sport-settings` (`main.py:711`) : appelé par le web (`web/app.mjs:2573`) mais pas par le mobile, qui ne fait que lire `sport_settings` (`shared_service.dart:750-752`).
  - Ces endpoints sont couverts par `backend/tests/` (28 occurrences).
- Impact : fonctionnalités ACCESS-03 et régénération de code de secours livrées côté serveur seulement (`docs/ai/BACKLOG.md:94, 117`) ; surface d'API exposée sans parcours utilisateur.
- Recommandation : soit brancher les écrans mobiles correspondants, soit tracer explicitement ces endpoints comme « serveur seul » dans le backlog.
- Effort : XS (traçage) à M (branchement)

### ARC-011 — Couche data et `core` qui violent la règle de dépendance
- Sévérité : Mineur / Domaine : couches mobile / Statut : confirmé
- Preuve :
  - `settings/data/backup_service.dart:5-6` importe `package:flutter/foundation.dart` et `flutter_riverpod`, et déclare `backupServiceProvider` (`:19`) dans la couche data.
  - `core/data/app_database.dart:1` importe `package:flutter/widgets.dart`.
  - `core/` dépend de `features/` : `core/domain/statoo_repository.dart:1-3` (mort, ARC-009) et `core/utils/player_sort.dart:1` (`features/players/domain/player.dart`). `core/router/app_router.dart` (19 imports de features) est un point de composition légitime.
  - `finance/data/finance_repository.dart` importe `shared/data/shared_service.dart` (seul import data → data inter-features).
  - Contrôle négatif : 0 import interdit dans `features/*/domain` et `core/domain` (Flutter, Riverpod, sqflite, http, data, application, presentation) ; 0 import `application → presentation` ; 0 import `data → application/presentation`.
- Impact : faible aujourd'hui ; empêche de tester `backup_service` hors Flutter et brouille la frontière data/application.
- Recommandation : déplacer `backupServiceProvider` dans `settings/application/` ; déplacer `player_sort.dart` dans `players/domain/`.
- Effort : S

### ARC-012 — Cycle d'imports entre deux fichiers de `shared/presentation`
- Sévérité : Mineur / Domaine : dépendances / Statut : confirmé
- Preuve : composantes fortement connexes du graphe de fichiers de `lib/` : une seule, `{add_manager_bottom_sheet.dart, shared_group_screen.dart}`. `add_manager_bottom_sheet.dart:13` importe `shared_group_screen.dart` pour `roleLabels` (défini `shared_group_screen.dart:30`, utilisé `add_manager_bottom_sheet.dart:410`).
- Impact : couplage d'un sous-composant à l'écran parent pour une constante métier.
- Recommandation : déplacer `roleLabels` dans `shared/domain/roles.dart` (voir ARC-004).
- Effort : XS

### ARC-013 — Conventions déclarées non suivies (freezed, Riverpod généré)
- Sévérité : Mineur / Domaine : conventions / Statut : confirmé
- Preuve :
  - `AGENTS.md` §4 (« Entités pures `freezed` ») et `.claude/rules/domain.md` (« Entités : `@freezed sealed class` ») : 4 fichiers sur 30 dans `domain/` utilisent `@freezed` (`player.dart`, `participation.dart`, `session.dart`, `stats_models.dart`) ; les autres sont des classes simples avec `==`/`hashCode` manuels (ex. `ranking/domain/mvp_weights.dart:2` désactive `avoid_equals_and_hash_code_on_mutable_classes`).
  - `riverpod_annotation` et `riverpod_generator` sont déclarés (`mobile/pubspec.yaml:38, 69`) mais seuls 2 fichiers utilisent `@riverpod` (`core/router/app_router.dart`, `core/theme/theme_provider.dart`) ; 79 providers sont manuels (27 `FutureProvider`, 21 `Provider`, 16 `NotifierProvider`, 8 `AsyncNotifierProvider`, 7 variantes `family`/`autoDispose`).
  - Point conforme : `prefer_relative_imports: true` (`analysis_options.yaml`) respecté partout dans `lib/` (0 import `package:statoo/`).
- Impact : deux styles de providers et d'entités coexistent ; les nouvelles contributions n'ont pas de modèle unique.
- Recommandation : acter la convention réelle (Riverpod manuel, freezed pour les entités persistées) dans `AGENTS.md` et les règles, ou planifier une migration ; retirer `riverpod_generator` si l'on garde le style manuel.
- Effort : M

### ARC-014 — Aucun garde-fou automatique de l'architecture
- Sévérité : Mineur / Domaine : qualité / Statut : confirmé
- Preuve : aucun test ne lit l'arborescence de `lib/` pour vérifier les imports (seul `test/core/source_encoding_test.dart` parcourt les sources, pour l'encodage) ; `analysis_options.yaml` n'active aucune règle de dépendance ; pas de linter JS (Prettier seul, `00-cadrage.md` §4.3) ; aucune CI (`CLAUDE.md`).
- Impact : les règles de couches d'`AGENTS.md` §4 ne reposent que sur la revue humaine ; ARC-003, ARC-007 et ARC-011 en sont la conséquence [déduit].
- Recommandation : ajouter un test Dart qui échoue si un fichier `domain/` importe Flutter/Riverpod/data ou si `presentation/` importe `core/data/app_database.dart` ou un `*/data/*` ; l'exécuter dans la future CI.
- Effort : S

### ARC-015 — `docs/ai/ARCHITECTURE.md` décrit une architecture qui n'existe pas
- Sévérité : Mineur / Domaine : documentation d'architecture / Statut : confirmé
- Preuve : `docs/ai/ARCHITECTURE.md:46` présente `core/domain/` comme « Interfaces génériques (StatooRepository) », interface jamais utilisée (ARC-009) ; la règle « Entités `freezed` » et « aucune dépendance Flutter ni Riverpod » de la couche data y est affirmée alors que ARC-011 et ARC-013 la contredisent ; le diagramme annonce « Python 3.13 ». La doc d'onboarding (`mobile/docs/architecture/analyse.md:12-19, 126, 149` ; `backend/docs/architecture/analyse.md:7-9, 41`) est, elle, cohérente avec les constats ci-dessus après revérification.
- Impact : un nouvel arrivant ou un agent suit une architecture fictive.
- Recommandation : marquer `docs/ai/ARCHITECTURE.md` comme historique ou le réaligner sur `mobile/docs/architecture/analyse.md`.
- Effort : XS

### ARC-016 — Analyse statique : 71 infos, 11 `// ignore` dans `lib/`
- Sévérité : Info / Domaine : qualité / Statut : confirmé
- Preuve :
  - `docs/audit/raw/dart-analyze.log` : « 71 issues found », toutes de niveau info : `directives_ordering` 41, `curly_braces_in_flow_control_structures` 13, `cascade_invocations` 5, autres ≤ 2. 11 dans `lib/` (ex. `players/presentation/edit_player_bottom_sheet.dart:56, 85`, `settings/presentation/settings_screen.dart:27-28, 225`), le reste dans `test/`.
  - Règles désactivées sur `very_good_analysis` (`analysis_options.yaml`) : `public_member_api_docs`, `sort_pub_dependencies`, `always_use_package_imports`, `lines_longer_than_80_chars`, `omit_local_variable_types`, `unnecessary_type_name_in_constructor` ; `prefer_relative_imports` activée.
  - `// ignore` dans `lib/` hors code généré : 11 (8 `specify_nonobvious_property_types` dans `players_provider.dart:156-184` et `sessions_provider.dart:28-117`, 1 `ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes` dans `ranking/domain/mvp_weights.dart:2`, 1 `use_setters_to_change_properties` `ranking_providers.dart:22`, 1 `avoid_setters_without_getters` `team_provider.dart:20`).
- Impact : niveau d'hygiène bon ; les `ignore` sont ciblés.
- Recommandation : `dart fix --apply` pour `directives_ordering` et `curly_braces` ; typer explicitement les 8 providers pour supprimer les `ignore`.
- Effort : XS

## 4. Hypothèses à vérifier

- Le coût de `copy.deepcopy(group.state)` et de la réécriture de l'agrégat (ARC-001) devient perceptible au-delà d'un certain nombre de documents et d'entrées `audit[]` : à mesurer avec un groupe volumineux (domaine performance).
- Le verrou global (ARC-002) cause des latences observables sur Render : à confirmer par mesure, en environnement non productif.
- Le nombre exact de fonctions > 100 lignes en Dart/JS (environ 40) dépend de l'heuristique ; un outil d'analyse de métriques Dart donnerait une valeur exacte.

## 5. Points positifs (Info)

- Domaine mobile pur : 0 import interdit dans les 30 fichiers `domain/`.
- Aucun import `application → presentation` ni `data → application/presentation`.
- Imports relatifs homogènes dans `lib/` (416, aucun `package:statoo/`), conformes à `analysis_options.yaml`.
- Graphe de fichiers Dart acyclique hormis un cycle local (ARC-012).
- `dart analyze` : 0 erreur, 0 avertissement ; `// ignore` peu nombreux et ciblés.
- Repositories avec interface abstraite + implémentation SQLite (règle `data-sqlite.md`), ce qui facilite les surcharges en test.
- Backend : modules auxiliaires petits et ciblés (`finance.py` 64 l., `security.py` 19 l., `portal.py` 30 l.).

## 6. Renvois vers d'autres domaines

- Limiteurs de tentatives en mémoire de processus (`main.py:285-288`), perdus au redémarrage : sécurité.
- Mobile ne permet pas d'éditer `sport-settings` alors que le web le permet (ARC-010) : parité web-mobile.
- Cohérence des six copies de la matrice des rôles et des trois barèmes (SQL, `StatsCalculator`, `web/summary.mjs`) : domaine A (règles métier).
- `create_all` sans migration sur Neon : données et déploiement.
- Latence induite par le verrou global : performance.

## Vérification croisée (Phase 4, 14/11/2026)

Tous les constats Critique et Majeur de ce rapport ont été relus et **confirmés** (aucun retrait, aucune requalification). Verdicts : [raw/verification-phase4.md](raw/verification-phase4.md).
