# Audit Statoo — 00. Cadrage et inventaire

Date : 14/11/2026. Branche courante : `fix/mobile-red-tests` (HEAD `2a9a3c7`, identique à `staging`), avec des modifications non commitées (voir §2). Méthode de cette phase : lecture des manifestes, du code et de la documentation, commandes git en lecture seule. **Aucune commande de test ou de build n'a encore été exécutée** : les chiffres de tests cités ci-dessous sont **déclarés**, pas vérifiés.

Convention : « [déduit] » marque une conclusion tirée d'indices, pas d'une lecture directe ; « déclaré » marque une affirmation de la documentation non revérifiée.

## 1. Écart initial avec la consigne d'audit

La consigne suppose « plusieurs applications, chacune dans son propre dépôt git ». **C'est faux** : `statoo-5v5/` est un seul dépôt git (une seule `.git` à la racine, `find . -maxdepth 3 -name .git` ne renvoie que `./.git`). Remote `origin` : `NorrisAkg/statoo-5v5`. L'audit traite donc un **monorepo à trois applications** ; les commits « dépôt par dépôt » se feront en réalité dans un seul dépôt.

## 2. État git

| Élément | Valeur |
|---|---|
| Branche courante | `fix/mobile-red-tests` |
| Dernier commit | `2a9a3c7 feat(mobile): add recovery flow from join screen [ACCESS-07]` |
| Branches locales | 15, dont `staging`, `refonte`, `backup-user-wip`, 10 `feat/*` |
| Branches distantes | `origin/main` (HEAD distant, ancienne pile Nuxt/Capacitor d'après `CLAUDE.md`), `origin/staging`, `origin/refonte`, `origin/codex/finances-et-groupe-partage`, `origin/feature/tournament-3-teams` |
| Modifiés non commités | `.gitignore`, `AGENTS.md`, `CLAUDE.md`, 2 fichiers `mobile/lib/features/sessions/presentation/`, 5 tests mobiles |
| Non suivis | `backend/CLAUDE.md`, `backend/docs/`, `docs/architecture/`, `docs/domain/`, `docs/onboarding/`, `mobile/CLAUDE.md`, `mobile/docs/`, `web/CLAUDE.md`, `web/docs/`, 3 fichiers `mobile/lib/features/ranking/` (export CSV, FEAT-01), 4 tests |

Conséquence pour l'audit : le code audité est celui de l'**arbre de travail**, pas celui de `staging`. Les différences portent sur l'export CSV (non branché) et la correction de tests rouges.

## 3. Inventaire de la racine

| Chemin | Nature | Remarque |
|---|---|---|
| `mobile/` | App Flutter (Android, iOS, Flutter web) | Référence fonctionnelle (`AGENTS.md` §1) |
| `backend/` | API FastAPI | 7 fichiers Python, 1 160 lignes, dont `main.py` 996 lignes |
| `web/` | Portail JS historique `/portal/`, tests Playwright, packaging | `web/app.mjs` 2 944 lignes ; portail « gelé depuis le 17/10 » (déclaré) |
| `scripts/` | Build et sondes | `neon_smoke.py` et `check-online-api.py` touchent Neon/production (déclaré) |
| `docs/` | 371 entrées, dont ~400 journaux `.txt` déclarés | Documentation et sorties de tests mêlées |
| `android/`, `ios/` | Artefacts générés versionnés (déclaré) | `android/local.properties` présent |
| `build/`, `.dart_tool/`, `node_modules/`, `statoo.db` | Artefacts locaux | Ignorés par `.gitignore` |
| `audits/`, `specs/`, `statoo-captures/` | Audit du 15/10, prompt agent, captures de référence (11 images) | |
| `README.md`, `reflexions.md`, `GEMINI.md`, `AGENTS.md`, `CLAUDE.md` | Documentation racine | `AGENTS.md` et `GEMINI.md` divergent (déclaré) |
| `vercel.json`, `render.yaml`, `neon.ts`, `.env.example` | Déploiement | `.env*` non lus |

## 4. Applications : stack et commandes

### 4.1 `mobile/` (Flutter)

- **Manifeste** `mobile/pubspec.yaml` : SDK Dart `^3.13.4`, `flutter_riverpod ^3.4.3`, `go_router ^18.0.1`, `freezed_annotation ^3.1.0`, `sqflite ^2.4.4`, `sqflite_common_ffi_web 1.2.0` (épinglé), `http 1.6.0` (épinglé), `flutter_secure_storage ^11.2.0`, `google_fonts ^8.2.1`, `remixicon ^4.9.3`, `share_plus`, `file_picker`, `image_picker`, `shared_preferences`, `image`. Dev : `very_good_analysis ^11.0.0`, `build_runner`, `freezed ^4.0.2`, `riverpod_generator`. `pubspec.lock` présent.
- **Taille** : 32 061 lignes Dart hors code généré ; 108 fichiers `*_test.dart`. Plus gros fichiers : `shared_group_screen.dart` 1 723, `standings_screen.dart` 1 692, `session_detail_screen.dart` 1 492, `new_session_screen.dart` 1 316.
- **SDK** : `~/development/flutter/bin/flutter`, hors PATH bash.
- **Commandes définies** (`mobile/CLAUDE.md`, `AGENTS.md`) : `flutter pub get`, `dart run build_runner build --delete-conflicting-outputs`, `dart analyze lib test`, `flutter test`, `flutter build web --release --target lib/main_web.dart --no-web-resources-cdn --dart-define=STATOO_API=<url>`.
- **Déclaré à vérifier** : `flutter test` 1358/1358 sur cette branche ; `dart analyze` 0 erreur, 71 infos.

### 4.2 `backend/` (FastAPI)

- **Manifestes** `backend/requirements.txt` : `fastapi>=0.115,<1`, `uvicorn[standard]>=0.30,<1`, `SQLAlchemy>=2.0.33,<3`, `psycopg[binary]>=3.2,<4`, `python-dotenv>=1.0,<2`. Dev : `pytest>=8,<10`, `httpx>=0.27,<1`. **Aucun lockfile**, bornes seulement.
- **Runtime** : venv `backend/.venv`, Python 3.12.3 déclaré (`backend/CLAUDE.md`) contre 3.13.5 annoncé dans `AGENTS.md`. `render.yaml` ne fixe pas de version Python.
- **Commandes** : `cd backend && .venv/bin/pytest -q` (20 fichiers dans `backend/tests/`, 442 tests déclarés, ~8 min) ; `.venv/bin/uvicorn app.main:app --reload`.
- **Configuration** : `backend/app/config.py:9-10` charge `<racine>/.env.local` puis `<racine>/.env` **sans écraser** l'environnement. Lancer `app.main:app` sans `DATABASE_URL` explicite pourrait donc viser la base configurée dans ces fichiers [déduit] ; seul `create_app("sqlite:///:memory:")` (ex. `web/tests/serve.py`) garantit l'isolement.

### 4.3 `web/` (portail JS et packaging)

- **Manifeste** racine `package.json` : `zod 4.6.7` (épinglé), `@neon/config ^1.9.1`, `@neon/env ^1.6.2` ; dev : `esbuild 0.28.2`, `playwright ^1.62.1`, `prettier ^3.9.10`. `package-lock.json` présent.
- **Runtime constaté** : `node --version` → v22.17.1 (`AGENTS.md` annonce v22.23.2) ; `npm --version` → 6.14.18 (npm de Node 14, comme signalé dans `web/CLAUDE.md`).
- **Commandes** (`package.json`) : `test:web` (`node --test web/tests/*.test.mjs`), `build:web`, `build`, `start`, `test:web:parity`, `test:web:browser`, `format:web`, `vendor:web`. Build Vercel : `bash scripts/build-universal-web.sh`.
- **Lint** : aucun linter JS ; Prettier seulement.

## 5. Fonctionnalités détectées

### 5.1 Écrans et routes Flutter (`mobile/lib/core/router/app_router.dart:85-174`)

| Route | Écran | Feature |
|---|---|---|
| `/splash` | `SplashScreen` | onboarding |
| `/onboarding` | `OnboardingScreen` | onboarding |
| `/bienvenue` | `GroupEntryScreen` (entrée groupe, récupération ACCESS-07) | onboarding |
| `/creer-equipe`, `/ajouter-joueurs-initiaux` | `CreateTeamScreen`, `AddTeamPlayersScreen` | team |
| `/` (onglet) | `HomeScreen` | home |
| `/seances`, `/seances/nouvelle`, `/seances/:id` | `SessionsScreen`, `NewSessionScreen`, `SessionDetailScreen` | sessions |
| `/seances/:id/finances` | `FinancialPointScreen` | finance |
| `/joueurs`, `/joueurs/:id` | `PlayersScreen`, `PlayerDetailScreen` | players |
| `/classement` | `StandingsScreen` | ranking |
| `/stats` | `StatsScreen` | stats |
| `/finances` | `FinancesScreen` | finance |
| `/groupe-partage` (`?creation=1`, `?installation=1`) | `SharedGroupScreen` | shared |
| `/reglages` | `SettingsScreen` (sauvegarde/restauration) | settings |

Bottom sheets : nouveau/édition joueur, discipline joueur, retardataires, règles MVP, changement d'équipe, ajout de gestionnaire, demande et confirmation de récupération.

### 5.2 Endpoints API (`backend/app/main.py`)

| Ligne | Méthode et chemin |
|---|---|
| 268, 275 | `GET /portal/config.json`, montage statique `/portal` |
| 345 | `GET /health` |
| 349 | `POST /groups` (création d'un groupe partagé) |
| 421, 437, 443 | `POST /auth/login`, `/auth/logout`, `/auth/recover` |
| 506 | `GET /groups/{group_id}` |
| 537 | `POST /groups/{g}/accounts` |
| 568, 577 | `POST /groups/{g}/accounts/{a}/password/verify`, `…/password` |
| 590, 612 | `POST /groups/{g}/account/password`, `PUT /groups/{g}/account/recovery-code` |
| 632, 658 | `PUT …/accounts/{a}/roles`, `PUT …/members` |
| 675, 686 | `POST …/shared-access/verify`, `PUT …/shared-access` |
| 702, 711 | `PUT …/financial-settings`, `PUT …/sport-settings` |
| 720, 738 | `POST …/opening`, `…/opening/approve` |
| 752 | `POST …/sync` |
| 827, 860 | `POST …/documents/{domain}/{occurrence_id}/resolve`, `…/transfer` |

Toutes les routes sont des closures dans `create_app`. Pas de routeur séparé, pas de versioning.

### 5.3 Tâches de fond et intégrations

- **Synchronisation** : `Timer.periodic(Duration(seconds: 45))` dans `mobile/lib/features/shared/data/shared_service.dart:243` (outbox vers `/sync`).
- **Service worker** : `web/sw.js` (portail) ; shell PWA Flutter `mobile/web/app-shell.js`, SQLite WASM (`mobile/web/sqflite_sw.js`, `sqlite3.wasm`).
- **Aucun job serveur** (pas de cron, pas de file) [déduit de l'absence de planificateur dans `backend/app/`].
- **Intégrations** : Neon PostgreSQL (`DATABASE_URL`, `DATABASE_URL_UNPOOLED`), Render (`render.yaml`), Vercel (`vercel.json`), stockage sécurisé natif (`flutter_secure_storage`), partage et sélection de fichiers (`share_plus`, `file_picker`, `image_picker`), polices `google_fonts`.
- **Variables d'environnement référencées (noms seulement)** : `DATABASE_URL`, `DATABASE_URL_UNPOOLED`, `CORS_ORIGINS`, `STATOO_PUBLIC_API_URL`, `RENDER`, `RENDER_GIT_BRANCH`, `STATOO_API` (dart-define).
- **Point d'attention** : `STATOO_API` vaut par défaut `https://statoo-api.onrender.com` dans `scripts/build-universal-web.sh:17` et dans le code Flutter (`shared_group_screen.dart:57`, `recovery_request_sheet.dart:110`).

## 6. Documentation existante : déclaré vs à vérifier

| Source | Affirmation | Statut |
|---|---|---|
| `CLAUDE.md`, `AGENTS.md` | Tests : mobile 1358/1358, backend 442, web 61 | À exécuter (Phase 2, domaine I) |
| `AGENTS.md` | Node 22.23.2, Python 3.13.5 | **Contredit** : Node 22.17.1 constaté ; Python 3.12.3 déclaré pour le venv |
| `AGENTS.md` §5 | Clôture bloquante (score absent, doublon, déséquilibre > 1) | À vérifier dans le code (domaine A) |
| `docs/onboarding/etat-des-lieux.md` | Verrou global, agrégat JSON, pas de rate limit, bug `resolve`/`obligations` | À revérifier (domaines E, F, G) |
| `docs/architecture/vue-densemble.md` | Matrice endpoints × clients, fonctions ACCESS sans client | À revérifier (domaines A, B) |
| `docs/business-rules.md`, `docs/architecture.md`, `docs/decisions-and-risks.md`, `docs/ai/DIAGNOSTIC.md` | Datés du 12/10, partiellement obsolètes (déclaré) | Lus seulement pour confronter au code |
| `docs/design-system.md` | Poppins, `context.colors`, clair/sombre, 320/393 dp | Référence du domaine C |
| Audits antérieurs | `audits/AUDIT-2026-10-15-2019.md`, `docs/audit-2026-10-25/`, `docs/audit-ui-ux-2026-10-14/`, `docs/audit_reports/` | À utiliser pour suivre les constats déjà connus |

Note : une partie des documents d'onboarding (`docs/onboarding/`, `docs/architecture/`, `*/docs/architecture/analyse.md`, les `CLAUDE.md` d'applications) a été produite le jour même et n'est pas commitée. Ils sont traités comme des sources à vérifier, pas comme des preuves.

## 7. Outillage local disponible

| Outil | Disponible | Usage dans l'audit |
|---|---|---|
| Flutter / Dart | Oui (`~/development/flutter/bin`) | tests, analyse, build web |
| pytest (venv) | Oui | tests backend |
| Node 22, Playwright, Prettier | Oui | tests web, parcours navigateur |
| npm audit | Oui (npm 6) | interroge le registre npm : réseau externe |
| pip-audit | **Absent** | installation dans le venv à autoriser |
| axe, pa11y, Lighthouse | **Absents** | accessibilité et performance en statique, sauf accord |

## 8. Périmètre et hypothèses

- **Dans le périmètre** : `mobile/`, `backend/`, `web/`, `scripts/`, fichiers de déploiement, `docs/`.
- **Hors périmètre** : `android/` et `ios/` racine (artefacts, seulement signalés), `node_modules/`, `build/`, contenu des `.env*`, configuration réelle de Render, Vercel et Neon (non visible depuis le dépôt).
- **Hypothèses** :
  1. L'application Flutter est la cible principale sur tous les supports ; le portail `web/` est secondaire mais toujours servi.
  2. Aucune CI n'existe (aucun fichier `.github/workflows`, `.gitlab-ci.yml` ou équivalent à confirmer en domaine J).
  3. Les environnements de production ne sont pas accessibles et ne doivent pas l'être.
