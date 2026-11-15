# Audit Statoo — 10. Exploitation, CI/CD et observabilité

- **Domaine** : J — Exploitation, CI/CD, déploiement, reproductibilité, configuration par environnement, sauvegardes, observabilité, distribution mobile, hygiène du dépôt.
- **Date** : 14/11/2026. Arbre de travail de `fix/mobile-red-tests` (HEAD `2a9a3c7`, identique à `staging`).
- **Méthode** : statique (lecture des fichiers de déploiement, scripts, configuration, code), commandes locales en lecture seule (`git ls-files`, `git branch --merged`, `git rev-list`, `node --version`, `dart --version`, lecture du venv). Réutilisation des sorties de `docs/audit/raw/` (`npm-audit.log`, `pip-audit-venv.log`, `npm-outdated.log`, `build-web.log`).
- **Limites** : aucun accès à Render, Vercel, Neon ni GitHub (configuration réelle des services, variables d'environnement, branches suivies, sauvegardes Neon, journaux de production : **non visibles**). Les conclusions sur la production s'appuient sur le dépôt et sur les comptes rendus de déploiement versionnés ; elles sont marquées [déduit] quand elles en dépendent. Aucun build Flutter, Android ou iOS exécuté dans ce domaine. Fichiers `.env*` non lus.

## Synthèse

L'exploitation repose entièrement sur la discipline manuelle. Il n'existe **aucune CI** ni hook git : rien n'empêche de pousser ou de déployer du code dont les tests échouent, et les deux déploiements automatiques (Render pour l'API, Vercel pour le web) n'exécutent ni les tests backend ni les tests Flutter. Il n'y a **pas de séparation d'environnements** : la branche `staging` alimente la production (API publique et site Vercel), et tout build Flutter sans `--dart-define` vise l'API de production. L'**observabilité est nulle** : aucun log applicatif, un `/health` qui ne vérifie pas la base, aucun crash reporting mobile, aucune alerte. La sauvegarde et la restauration côté serveur (Neon) ne sont ni outillées ni documentées, et aucun plan de reprise n'existe. Le backend n'a ni lockfile ni version Python fixée, et tourne sur le plan gratuit de Render. Points solides : lockfiles Flutter et npm appliqués strictement au build web, SDK Flutter épinglé, refus de démarrer sur Render sans base, timeouts HTTP mobiles adaptés au réveil du serveur, outbox qui réessaie les erreurs transitoires.

**Note proposée : 1,5/5.** Le minimum vital existe (build web reproductible, déploiement déclaratif), mais l'absence conjointe de CI, de séparation d'environnements, d'observabilité et de procédure de restauration expose une application qui stocke des données financières de groupes réels.

## Tableau récapitulatif

| ID | Sévérité | Titre | Fichier principal | Effort |
|---|---|---|---|---|
| OPS-001 | Majeur | Aucune CI ni hook git ; les déploiements ne sont conditionnés à aucun test complet | `render.yaml`, `scripts/build-universal-web.sh` | M |
| OPS-002 | Majeur | Pas de séparation d'environnements : `staging` = production, défaut Flutter = API de production | `scripts/build-universal-web.sh:17` | M |
| OPS-003 | Majeur | Observabilité absente : aucun log applicatif, métrique, trace, alerte ni crash reporting | `backend/app/main.py`, `mobile/lib/main.dart` | M |
| OPS-004 | Majeur | Sauvegarde, restauration et plan de reprise côté serveur inexistants dans le dépôt | `docs/deploiement-backend-pwa.md:38` | M |
| OPS-005 | Majeur | Backend non reproductible : pas de lockfile, Python non fixé | `backend/requirements.txt`, `render.yaml` | S |
| OPS-006 | Majeur | Production sur le plan gratuit Render, sans garantie de disponibilité | `render.yaml:6` | S |
| OPS-007 | Majeur [déduit] | Limitation par IP probablement globale derrière le proxy Render | `backend/app/main.py:423` | S |
| OPS-008 | Mineur | `/health` ne vérifie pas la base de données | `backend/app/main.py:345` | XS |
| OPS-009 | Mineur | Versions déclarées dans `AGENTS.md` différentes des versions réelles ; outillage non épinglé | `AGENTS.md` §2 | XS |
| OPS-010 | Mineur | Configuration du portail incohérente avec celle de Flutter sur Vercel | `scripts/app.mjs:18` | XS |
| OPS-011 | Mineur | Origines CORS locales ajoutées en production via la branche `staging` | `backend/app/main.py:277` | XS |
| OPS-012 | Mineur | Schéma serveur sans outil de migration ; jetons expirés jamais purgés | `backend/app/main.py:254` | S |
| OPS-013 | Mineur | Réponses d'erreur non JSON mal gérées par le client mobile | `mobile/lib/core/data/shared_http_native.dart:21` | S |
| OPS-014 | Mineur | Distribution mobile non prête : repli silencieux sur la clé debug, version jamais incrémentée, iOS non configuré | `mobile/android/app/build.gradle.kts:55` | M |
| OPS-015 | Mineur | Artefacts générés versionnés à la racine (`android/`, `ios/`) | `android/.gradle/…` | XS |
| OPS-016 | Mineur | `docs/` chargé de 401 journaux `.txt` et 159 images | `docs/` | S |
| OPS-017 | Mineur | Branche par défaut distante obsolète et 12 branches locales déjà fusionnées | `origin/main` | XS |
| OPS-018 | Mineur | Build Vercel lourd et dépendances npm inutiles au build | `scripts/build-universal-web.sh:5` | S |
| OPS-019 | Mineur | Documentation d'exploitation obsolète, sans runbook | `README.md:12` | S |

Répartition : 0 Critique, 7 Majeur (dont 1 [déduit]), 12 Mineur, plus des points Info en fin de rapport.

---

### OPS-001 — Aucune CI ni hook git ; les déploiements ne sont conditionnés à aucun test complet

- Sévérité : Majeur / Domaine : CI/CD / Statut : confirmé
- Preuve :
  - `ls .github .gitlab-ci.yml .husky` → `No such file or directory` pour les trois ; `ls .git/hooks | grep -v sample` → vide ; `git config --get core.hooksPath` → vide.
  - Les seuls hooks présents sont ceux de l'agent Claude (`.claude/settings.json`, `.claude/hooks/guard-generated.js`, `.claude/hooks/analyze-dart.js`) : ils ne s'exécutent que dans une session Claude Code et n'analysent que le fichier Dart modifié.
  - Render : `render.yaml:7` `buildCommand: pip install -r requirements.txt`. Aucun test backend avant mise en ligne.
  - Vercel : `scripts/build-universal-web.sh:12` lance `npm run build:web`, qui n'exécute que les tests unitaires du portail (`scripts/app.mjs:20`), puis `flutter build web` (ligne 17) **sans** `flutter test` ni `dart analyze`. Les tests backend (`scripts/app.mjs:30-31`) ne sont lancés que par `npm run build`, que ni Render ni Vercel n'appellent.
  - `CLAUDE.md` (source à vérifier) déclare `staging` (`2a9a3c7`) à « 1333 OK, 16 KO » ; `staging` est la branche déployée (voir OPS-002). Non revérifié ici sur `staging` [déclaré].
- Impact : une régression (y compris sur les règles finance ou rôles, dupliquées en trois copies) peut atteindre la production sans qu'aucun contrôle automatique ne s'y oppose. La règle « commit uniquement après revue » de `AGENTS.md` §1 n'est outillée nulle part.
- Recommandation : ajouter un workflow CI (GitHub Actions, dépôt hébergé sur GitHub) déclenché sur `staging` et les PR : `pytest` backend, `npm run test:web`, `flutter analyze` + `flutter test` (avec cache du SDK), tests de parité. Protéger `staging` (PR obligatoire, statuts requis). Côté Render, activer le déploiement uniquement après succès de la CI (« Auto-Deploy: After CI checks pass ») ; côté Vercel, idem via les statuts requis.
- Effort : M

### OPS-002 — Pas de séparation d'environnements : `staging` = production, défaut Flutter = API de production

- Sévérité : Majeur / Domaine : configuration par environnement / Statut : confirmé (suivi de branche par Render : [déduit] fort)
- Preuve :
  - `docs/deploiement-d472c54-2026-10-17.md:3-4` : « Push réussi : staging distant passé de aff1af2 à d472c54 » puis « API publique : … OPTIONS /groups depuis http://127.0.0.1:19095 désormais 200 ». Or l'origine 19095 n'est ajoutée que si `RENDER_GIT_BRANCH == "staging"` (`backend/app/main.py:277-279`). Le service public `statoo-api.onrender.com` est donc déployé depuis `staging`.
  - Même document, lignes 7 et 11 : le déploiement Vercel public de `d472c54` est déclenché par le push sur `staging`.
  - `origin/main` ne contient pas `render.yaml` (`git show origin/main:render.yaml` → `fatal: path 'render.yaml' exists on disk, but not in 'origin/main'`).
  - Défaut vers la production dans le code Flutter : `mobile/lib/features/shared/presentation/shared_group_screen.dart:56-59` et `mobile/lib/features/shared/presentation/recovery_request_sheet.dart:109-111` (`defaultValue: 'https://statoo-api.onrender.com'`) ; dans le build : `scripts/build-universal-web.sh:17` (`${STATOO_PUBLIC_API_URL:-https://statoo-api.onrender.com}`).
  - `scripts/neon_smoke.py:17-18` lit `DATABASE_URL` depuis le `.env` local (via `load_environment`) et exige `neon.tech` : le poste de développement détient donc une URL Neon [déduit : sans savoir s'il s'agit de la branche de production]. `npm start` (`scripts/app.mjs:38`) et `backend/app/config.py:9-10` chargent ce même `.env`.
- Impact : il n'existe aucun environnement de recette. Toute intégration sur `staging` est une mise en production ; un `flutter run` sans `--dart-define`, un build de prévisualisation Vercel ou un serveur local relié au `.env` écrivent dans les données réelles des groupes.
- Recommandation : créer un vrai environnement de recette (service Render distinct + branche Neon dédiée, déjà prévue par `neon.ts`) ; faire suivre la production par `main` (ou une branche `production`) ; rendre `STATOO_API` **obligatoire** dans les builds release (échec si absent) et faire viser par défaut `http://127.0.0.1:8000` en debug ; distinguer les variables Vercel « Production » et « Preview ».
- Effort : M

### OPS-003 — Observabilité absente : aucun log applicatif, métrique, trace, alerte ni crash reporting

- Sévérité : Majeur / Domaine : observabilité / Statut : confirmé
- Preuve :
  - `grep -n "import logging\|logging\." backend/app/*.py | wc -l` → `0`. Aucun logger, aucun middleware de journalisation ni d'identifiant de requête dans `backend/app/main.py` ; seul gestionnaire d'exception : `RequestValidationError` (`main.py:265-267`). Les seules traces en production sont les journaux d'accès et les tracebacks par défaut d'Uvicorn.
  - Aucune dépendance Sentry, OpenTelemetry ou équivalent dans `backend/requirements.txt` ni `mobile/pubspec.yaml` (`grep -rn "sentry\|crashlytics\|firebase" mobile/lib mobile/pubspec.yaml` → vide).
  - `mobile/lib/main.dart:24-36` : `main()` ouvre la base et charge le service partagé sans `runZonedGuarded`, `FlutterError.onError` ni `PlatformDispatcher.instance.onError` (`grep` → aucune occurrence dans `mobile/lib`). Une exception au démarrage (base corrompue, migration en échec) n'est ni capturée ni remontée.
  - Le journal d'audit métier existe mais dans le JSON du groupe (`main.py:325-327`), pas dans un canal d'exploitation.
- Impact : impossible de détecter une panne, une hausse d'erreurs 500, une lenteur Neon ou un crash mobile autrement que par le signalement d'un utilisateur. Aucune donnée pour diagnostiquer un incident après coup (rétention des logs Render limitée sur le plan gratuit [déduit]).
- Recommandation : backend : `logging` structuré (JSON) avec identifiant de requête, journalisation des 4xx/5xx sans données personnelles ni jetons, Sentry (ou équivalent) côté API ; mobile/web : crash reporting avec consentement, `runZonedGuarded` + `FlutterError.onError` ; une sonde externe sur `/health` avec alerte (e-mail/Slack).
- Effort : M

### OPS-004 — Sauvegarde, restauration et plan de reprise côté serveur inexistants dans le dépôt

- Sévérité : Majeur / Domaine : sauvegardes et reprise / Statut : confirmé pour le dépôt ; état réel de Neon [non vérifiable]
- Preuve :
  - `grep -rniE "pitr|point-in-time|pg_dump|history retention|restore" docs/*.md backend/*.md README.md` : aucune procédure serveur. Seule mention : `docs/deploiement-backend-pwa.md:38` « Vérifier les sauvegardes habituelles de la base avant déploiement », sans dire lesquelles ni comment.
  - `neon.ts:6-18` ne règle que la durée de vie des branches non par défaut (`ttl: "7d"`), rien sur la rétention de l'historique ni la restauration ; `web/docs/architecture/analyse.md:108` note qu'il n'est utilisé par aucun script (revérifié : `grep` ne trouve `neon.ts` que dans `README.md` et `CLAUDE.md`).
  - Tout l'état d'un groupe est un seul document JSON (`backend/app/models.py:11-14`, colonne `state`) réécrit à chaque opération : une écriture erronée écrase l'intégralité du groupe.
  - Côté mobile, la sauvegarde est un export JSON manuel (`docs/backup.md:7` « Aucun backup automatique »).
- Impact : en cas de suppression accidentelle, de bug d'écriture du JSON ou de compromission, la capacité de restauration dépend de réglages Neon que personne n'a documentés ni testés. Aucun objectif de reprise (RPO/RTO), aucune procédure de rollback applicatif (le schéma est créé par `create_all`, voir OPS-012).
- Recommandation : documenter la fenêtre de restauration Neon effective (plan, rétention de l'historique), ajouter une sauvegarde logique planifiée (`pg_dump` vers un stockage externe) et **tester une restauration** sur une branche Neon ; rédiger un plan de reprise court (qui, comment, en combien de temps) ; envisager un historique des versions de `state` par groupe.
- Effort : M

### OPS-005 — Backend non reproductible : pas de lockfile, Python non fixé

- Sévérité : Majeur / Domaine : reproductibilité / Statut : confirmé
- Preuve :
  - `backend/requirements.txt` : bornes larges seulement (`fastapi>=0.115,<1`, `uvicorn[standard]>=0.30,<1`, `SQLAlchemy>=2.0.33,<3`, `psycopg[binary]>=3.2,<4`). Aucun fichier de verrouillage (`git ls-files | grep -E "lock"` ne renvoie que `mobile/pubspec.lock`, `package-lock.json` et des artefacts Gradle).
  - Aucune version Python fixée : pas de `PYTHON_VERSION` dans `render.yaml:10-14`, pas de `.python-version` ni `runtime.txt` (`ls` → absents).
  - Le venv local tourne en Python 3.12.3 avec `fastapi==0.143.2`, `starlette==1.8.0`, `uvicorn==0.54.0` (`pip freeze`) ; Render installe à chaque build la dernière version compatible, sur une version Python choisie par Render.
  - `docs/audit/raw/pip-audit-venv.log` : 15 vulnérabilités connues dans le venv local (`certifi`, `pip`, `opentelemetry-api`) — hors dépendances directes, voir renvois.
- Impact : la production peut tourner avec des versions jamais testées localement ; FastAPI/Starlette en 0.x/1.x introduisent des ruptures entre versions mineures (le dépôt filtre déjà `StarletteDeprecationWarning` dans `backend/pytest.ini`). Un rollback ne restaure pas les mêmes dépendances.
- Recommandation : générer un fichier verrouillé (`pip-compile` ou `uv lock`) avec empreintes, l'utiliser dans `buildCommand` ; fixer `PYTHON_VERSION` dans `render.yaml` et `.python-version` à la même valeur que le venv de test.
- Effort : S

### OPS-006 — Production sur le plan gratuit Render, sans garantie de disponibilité

- Sévérité : Majeur / Domaine : déploiement / Statut : confirmé pour la configuration ; comportement du plan [déduit]
- Preuve : `render.yaml:6` `plan: free` ; `render.yaml:8` `startCommand: uvicorn app.main:app --host 0.0.0.0 --port $PORT` (un seul processus). Le service décrit est celui de l'API publique (OPS-002).
- Impact [déduit, d'après les conditions publiques du plan gratuit Render] : mise en veille après inactivité, démarrage à froid de l'ordre de la minute, ressources partagées, pas d'engagement de disponibilité, journaux à rétention courte. Le code mobile en tient compte (timeout de 90 s, `shared_http_native.dart:19`), mais la première synchronisation après une période calme est lente et le portail peut afficher « Impossible de joindre Statoo ».
- Recommandation : passer sur une offre payante dès qu'il y a des groupes réels, ou documenter explicitement l'acceptation du risque ; ajouter au minimum une sonde externe (OPS-003).
- Effort : S

### OPS-007 — Limitation par IP probablement globale derrière le proxy Render

- Sévérité : Majeur / Domaine : déploiement, sécurité opérationnelle / Statut : [déduit]
- Preuve :
  - `backend/app/main.py:423` (`/auth/login`) et `:445` (`/auth/recover`) indexent les compteurs par `request.client.host`. `main.py:427-428` : 429 au-delà de 20 tentatives en 60 s par clé ; la clé n'est remise à zéro qu'après un succès (`main.py:434`).
  - `render.yaml:8` lance Uvicorn sans `--forwarded-allow-ips`. Dans la version installée, `backend/.venv/lib/python3.12/site-packages/uvicorn/config.py:362-363` : les en-têtes `X-Forwarded-For` ne sont pris en compte que si le pair est dans `FORWARDED_ALLOW_IPS`, par défaut `127.0.0.1,::1`.
  - Derrière le répartiteur de Render, le pair TCP n'est pas `127.0.0.1` [déduit] : `request.client.host` vaut alors l'adresse du proxy pour tous les clients, sauf si la variable `FORWARDED_ALLOW_IPS` est définie dans Render (non visible).
- Impact : si la déduction se confirme, 20 tentatives erronées par minute, de n'importe qui, bloquent la connexion de **tous** les utilisateurs (déni de service simple), et le seuil de 10/min de `/auth/recover` est partagé de même. À l'inverse, la limitation ne freine pas un attaquant distribué.
- Recommandation : vérifier dans Render la valeur de `FORWARDED_ALLOW_IPS` et la réalité de `request.client.host` (log temporaire) ; ajouter `--proxy-headers --forwarded-allow-ips='*'` (Render étant le seul point d'entrée) ou lire l'en-tête documenté par Render ; ajouter un test qui fixe le comportement.
- Effort : S

### OPS-008 — `/health` ne vérifie pas la base de données

- Sévérité : Mineur / Domaine : observabilité / Statut : confirmé
- Preuve : `backend/app/main.py:345-347` renvoie `{"status": "ok"}` sans requête SQL ; `render.yaml:9` l'utilise comme `healthCheckPath`.
- Impact : Render considère le service sain même si Neon est indisponible ou si les identifiants ont expiré ; un déploiement cassé côté base n'est pas bloqué par le contrôle de santé.
- Recommandation : `SELECT 1` avec timeout court (sur une route `/health/ready` si l'on veut garder `/health` comme liveness) ; ne pas exposer de détail d'erreur.
- Effort : XS

### OPS-009 — Versions déclarées dans `AGENTS.md` différentes des versions réelles ; outillage non épinglé

- Sévérité : Mineur / Domaine : reproductibilité / Statut : confirmé
- Preuve (déclaré `AGENTS.md` §2 → constaté) :

  | Élément | Déclaré | Constaté |
  |---|---|---|
  | Flutter / Dart | 3.47.5 / 3.13.4 | 3.47.5 / 3.13.4 (`flutter --version`, `dart --version`) — conforme |
  | Riverpod, GoRouter, sqflite | 3.4.3, 18.0.1, 2.4.4 | identiques dans `mobile/pubspec.lock` — conforme |
  | Freezed | 3.1.0 | `freezed` 4.0.2, `freezed_annotation` 3.1.0 (`pubspec.lock`) |
  | Node.js | 22.23.2 | `v22.17.1` (`/usr/local/bin/node`) |
  | npm | non déclaré | `npm` du PATH = 6.14.18, issu de `~/.nvm/versions/node/v14.21.3` |
  | Python | 3.13.5 | 3.12.3 (`backend/.venv/bin/python --version`) |
  | FastAPI | 0.143.0 | 0.143.2 (venv) ; `requirements.txt` accepte `>=0.115` |

  - `docs/audit/raw/npm-audit.log:1` : « npm 6.14.18 (PATH) échoue : 'Cannot read properties of undefined (reading @neon/config)' » — npm 6 ne sait pas lire `package-lock.json` en `lockfileVersion: 3` (`package-lock.json:3`).
  - Aucun `.nvmrc`, champ `engines` dans `package.json`, `.tool-versions` ni `.python-version`.
- Impact : un nouveau contributeur ou un agent suit des versions fausses ; `npm ci` local échoue avec le npm du PATH. Vercel choisit sa version de Node selon les réglages du projet, invisibles dans le dépôt.
- Recommandation : corriger `AGENTS.md` (et `GEMINI.md`), ajouter `.nvmrc` + `"engines": {"node": "22.x"}` et `.python-version`, documenter la version réelle de Python.
- Effort : XS

### OPS-010 — Configuration du portail incohérente avec celle de Flutter sur Vercel

- Sévérité : Mineur / Domaine : configuration par environnement / Statut : confirmé (valeur réelle sur Vercel [non vérifiable])
- Preuve :
  - `scripts/app.mjs:18-19,26` : sans `STATOO_PUBLIC_API_URL`, `web/dist/config.json` contient `{"api_url":""}` ; le portail retombe alors sur `location.origin` (`web/app.mjs:2896-2901`, `web/config.mjs:2`), c'est-à-dire le domaine Vercel, qui n'héberge pas l'API.
  - Dans le même build, Flutter retombe sur l'API de production (`scripts/build-universal-web.sh:17`).
  - Le backend expose aussi `/portal/config.json` (`backend/app/main.py:268-271`) et sert le dossier `web/` source, pas `web/dist` (`main.py:273-275`).
- Impact : selon la présence de la variable dans Vercel, le portail `/portal/` est soit inutilisable, soit relié à la production ; les deux clients d'un même déploiement peuvent viser des serveurs différents.
- Recommandation : un seul point de vérité pour l'URL d'API, obligatoire au build release (échec explicite si absente), partagé par le portail et Flutter.
- Effort : XS

### OPS-011 — Origines CORS locales ajoutées en production via la branche `staging`

- Sévérité : Mineur / Domaine : configuration par environnement / Statut : confirmé (lié à OPS-002)
- Preuve : `backend/app/main.py:277-279` ajoute `http://127.0.0.1:18085`, `http://localhost:18085`, `http://127.0.0.1:19095`, `http://localhost:19095` quand `RENDER_GIT_BRANCH == "staging"` ; le service public suit `staging` (OPS-002, `docs/deploiement-d472c54-2026-10-17.md:4`).
- Impact : l'API de production accepte des origines de développement. Le risque direct reste limité (jetons Bearer, pas de cookies), mais la règle « staging seulement » ne joue pas son rôle.
- Recommandation : piloter ces origines par une variable explicite (`STATOO_DEV_ORIGINS`) absente en production, une fois l'environnement de recette séparé.
- Effort : XS

### OPS-012 — Schéma serveur sans outil de migration ; jetons expirés jamais purgés

- Sévérité : Mineur / Domaine : exploitation de la base / Statut : confirmé
- Preuve :
  - `backend/app/main.py:251-254` : `Base.metadata.create_all(...)` au démarrage ; aucun Alembic ni script de migration (`grep -rn "alembic\|migrat" backend/app` → vide). `create_all` ne crée que les tables manquantes : il n'ajoute ni ne modifie de colonne sur une table existante.
  - Aucune purge des jetons expirés : les seules suppressions de `Token` (`main.py:440, 498, 585, 607, 697`) sont des révocations explicites ; les jetons durent 30 jours (`main.py:331`).
- Impact : la première évolution de colonne (ex. index, nouvelle colonne sur `tokens`) devra se faire à la main sur Neon, sans trace ni rollback ; la table `tokens` croît indéfiniment.
- Recommandation : introduire Alembic (migration initiale = schéma actuel) et l'exécuter en `preDeployCommand` ; tâche de purge des jetons expirés (au login ou planifiée).
- Effort : S

### OPS-013 — Réponses d'erreur non JSON mal gérées par le client mobile

- Sévérité : Mineur / Domaine : gestion des erreurs en production / Statut : confirmé pour le code ; affichage final [déduit]
- Preuve :
  - `mobile/lib/core/data/shared_http_native.dart:21` et `mobile/lib/core/data/shared_http_browser.dart:23` décodent le corps en JSON **avant** de tester le statut ; seules `IOException`/`ClientException` et `TimeoutException` sont converties en `SharedNetworkException` (`:26-29`, `:28-31`).
  - Une 500 non gérée de FastAPI (texte brut « Internal Server Error ») ou une page HTML de Render (502/503 pendant un déploiement ou un réveil) lève donc une `FormatException`.
  - `mobile/lib/features/shared/data/shared_service.dart:605-616` : l'outbox classe cette erreur en `pending` (pas de perte, bon point) mais enregistre `'$error'` comme message ; `:671-673` copie `'$error'` dans `syncWarning`.
- Impact : l'utilisateur peut voir un message technique (« FormatException: Unexpected character… ») au lieu du message réseau prévu ; les incidents serveur sont indiscernables des erreurs de format.
- Recommandation : tester le statut avant de décoder, convertir tout 5xx ou corps non JSON en `SharedNetworkException` ; côté API, gestionnaire d'exception global qui renvoie `{"detail": "..."}` en 500.
- Effort : S

### OPS-014 — Distribution mobile non prête : repli silencieux sur la clé debug, version jamais incrémentée, iOS non configuré

- Sévérité : Mineur (Majeur si des APK sont déjà distribués) / Domaine : distribution mobile / Statut : confirmé
- Preuve :
  - `mobile/android/app/build.gradle.kts:52-56` : `signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")` — sans `key.properties`, le build release est signé avec la clé debug, sans avertissement. `key.properties`, `*.jks` et `*.keystore` sont bien ignorés (`mobile/android/.gitignore`).
  - `mobile/pubspec.yaml:19` `version: 1.0.0+1`, inchangé depuis le commit `2faa8f7` du 24/09/2026 (`git log -L19,19:mobile/pubspec.yaml`) : `versionCode` reste 1.
  - iOS : `mobile/ios/Runner.xcodeproj/project.pbxproj` contient `CODE_SIGN_STYLE = Automatic` mais aucun `DEVELOPMENT_TEAM` ; `mobile/ios/Runner/Info.plist` ne contient pas `NSPhotoLibraryUsageDescription` alors que `new_player_bottom_sheet.dart:38` utilise `ImageSource.gallery` (déjà relevé dans `docs/testing-and-release.md:52`).
  - Aucun Fastlane, aucune procédure de publication versionnée (`docs/testing-and-release.md:54`).
- Impact : un APK signé debug ne pourra pas être mis à jour par un APK signé avec la vraie clé (désinstallation obligatoire, perte des données SQLite locales non sauvegardées) ; le Play Store refuse un `versionCode` déjà utilisé ; la revue App Store rejette usuellement l'absence de chaîne d'usage photo [déduit].
- Recommandation : faire échouer le build release sans `key.properties` (ou exiger un drapeau explicite) ; incrémenter la version à chaque livraison (idéalement en CI) ; compléter `Info.plist` ; documenter la procédure de release.
- Effort : M

### OPS-015 — Artefacts générés versionnés à la racine (`android/`, `ios/`)

- Sévérité : Mineur / Domaine : hygiène du dépôt / Statut : confirmé
- Preuve : `git ls-files android ios | wc -l` → 28 fichiers, ajoutés par `493d62d` (30/10/2026). Dont `android/.gradle/9.3.1/executionHistory/executionHistory.bin` (9 704 604 octets, plus gros fichier suivi du dépôt), `android/local.properties` (clés `sdk.dir`, `flutter.sdk` : chemins machine), `ios/Flutter/ephemeral/flutter_native_integration.env`, `ios/Flutter/flutter_export_environment.sh`. Les vrais projets natifs sont dans `mobile/android` et `mobile/ios`.
- Impact : bruit dans les diffs, 10 Mo dans l'historique, fuite de chemins locaux, confusion pour les outils (deux arborescences `android/`).
- Recommandation : `git rm -r --cached android ios` et ajouter `/android/` et `/ios/` au `.gitignore` racine (avec accord, hors de cet audit).
- Effort : XS

### OPS-016 — `docs/` chargé de 401 journaux `.txt` et 159 images

- Sévérité : Mineur / Domaine : hygiène du dépôt / Statut : confirmé
- Preuve : `git ls-files docs | grep -c '\.txt$'` → 401 (dont 259 directement dans `docs/`) ; `git ls-files docs | grep -E "\.(png|jpg)$" | wc -l` → 159 ; `du -sh docs` → 20 Mo sur 750 fichiers suivis. `.gitignore:6` ignore `*.log` mais pas ces sorties de tests en `.txt`.
- Impact : la documentation utile est noyée ; chaque clone transporte des sorties de tests figées qui ne prouvent plus rien.
- Recommandation : déplacer les preuves dans un dossier `docs/evidence/<date>/` archivé (ou hors dépôt), garder un index ; règle `.gitignore` pour les sorties de tests.
- Effort : S

### OPS-017 — Branche par défaut distante obsolète et 12 branches locales déjà fusionnées

- Sévérité : Mineur / Domaine : gestion des branches / Statut : confirmé
- Preuve :
  - `git branch -a` : `remotes/origin/HEAD -> origin/main`. `origin/main` = `e6a0fc7` (12/08/2026, pile Nuxt/Capacitor : `git ls-tree origin/main` montre `nuxt.config.ts`, `capacitor.config.ts`) ; c'est la base de fusion avec `staging`, qui a 120 commits d'avance (`git rev-list --count origin/main..origin/staging` → 120, inverse → 0).
  - `origin/main:vercel.json` décrit un build Nuxt (`NITRO_PRESET=static npm run generate`).
  - `git branch --merged staging` : les 12 branches `backup-user-wip`, `docs/ACCESS-backlog`, `feat/ACCESS-01…07`, `feat/API-01…`, `feat/DATA-01…`, `feat/FEAT-01…`, `feat/PARITY-01…`, `feat/PERF-01…`, `feat/add-manager-bottom-sheet`, `refonte` sont entièrement contenues dans `staging`.
  - `README.md:12` annonce encore `codex/finances-et-groupe-partage` comme branche de travail.
- Impact : un clone par défaut récupère l'ancienne application ; si un projet Vercel suit `main` en production, il publie l'ancienne pile [hypothèse] ; confusion sur la branche de référence.
- Recommandation : avancer `main` sur `staging` (fast-forward possible) ou changer la branche par défaut GitHub ; supprimer les branches fusionnées (avec accord) ; corriger le README.
- Effort : XS

### OPS-018 — Build Vercel lourd et dépendances npm inutiles au build

- Sévérité : Mineur / Domaine : déploiement web / Statut : confirmé
- Preuve :
  - `scripts/build-universal-web.sh:5-11` : si `flutter` est absent, clone de Flutter (`--branch 3.47.5`, épinglé, bon point) dans `.flutter-sdk`, puis téléchargement du moteur et de Dart par Flutter à la première commande ; rien ne garantit la mise en cache de `.flutter-sdk` entre builds Vercel [déduit].
  - `scripts/build-universal-web.sh:16` régénère `sqlite3.wasm` alors que `mobile/web/sqlite3.wasm` (748 686 octets) est aussi versionné (`8e57365`, 17/10) : deux sources possibles pour le même binaire.
  - `package.json:15-16` place `@neon/config` et `@neon/env` en `dependencies` alors qu'aucun script de build ne les utilise ; `npm ci` (`vercel.json:4`) les installe à chaque build.
- Impact : builds longs et dépendants de GitHub ; risque de divergence du binaire SQLite web.
- Recommandation : préférer une image de build avec Flutter préinstallé ou un build en CI qui publie l'artefact vers Vercel ; ne pas versionner `sqlite3.wasm` (ou ne pas le régénérer) ; déplacer les paquets Neon en `devDependencies`.
- Effort : S

### OPS-019 — Documentation d'exploitation obsolète, sans runbook

- Sévérité : Mineur / Domaine : documentation d'exploitation / Statut : confirmé
- Preuve :
  - `README.md:12` (branche de travail périmée) ; `docs/deploiement-backend-pwa.md:43`, `README.md:57-60` : chemins Windows `.venv/Scripts` seulement.
  - `docs/deploiement-backend-pwa.md:16` affirme « le verrou compatible avec les workers FastAPI » alors que le verrou est un `threading.Lock` par processus (`backend/app/main.py:284`, utilisé ligne 299) et que les compteurs de tentatives sont en mémoire (`main.py:285-288`) ; ils ne seraient pas partagés avec plusieurs workers Uvicorn.
  - `docs/backup.md:3` date du 12/10 et cite des chemins `lib/…` sans le préfixe `mobile/` ; des évolutions ultérieures (versions de sauvegarde 26/10, atomicité de restauration 27/10) ne sont pas reportées [déduit, à confronter au domaine données].
  - Aucun document « incident », « rollback » ou « rotation de secrets ».
- Impact : en cas d'incident, aucune procédure à suivre ; les documents existants peuvent induire en erreur (notamment sur le passage à plusieurs workers).
- Recommandation : un `docs/exploitation.md` unique : environnements, variables, déploiement, rollback Render/Vercel, restauration Neon, rotation des secrets, contacts ; marquer les documents historiques comme tels.
- Effort : S

---

## Hypothèses à vérifier

1. **Variable `FORWARDED_ALLOW_IPS` dans Render** : décide si OPS-007 est réel. Vérifiable dans le tableau de bord Render ou par un log temporaire de `request.client.host`.
2. **Branche suivie par Vercel en production** : les comptes rendus montrent que `staging` est publié sur le domaine public ; si un projet Vercel suit encore `main`, l'ancienne pile Nuxt est aussi en ligne.
3. **Rétention de l'historique Neon** (PITR) du projet et existence d'une branche de recette : non visible.
4. **URL Neon du `.env` local** : branche de production ou de développement ? (`.env` non lu volontairement.)
5. **APK déjà distribués** : si oui, signés avec la clé debug ou la clé release ? (escalade d'OPS-014 en Majeur.)
6. **Variables Vercel** `STATOO_PUBLIC_API_URL` en Production et Preview (OPS-010, OPS-002).
7. **Version de Python effectivement utilisée par Render** au dernier déploiement (OPS-005).
8. **Endpoints `/docs` et `/openapi.json`** activés par défaut en production (`FastAPI(title=…)`, `main.py:263`, utilisés par `scripts/check-online-api.py:11`) : exposition voulue ? (renvoi sécurité).

## Points positifs (Info)

- Build web reproductible : `npm ci` (`vercel.json:4`) sur `package-lock.json` v3 avec empreintes d'intégrité ; `flutter pub get --enforce-lockfile` (`scripts/build-universal-web.sh:15`) ; SDK Flutter épinglé sur le tag `3.47.5` (`:8`) ; `pubspec.lock` versionné.
- Le backend refuse de démarrer sur Render sans base distante (`backend/app/main.py:246-247`) et le chargement du `.env` n'écrase pas les variables de l'hébergeur (`backend/app/config.py:9-10`, `override=False`).
- `/portal/config.json` n'expose qu'une liste blanche (`main.py:268-271`) ; le build du portail n'écrit que `api_url` (`scripts/app.mjs:26`).
- Démarrage Uvicorn mono-processus (`render.yaml:8`) cohérent avec le verrou et les compteurs en mémoire : à conserver tant que ces états ne sont pas externalisés.
- Timeouts mobiles adaptés au réveil du serveur (90 s, `shared_http_native.dart:19`, `shared_http_browser.dart:21`) et outbox qui conserve en `pending` les échecs transitoires (`shared_service.dart:611-614`).
- Secrets de signature Android correctement ignorés (`mobile/android/.gitignore`) ; `.env*` ignorés sauf `.env.example`, qui ne contient que `STATOO_PUBLIC_API_URL`.
- Sonde de recette en lecture seule (`scripts/check-online-api.py:1`) et hooks Claude qui empêchent d'éditer le code généré (`.claude/hooks/guard-generated.js`).
- `npm audit` : 0 vulnérabilité (`docs/audit/raw/npm-audit.log`).

## Renvois vers d'autres domaines

- **Sécurité** : OPS-007 (limitation par IP), exposition de `/docs` et `/openapi.json` en production, absence d'en-têtes de sécurité dans `vercel.json` (staging) ; 15 vulnérabilités `pip-audit` dans le venv local (`certifi`, `pip`, `opentelemetry-api`, `docs/audit/raw/pip-audit-venv.log`), à distinguer des dépendances de production.
- **Données / sauvegarde mobile** : actualité de `docs/backup.md` face aux lots du 26-27/10.
- **Performance backend** : journal d'audit `state["audit"]` ajouté sans borne dans le JSON du groupe (`main.py:325-327`).
- **Tests** : 16 tests rouges déclarés sur `staging`, déployée en production.
- **Process d'audit** : `.gitignore:6` (`*.log`) ignore `docs/audit/raw/*.log` (`git check-ignore -v docs/audit/raw/pytest.log` → `.gitignore:6:*.log`) ; les preuves brutes de cet audit ne seront pas versionnées sans règle d'exception.

## Vérification croisée (Phase 4, 14/11/2026)

Tous les constats Critique et Majeur de ce rapport ont été relus et **confirmés** (aucun retrait, aucune requalification). Verdicts : [raw/verification-phase4.md](raw/verification-phase4.md).
