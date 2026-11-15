# Audit Statoo — 09. Tests et qualité d'ingénierie

- **Domaine** : couverture, pyramide de tests, qualité des tests, parité inter-implémentations, zones critiques sans test, lint et typage, écart documentation ↔ réalité, temps d'exécution.
- **Date** : 14/11/2026. Arbre de travail de `fix/mobile-red-tests` (HEAD `2a9a3c7` + modifications non commitées).
- **Méthode** : statique (lecture des tests et du code), journaux déjà produits dans `docs/audit/raw/` (`flutter-test.log`, `dart-analyze.log`, `pytest.log`, `test-web.log`, `build-web.log`, `prettier.log`), et commandes ciblées courtes : `pytest --co -q`, `dart format --output=none --set-exit-if-changed lib test` (aucune écriture), chronométrage d'un PBKDF2, `pytest tests/test_api.py tests/test_session_lock.py --durations=12` (34 tests, SQLite en mémoire).
- **Limites** : aucune mesure de couverture (aucun outil installé, rien n'a été installé) ; les e2e Playwright n'ont pas été lancés (serveurs manuels, certains peuvent viser la production) ; la qualité de chaque test n'a pas été relue un par un (échantillonnage sur les zones à risque).

## Synthèse

Le volume de tests est élevé et, sur cette branche, tout est vert : 1358 tests Flutter (`flutter-test.log` : « 04:13 +1358: All tests passed! »), 442 tests backend (`pytest.log` : « 442 passed in 650.22s (0:10:50) »), 61 tests unitaires web (`test-web.log`). Les tests sont majoritairement comportementaux (SQLite en mémoire via `sqflite_common_ffi`, `TestClient` FastAPI réel, aucun framework de mock), avec de bons tests de migration, d'atomicité de restauration et de validation d'API.

Mais la confiance est plus faible que les chiffres : **aucune mesure de couverture** n'existe ; **aucune CI** n'exécute ces suites (renvoi OPS-001), et `staging` porte 16 tests mobiles rouges (déclaré) ; plusieurs **chemins critiques du contrôleur de séances ne sont jamais exécutés** (suppression de séance, garde « séance déjà active » à la création) ; les migrations SQLite ne sont testées qu'à partir de v6 ; la **parité entre les trois copies des règles** (Dart, Python, JS) ne repose que sur une fixture sport unique, ce qui laisse passer les divergences relevées par le domaine métier ; plusieurs défauts de sécurité confirmés (SEC-004 à SEC-006) n'ont aucun test négatif. La suite backend coûte ~11 min parce que chaque fixture hache une dizaine de mots de passe PBKDF2 à 600 000 itérations. Lint : `very_good_analysis` côté Dart (bon), mais 125 fichiers Dart non formatés et ni linter ni typage côté JS et Python. La documentation des chiffres de tests est fausse dans les fichiers commités.

**Note proposée : 3/5.** Base de tests large, réelle et plutôt bien écrite (au-dessus de la moyenne d'un projet de cette taille), pénalisée par l'absence de couverture mesurée et de CI, des trous sur des chemins destructifs et sur la parité, et une suite backend lente qui décourage l'exécution complète.

## Tableau récapitulatif

| ID | Sévérité | Titre | Fichier principal | Effort |
|---|---|---|---|---|
| TST-001 | Majeur | Aucune exécution automatique des tests ; `staging` porte des tests rouges | `CLAUDE.md` (racine) | S |
| TST-002 | Mineur (requalifié, était Majeur) | Aucune mesure de couverture, sur aucune des trois applications | `backend/requirements.txt`, `mobile/pubspec.yaml` | S |
| TST-003 | Majeur | Suppression de séance (`deleteSession` → `cancelSport`) jamais testée | `mobile/lib/features/sessions/application/sessions_provider.dart:769` | S |
| TST-004 | Majeur | Parité des trois copies des règles limitée à une fixture sport unique | `web/tests/fixtures/mobile-snapshot.json` | M |
| TST-005 | Mineur (requalifié, était Majeur) | Défauts de sécurité confirmés sans test négatif (cumul de rôles, prise de contrôle, oracles, throttling du login) | `backend/tests/` | M |
| TST-006 | Mineur | Garde « séance déjà active » du contrôleur jamais exécutée par un test | `mobile/lib/features/sessions/application/sessions_provider.dart:263-271` | XS |
| TST-007 | Mineur | Migrations SQLite testées seulement depuis v6 et v7 (v1 à v5 absentes) | `mobile/test/core/data/database_migration_test.dart:150` | S |
| TST-008 | Mineur | Isolation multi-tenant backend testée contre un groupe inexistant seulement | `backend/tests/test_api.py:57-63` | S |
| TST-009 | Mineur | Suite backend de 11 min : PBKDF2 600 000 itérations dans chaque fixture | `backend/app/security.py:8` | S |
| TST-010 | Mineur | Dix e2e sans script npm, dont les e2e Flutter ; quatre peuvent écrire en production | `package.json:9-10` | S |
| TST-011 | Mineur | Des tests figent des comportements jugés défectueux par d'autres domaines | `mobile/test/features/sessions/session_close_test.dart:414` | S |
| TST-012 | Mineur | Tests web qui assertent le texte source de `app.mjs` | `web/tests/config.test.mjs:4-14` | XS |
| TST-013 | Mineur | Formatage non appliqué : 125 fichiers Dart et 14 fichiers JS non conformes | `docs/audit/raw/prettier.log` | XS |
| TST-014 | Mineur | Ni linter ni typage statique pour JavaScript et Python | `package.json`, `backend/` | M |
| TST-015 | Mineur | Chiffres de tests faux dans la documentation commitée | `AGENTS.md` (commité), `docs/ai/DIAGNOSTIC.md:12-15` | XS |
| TST-016 | Mineur | Consigne TDD d'`AGENTS.md` non vérifiable sur les dernières livraisons | `AGENTS.md` §1 | S |
| TST-017 | Info | Aucun test golden ni d'intégration Flutter (`integration_test/`) | `mobile/test/` | M |
| TST-018 | Info | Analyse statique Dart : 71 infos, dont 60 dans `test/` | `docs/audit/raw/dart-analyze.log` | XS |

---

### TST-001 — Aucune exécution automatique des tests ; `staging` porte des tests rouges
- Sévérité : Majeur / Domaine : tests, processus / Statut : confirmé (absence de CI) ; échecs sur `staging` déclarés
- Preuve :
  - `ls .github` → « No such file or directory » ; `.git/hooks` ne contient que des `*.sample` ; `CLAUDE.md` racine : « Il n'y a aucune CI. »
  - Seuls les 61 tests unitaires web sont exécutés au build (`package.json:8`, `build-web.log` : « PWA tests passed and static portal packaged. ») ; ni `flutter test` ni `pytest` ne conditionnent un déploiement (détail dans OPS-001).
  - `CLAUDE.md` racine et `mobile/CLAUDE.md:15` déclarent `staging` (`2a9a3c7`) à 1333 OK / 16 KO ; la branche `fix/mobile-red-tests` corrige ces échecs par des modifications non commitées (`git diff HEAD --stat -- mobile/` : 7 fichiers, dont 5 tests). Non revérifié sur `staging` (pas de `checkout` autorisé).
- Impact : la branche qui alimente la production a reçu des commits avec une suite mobile rouge, malgré la consigne « Commit uniquement après validation » (`AGENTS.md` §1). Une régression peut atteindre les utilisateurs sans être vue.
- Recommandation : une CI minimale (GitHub Actions) sur `staging` et les PR : `dart analyze`, `flutter test`, `pytest`, `npm run test:web`, `prettier --check`. Bloquer la fusion en cas d'échec. Voir OPS-001 pour le déploiement.
- Effort : S

### TST-002 — Aucune mesure de couverture, sur aucune des trois applications
- Sévérité : Mineur (requalifié en Phase 4, était Majeur) / Domaine : tests / Statut : confirmé
- Preuve : `find . -path ./node_modules -prune -o \( -name coverage -o -name lcov.info -o -name .coverage -o -name htmlcov -o -name "coverage*.xml" \) -print` → aucun résultat. `backend/.venv/bin/pip list` : `pytest 9.1.1`, ni `pytest-cov` ni `coverage`. Aucun script npm de couverture (`package.json:5-12`, pas de `--experimental-test-coverage`). Aucune mention de `flutter test --coverage` dans les `CLAUDE.md`.
- Impact : impossible de savoir quelles branches du code sont exécutées ; les trous trouvés ci-dessous (TST-003, TST-006, TST-007) l'ont été par lecture, au hasard. Le chiffre « 1358 tests » ne dit rien de la couverture des zones à risque listées dans `AGENTS.md` §6.
- Recommandation : `flutter test --coverage` (lcov) ; `pytest-cov` en dépendance de dev ; `node --test --experimental-test-coverage` pour le web. Publier le rapport en CI, sans seuil au départ, puis fixer un plancher sur `sessions/`, `finance/`, `app_database.dart` et `backend/app/main.py`.
- Effort : S

### TST-003 — Suppression de séance (`deleteSession` → `cancelSport`) jamais testée
- Sévérité : Majeur / Domaine : tests, sessions / Statut : confirmé
- Preuve :
  - `mobile/lib/features/sessions/application/sessions_provider.dart:769-776` : `deleteSession` appelle `requireWrite` puis `SharedService.cancelSport`. `mobile/lib/features/shared/data/shared_service.dart:465` : `cancelSport` supprime en transaction séance, alias et occurrence financière.
  - `grep -rln "cancelSport\|deleteSession" mobile/test` → seul `session_detail_kebab_menu_test.dart`, qui ne vérifie que l'absence ou la présence de libellés « Supprimer » (l. 228-263, 335) ; il n'appelle jamais la méthode.
  - Comptage des appels de méthodes du contrôleur dans `mobile/test` : `deleteSession 0`, `updateScore 0`, `startSession 1`, `reopenSession 1`.
- Impact : un chemin destructif, appelé depuis l'écran (`session_detail_screen.dart:1387`), sans aucun filet. Le domaine métier relève justement un bug sur ce chemin (MET-001 : la suppression laisse une cotisation due) ; aucun test ne l'aurait détecté.
- Recommandation : tests sur SQLite en mémoire avec `SharedService` réel : suppression d'un brouillon, d'une séance close, d'une séance avec point financier, d'une séance d'un autre groupe (refus), groupe partagé sans droit `sport` (refus), vérification de `meta` et des obligations après suppression.
- Effort : S

### TST-004 — Parité des trois copies des règles limitée à une fixture sport unique
- Sévérité : Majeur / Domaine : tests, parité / Statut : confirmé
- Preuve :
  - `CLAUDE.md` racine : les règles sport, finance et rôles existent en trois copies (`mobile/lib/features/sessions/domain/`, `backend/app/main.py`, `web/domain.mjs`).
  - Le seul artefact partagé est `web/tests/fixtures/mobile-snapshot.json` (une séance `TOURNAMENT_3`, trois membres), généré par `web/tests/export-mobile-fixture.mjs`, dernier commit `4266cda` du 16/10/2026. Il est lu par `mobile/test/features/shared/pwa_wire_import_test.dart:36`, `backend/tests/test_sport_validation.py:253` et `web/tests/domain.test.mjs:261-273`.
  - Aucun jeu de vecteurs partagé pour la finance (totaux, reliquat, validations), la matrice des rôles ou le classement. Les divergences établies par le domaine métier (MET-003 cohérence buts/score, MET-007 validation financière, MET-012 totaux, MET-016 règles sport secondaires) coexistent avec des suites vertes dans les trois applications.
  - Les e2e `parity-contract` et `parity-shared` (`package.json:9`) exigent des serveurs lancés à la main et ne sont exécutés nulle part automatiquement.
- Impact : la règle « toute modification doit aligner les trois et passer les tests de parité » n'est pas outillée ; une divergence de calcul financier entre mobile et serveur passe inaperçue.
- Recommandation : un répertoire de vecteurs JSON partagés (`entrée → sortie attendue`) pour chaque règle dupliquée (validation de point financier, totaux, droits par rôle et par domaine, cohérence buts/score), consommé par un test dans chacune des trois suites. À terme, réduire le nombre de copies (renvoi ARC-004).
- Effort : M

### TST-005 — Défauts de sécurité confirmés sans test négatif
- Sévérité : Mineur (requalifié en Phase 4, était Majeur) / Domaine : tests, sécurité / Statut : confirmé
- Preuve :
  - Limitation de `/auth/login` : `backend/app/main.py:420-428` (20 essais par minute et par IP). `grep -n "429" backend/tests/*.py` → seulement `test_recovery_code.py:245` et `test_change_password.py:168` ; aucun test ne vérifie le 429 du login, ni le comportement derrière un proxy (SEC-002).
  - SEC-005 (oracles de mot de passe sans throttling), SEC-006 (un compte cumule TR et PDT et approuve ses propres soldes), SEC-004 (prise de contrôle par un co-admin sans ré-authentification) : aucun test n'en exprime le comportement attendu ; `test_opening_review.py` (10 cas) teste les refus par rôle, pas le cumul.
  - Le seul test de concurrence backend (`backend/tests/test_session_lock.py:5-16`) vérifie la libération du verrou en appelant la dépendance interne `db` ; aucun test d'écritures `/sync` concurrentes sur le même groupe.
- Impact : les failles relevées par le domaine sécurité ne seraient pas détectées si elles réapparaissaient après correction ; la sécurité repose sur la lecture.
- Recommandation : pour chaque correction SEC-00x, un test rouge préalable (TDD d'`AGENTS.md`) : 429 sur login après 20 essais, refus du cumul TR+PDT ou de l'auto-approbation, throttling des endpoints `verify`, test de deux `/sync` concurrentes avec la même `base_revision`.
- Effort : M

### TST-006 — Garde « séance déjà active » du contrôleur jamais exécutée par un test
- Sévérité : Mineur / Domaine : tests, sessions / Statut : confirmé
- Preuve : `sessions_provider.dart:263-271` : si une séance est déjà active, `createDraftSession(startImmediately: true)` enregistre la séance sans l'activer, silencieusement. `new_session_active_draft_guard_test.dart:40-58` remplace le contrôleur par `_RecordingController extends SessionsController` qui ne fait qu'enregistrer `startImmediately` ; les appels réels à `createDraftSession` (`session_close_test.dart:420`, `tournament_3_teams_test.dart:288`, `team_appearance_test.dart:97`) n'ont jamais de séance active. `docs/onboarding/questions-ouvertes.md:20` signalait déjà ce trou.
- Impact : seule la garde d'écran est testée. Si l'écran envoie `true` alors que `activeDraftSessionProvider` charge encore, le comportement du contrôleur (pas d'activation, pas de `queueSport`, pas de message) n'est pas spécifié.
- Recommandation : un test sur le vrai contrôleur et SQLite en mémoire : séance active existante + `startImmediately: true` → séance créée en brouillon, séance active inchangée, aucun événement d'outbox sport ; décider si l'appelant doit être prévenu.
- Effort : XS

### TST-007 — Migrations SQLite testées seulement depuis v6 et v7
- Sévérité : Mineur / Domaine : tests, données / Statut : confirmé
- Preuve : `mobile/test/fixtures/migrations/` ne contient que `v6.json` et `v7.json` ; `database_migration_test.dart:150` charge `v$version.json`, appelé avec 6 (défaut) ou 7 (l. 337). `app_database.dart:62` déclare `version: 8` et `onUpgrade` contient des étapes `oldVersion < 4` (ajout de `sessions.team_id`, l. 80-91) et `oldVersion < 5` (séances closes sans score renvoyées en brouillon, l. 92-99), qu'aucun test ne parcourt sur un schéma historique. Les autres `version: 1/2/5` trouvés dans `test/` sont des versions de sauvegarde ou des bases neuves (`goal_score_sync_test.dart:76` + `initSchemaForTest`).
- Impact : un appareil resté sur une version ≤ 5 suit un chemin de migration jamais exécuté ; le domaine données relève d'ailleurs une divergence de schéma entre base neuve et base migrée (DAT-008) et un blocage au démarrage si la migration échoue (DAT-006).
- Recommandation : extraire les schémas v1 à v5 des commits historiques (même procédure que `fixtures/migrations/README.md`) et ajouter un test par version de départ, avec comparaison du schéma final à celui d'une base neuve.
- Effort : S

### TST-008 — Isolation multi-tenant backend testée contre un groupe inexistant seulement
- Sévérité : Mineur / Domaine : tests, multi-tenant / Statut : confirmé
- Preuve : `backend/tests/test_api.py:57-63` vérifie `GET /groups/other` → 403 avec un jeton du groupe `#00000001` ; même motif dans `test_collective_access.py:51`, `test_manager_access.py:50`, `test_change_password.py:98` (`other`, `other-group`). Aucun test ne crée deux groupes réels pour utiliser le jeton de A sur B, ni ne cible un `account_id` de B depuis `/groups/A/accounts/{id}`. La protection repose sur `scoped()` (`backend/app/main.py:315-319`), qui compare `group.id` à l'URL.
- Impact : le code actuel est correct par construction [déduit de `scoped()`], mais un futur endpoint qui oublierait `scoped` ou chercherait une ressource par identifiant global ne serait pas détecté. Côté mobile, l'isolation par `team_id` est mieux couverte (`test/features/team/tenant_isolation_test.dart`, 11 cas ; `ranking/multi_tenant_isolation_and_archived_players_test.dart`).
- Recommandation : une fixture à deux groupes et un test paramétré sur toutes les routes `/groups/{id}/…` (lecture et écriture) avec le jeton de l'autre groupe, y compris avec des identifiants de comptes et d'occurrences du groupe cible.
- Effort : S

### TST-009 — Suite backend de 11 min : PBKDF2 600 000 itérations dans chaque fixture
- Sévérité : Mineur / Domaine : tests, productivité / Statut : confirmé
- Preuve :
  - `pytest.log` : « 442 passed in 650.22s (0:10:50) », soit ~1,5 s par test.
  - `backend/app/security.py:8` et `:14` : `pbkdf2_hmac("sha256", …, 600_000)` codé en dur ; aucun `conftest.py`, aucun `monkeypatch` des itérations (`grep -n "monkeypatch" backend/tests/*.py` : uniquement `secrets.randbelow`, variables d'environnement et `validate_sport`).
  - Chronométrage local : `pbkdf2_hmac('sha256', …, 600_000)` → 0,82 s par appel.
  - La fixture `system` de `test_api.py:9-35` (portée fonction, 33 tests) crée un groupe (3 hachages + 1 empreinte d'opération possible, `main.py:386-411`), quatre comptes (4 hachages) et cinq connexions (5 vérifications) : ~12 dérivations, soit ~6 à 10 s par test avant toute assertion (confirmé par la mesure ci-dessous). Les fixtures de `test_sport_validation.py:13` et `test_portal_exposure.py:33` sont en portée `module`, ce qui explique que leurs 244 cas soient rapides.
  - Mesure ciblée (`pytest tests/test_api.py tests/test_session_lock.py -q --durations=12`) : « 34 passed in 176.37s (0:02:56) » ; les 12 durées les plus longues sont toutes des phases **setup** de la fixture `system`, de 6,03 s à 9,67 s (ex. « 9.67s setup tests/test_api.py::test_invalid_responsibility_remains_rejected[roles1] »). `test_api.py` seul représente ~27 % du temps total de la suite pour 7 % des cas.
- Impact : 11 min pour la suite backend décourage l'exécution complète avant commit, contraire au TDD exigé ; c'est aussi la contrainte principale d'une future CI. Les docs annoncent « ~8 min » (`backend/CLAUDE.md:13`).
- Recommandation : rendre le nombre d'itérations paramétrable (`create_app(…, kdf_iterations=…)` ou variable lue au démarrage) et le réduire à 1 000 dans un `conftest.py` ; garder un test qui vérifie la valeur de production. Passer les fixtures en lecture seule en portée `module`, ou ajouter `pytest-xdist`.
- Effort : S

### TST-010 — Dix e2e sans script npm, dont les e2e Flutter ; quatre peuvent écrire en production
- Sévérité : Mineur / Domaine : tests, e2e / Statut : confirmé (scripts) ; [déduit] (cible production)
- Preuve :
  - `web/tests/` compte 24 fichiers `*.e2e.mjs`. `package.json:9-10` n'en référence que 13 (`test:web:parity`, `test:web:browser`). Sans script : `accessible-commands-flutter`, `collective-access`, `group-entry`, `ios-input-focus`, `live-integration`, `manager-access`, `portable-photos-flutter`, `responsive-flutter`, `startup-group-flutter`, `universal-pwa`, ainsi que `web/tests/audit/client.audit.mjs`.
  - Les e2e qui ciblent **Flutter web**, la cible principale, sont presque tous dans cette liste ; ceux qui ont un script testent surtout le portail gelé.
  - `live-integration.e2e.mjs:5` (port 19095), `group-entry.e2e.mjs:6`, `collective-access.e2e.mjs:6-7`, `manager-access.e2e.mjs:6-7` pointent vers un build Flutter servi à la main, dont l'API est figée à la compilation ; sans `--dart-define=STATOO_API`, Flutter vise la production (`CLAUDE.md` racine). `group-entry.e2e.mjs:37` intercepte `**/groups/*` sur n'importe quel hôte, sans vérifier qu'il est local. `web/CLAUDE.md` interdit de les lancer sans vérifier l'API.
  - Ces tests écrivent des captures dans le dépôt (`group-entry.e2e.mjs:56` : `docs/group-entry-captures/…`), ce qui alimente OPS-016.
- Impact : la parité Flutter web n'est vérifiée par aucune commande documentée ; un développeur peut créer des groupes de test en production.
- Recommandation : un script `test:web:flutter` qui construit Flutter web avec `--dart-define=STATOO_API=http://127.0.0.1:…`, lance `serve.py` et refuse de démarrer si l'API n'est pas locale (assertion sur `page.on('request')`) ; écrire les captures hors du dépôt.
- Effort : S

### TST-011 — Des tests figent des comportements jugés défectueux par d'autres domaines
- Sévérité : Mineur / Domaine : tests, métier / Statut : confirmé
- Preuve :
  - `session_close_test.dart:414-431` (« initializes new session score to 0 - 0 with draw result ») et `:447-457` exigent que création et démarrage initialisent le score à 0-0/`DRAW` (`sessions_provider.dart:233`, `:296`). Le domaine métier (MET-010) montre que ce choix rend inopérant le bloqueur « score absent » de la clôture (`AGENTS.md` §5).
  - `test/startup/active_group_test.dart:200-214` valide la recréation d'un groupe depuis les SharedPreferences héritées, que DAT-010 identifie comme une résurrection possible après suppression.
- Impact : ces tests transforment des défauts en spécification ; la correction exigera de les réécrire, avec le risque de les « faire passer » plutôt que de trancher la règle.
- Recommandation : à la correction de MET-010 et DAT-010, réécrire ces tests à partir de la règle du CDC et l'indiquer dans le message de commit ; marquer dans `docs/business-rules.md` la règle tranchée.
- Effort : S

### TST-012 — Tests web qui assertent le texte source de `app.mjs`
- Sévérité : Mineur / Domaine : tests, qualité / Statut : confirmé
- Preuve : `web/tests/config.test.mjs:4-14` lit `../app.mjs` et vérifie `source.includes("Adresse de l’API") === false` et `assert.match(source, /apiAddress/)` ; `web/tests/offline-registration.test.mjs:5-9` vérifie la présence du mot `RegistrationDraft`. Le commentaire `config.test.mjs:10` explique que c'est pour obtenir un RED non lié à un module manquant.
- Impact : tests fragiles et peu probants (un renommage casse le test, un code mort contenant le mot le fait passer). Faible portée : le portail est gelé.
- Recommandation : remplacer par des assertions de comportement (import du module et appel), ou supprimer ces lignes puisque les assertions suivantes testent déjà le comportement.
- Effort : XS

### TST-013 — Formatage non appliqué : 125 fichiers Dart et 14 fichiers JS non conformes
- Sévérité : Mineur / Domaine : qualité / Statut : confirmé
- Preuve : `dart format --output=none --set-exit-if-changed lib test` → « Formatted 245 files (125 changed) », dont 65 dans `lib/` et 60 dans `test/` (aucun fichier généré). `docs/audit/raw/prettier.log` : « Code style issues found in 14 files », dont `web/app.mjs` et 11 fichiers de test. `docs/ai/DIAGNOSTIC.md:13` affirme pourtant « Prettier configuré, 0 erreur ».
- Impact : diffs bruyants, revues plus difficiles ; un formatage global ultérieur produira un énorme commit sans valeur.
- Recommandation : un commit de formatage unique et isolé (`dart format lib test`, `npm run format:web`), puis vérification en CI (`--set-exit-if-changed`, `prettier --check`).
- Effort : XS

### TST-014 — Ni linter ni typage statique pour JavaScript et Python
- Sévérité : Mineur / Domaine : qualité / Statut : confirmé
- Preuve :
  - JS : aucun fichier `eslint*`, `tsconfig*`, `jsconfig*` à la racine ; aucun `// @ts-check` dans `web/*.mjs` ; `grep -c "@param\|@returns"` → 0 dans `web/app.mjs` (2 944 lignes) et `web/domain.mjs`. Seul Prettier est configuré (`package.json:11`). Zod valide à l'exécution.
  - Python : aucun `pyproject.toml`, `setup.cfg`, `ruff`, `mypy` ou `flake8` dans le dépôt ou le venv. `backend/app/main.py` : 2 fonctions sur 54 ont une annotation de retour (`grep -cE "def [a-z_]+\([^)]*\)\s*->"`) ; les paramètres des routes sont typés via Pydantic, l'agrégat `group.state` est un `dict` libre.
  - Dart, à l'inverse, est bien outillé : `mobile/analysis_options.yaml:1` inclut `very_good_analysis` et ne désactive que 7 règles de style (`public_member_api_docs`, `lines_longer_than_80_chars`, etc.), aucune règle de sûreté.
- Impact : les copies JS et Python des règles métier (TST-004) n'ont aucune vérification statique ; les erreurs de clé dans `state` (dictionnaires) ne sont détectées qu'en test.
- Recommandation : `ruff` (lint + format) et `mypy` en mode progressif sur `backend/app` ; `// @ts-check` + `tsc --noEmit --allowJs` ou ESLint sur `web/domain.mjs`, `summary.mjs`, `client.mjs` (le reste du portail est gelé).
- Effort : M

### TST-015 — Chiffres de tests faux dans la documentation commitée
- Sévérité : Mineur / Domaine : documentation / Statut : confirmé
- Preuve :
  - `git show staging:AGENTS.md` l. 19 : « 836 tests unitaires & widgets » ; l. 28 : « 89 tests API ». Mesuré : 1358 et 442. La correction n'existe que dans l'arbre de travail (`git diff AGENTS.md`), non commitée.
  - `docs/ai/DIAGNOSTIC.md:12-15` : « 836 / 836 », « 406 / 406 », « 1 303 / 1 303 », « Baseline de tests 100% verte » ; l. 19 : « Aucun test en échec » alors que `staging` a 16 échecs (déclaré, TST-001).
  - La doc d'onboarding du 14/11 n'est pas cohérente avec elle-même : `docs/onboarding/etat-des-lieux.md:17` donne « 1351/1351 » sur cette branche et l. 26 « 1349 tests », contre 1358 mesurés ; « ≈ 8 min » pour pytest (l. 18, `backend/CLAUDE.md:13`) contre 10 min 50 s mesurées.
- Impact : la doc sert de preuve de qualité aux agents et aux revues ; elle surestime la qualité réelle.
- Recommandation : commiter les corrections d'`AGENTS.md` et `CLAUDE.md` ; marquer `DIAGNOSTIC.md` comme historique ; une fois la CI en place, ne plus écrire de chiffres de tests à la main (lien vers le dernier run).
- Effort : XS

### TST-016 — Consigne TDD d'`AGENTS.md` non vérifiable sur les dernières livraisons
- Sévérité : Mineur / Domaine : processus / Statut : confirmé (absence de preuve) ; [déduit] (pratique réelle)
- Preuve :
  - `AGENTS.md` §1 impose un cycle rouge → vert → refactor avec tous les scénarios écrits avant le code.
  - `docs/` contient 401 fichiers `.txt` suivis (`git ls-files 'docs/*.txt' | wc -l`), dont 112 avec « red/rouge » et 80 avec « green/vert » dans le nom (ex. `docs/collective-access-red.txt`, `docs/manager-access-backend-green.txt`) : la pratique a existé jusqu'au 30/10 (dernier commit touchant `docs/*.txt`).
  - Les livraisons ACCESS-01, 02, 03 et 07 du 31/10 (`5e86c25`, `25f7962`, `28fc6f7`, `2a9a3c7`) n'ont aucun journal RED associé (`find docs -name "*.txt" | grep -iE "recover|co-admin|password"` → rien) ; tests et code arrivent dans les mêmes commits (`git show --stat 2a9a3c7` : +940 lignes dans `recovery_controller_test.dart`, etc.). L'ordre RED/GREEN n'est donc pas démontrable.
  - Le domaine métier (MET-005) montre que le code de secours livré par ACCESS-07 n'est créé par aucun client, malgré 4 000+ lignes de tests ajoutées : les tests vérifient les composants, pas le parcours de bout en bout.
- Impact : la consigne la plus coûteuse du projet n'est pas auditable, et les journaux `.txt` encombrent `docs/` (OPS-016) sans remplir ce rôle.
- Recommandation : remplacer les journaux `.txt` par une preuve légère et vérifiable : commit de test rouge séparé (`test(scope): … [ID]`) avant le commit de code, visible dans `git log` ; un test d'acceptation de bout en bout par lot (ex. ACCESS-07 : création du groupe → code de secours → récupération).
- Effort : S

### TST-017 — Aucun test golden ni d'intégration Flutter
- Sévérité : Info / Domaine : tests / Statut : confirmé
- Preuve : `grep -rl "matchesGoldenFile" mobile/test` → 0 ; aucun dossier `mobile/integration_test` ; aucune dépendance `integration_test` dans `mobile/pubspec.yaml`. La pyramide mobile : 108 fichiers, 455 `test(` et 285 `testWidgets(` (avant paramétrage), aucun niveau intégration sur appareil. Les parcours de bout en bout ne sont couverts que par les e2e Playwright sur Flutter web (TST-010), non scriptés.
- Impact : la fidélité visuelle (thèmes clair/sombre, 320/393 dp exigés par `AGENTS.md` §1) repose sur des tests de layout (`test/design/*`) et sur l'agent `design-fidelity` ; Android et iOS ne sont jamais testés sur appareil ou émulateur.
- Recommandation : quelques goldens ciblés (écran de séance en direct, classement, point financier) en clair/sombre et 320 dp ; un `integration_test` du parcours principal (créer un groupe → séance → clôture → classement) exécuté sur émulateur.
- Effort : M

### TST-018 — Analyse statique Dart : 71 infos, dont 60 dans `test/`
- Sévérité : Info / Domaine : qualité / Statut : confirmé
- Preuve : `docs/audit/raw/dart-analyze.log` : « 71 issues found », exit 0, aucune erreur ni avertissement. Répartition : `directives_ordering` 41, `curly_braces_in_flow_control_structures` 13, `cascade_invocations` 5, divers 12 ; 11 dans `lib/`, 60 dans `test/`. 11 `// ignore:` dans `lib/` hors code généré (déjà noté en ARC-016), 2 dans `test/`, 1 `ignore_for_file` (`lib/features/ranking/domain/mvp_weights.dart:2`).
- Impact : faible ; uniquement du style. `docs/ai/DIAGNOSTIC.md:12` annonce « 0 erreur, 0 warning » ce qui reste vrai.
- Recommandation : `dart fix --apply` dans le commit de formatage (TST-013), puis `dart analyze --fatal-infos` en CI.
- Effort : XS

## Pyramide de tests (constat chiffré)

| Application | Unitaires | Widget / composant | Intégration / API | e2e | Total exécuté le 14/11 |
|---|---|---|---|---|---|
| `mobile/` | 55 fichiers sans `testWidgets` ; 455 `test(` | 53 fichiers avec `testWidgets` ; 285 `testWidgets(` | ~40 fichiers sur SQLite en mémoire (`sqflite_common_ffi`) | 0 sur appareil | 1358 (cas paramétrés compris) |
| `backend/` | quelques tests de fonctions (`validate_sport`) | — | 19 fichiers, 124 fonctions `test_`, 442 cas via `TestClient` réel | — | 442 |
| `web/` | 16 fichiers `*.test.mjs`, 61 tests | — | — | 24 fichiers `*.e2e.mjs` (13 scriptés), non exécutés | 61 |

Répartition backend (`pytest --co -q`) : `test_sport_validation.py` 152 et `test_portal_exposure.py` 92 cas, soit 55 % de la suite sur deux fichiers paramétrés ; `test_registration_retry.py`, `test_session_lock.py` 1 cas chacun.

## Hypothèses à vérifier

1. **Couverture réelle** : sans mesure (TST-002), les zones suivantes semblent peu couvertes à la lecture : `updateScore` du contrôleur (0 appel en test), `backup_service.dart` en restauration complète avec groupes partagés (hypothèses 1 et 2 de `07-donnees.md`), `shared_group_screen.dart` (1 723 lignes) au-delà de `shared_group_screen_test.dart`. À confirmer par `flutter test --coverage`.
2. **Stabilité** : aucun `skip`/`xfail` trouvé dans les trois suites ; l'absence de tests instables n'a pas été vérifiée par exécutions répétées. 38 usages d'`AppDatabase.instance` dans `mobile/test` (singleton) pourraient créer des dépendances d'ordre entre tests.
3. **Rejeu de l'outbox restaurée** (SEC-015) et **perte de protection d'un groupe partagé après restauration** (07-donnees, hypothèse 1) : aucun test ne les couvre ; à écrire avant toute correction.

## Points positifs (Info)

- Tests comportementaux sur infrastructure réelle : SQLite en mémoire côté mobile, `TestClient` sur `create_app("sqlite:///:memory:")` côté backend ; aucun framework de mock (`mocktail`/`mockito` absents), 16 faux écrits à la main.
- Migrations : tests MIG01 à MIG11 sur schémas historiques réels extraits des commits, avec atomicité, restauration des vues en cas d'échec et volume de 5 000 participations (`database_migration_test.dart`, `fixtures/migrations/README.md`).
- Validation d'API exhaustive et paramétrée (`test_sport_validation.py` : 152 cas d'entrées malformées avec vérification d'atomicité).
- Isolation par `team_id` testée côté mobile (`tenant_isolation_test.dart`, `multi_tenant_isolation_and_archived_players_test.dart`) ; droits d'écriture testés avec le vrai `SharedService` (`write_capabilities_test.dart`), le faux `LocalTestSharedService` étant documenté comme réservé aux tests de coordination (`test/support/local_shared_service.dart:4-6`).
- Une fixture inter-clients réelle, lue par les trois suites (TST-004 en souligne la limite, pas l'idée).
- Garde d'encodage des sources (`test/core/source_encoding_test.dart`) et test de catalogue partagé Dart/JS (`domain.test.mjs`, WEB-07).
- Lint Dart strict (`very_good_analysis`) avec peu d'exceptions.
- Sur la branche `fix/mobile-red-tests`, le test supprimé (`live_picker_dialog_test.dart`) est remplacé par des tests PANEL-05 à 07 et justifié en commentaire.

## Renvois vers d'autres domaines

- **DevOps (10)** : absence de CI et déploiements non conditionnés aux tests (OPS-001) ; journaux `.txt` et captures dans `docs/` (OPS-016).
- **Métier (01)** : MET-001 (suppression de séance), MET-010 (score 0-0), divergences MET-003/007/012/016 non détectées par les tests.
- **Sécurité (06)** : SEC-002, SEC-004, SEC-005, SEC-006 sans test ; le coût PBKDF2 sous verrou (SEC-001) est aussi la cause de la lenteur de la suite (TST-009).
- **Données (07)** : DAT-006, DAT-008 (migrations), DAT-010 (comportement figé par un test).
- **Architecture (05)** : ARC-004 (copies multiples de la matrice des rôles), ARC-014 (pas de garde-fou d'architecture), ARC-016 (`// ignore`).

## Corrections de la vérification croisée (Phase 4, 14/11/2026)

Verdicts détaillés : [raw/verification-phase4.md](raw/verification-phase4.md).

- **TST-002** : Majeur → **Mineur**. Motif : manque d'outillage ; les trous réels sont portés par TST-003 et TST-004.
- **TST-005** : Majeur → **Mineur**. Motif : SEC-004 et SEC-006 sont des comportements voulus ; reste l'absence de test 429 sur /auth/login.
