# Analyse du web et du pipeline de build (`web/`, `scripts/`)

État constaté le 14/11/2026, branche `staging`, commit `2a9a3c7`. Sauf mention contraire, les chemins sont relatifs à la racine du monorepo. Les déductions sont marquées **[déduit]**.

## 1. Architecture

Deux applications web sont livrées dans un même artefact (`web/universal-dist/`).

- **Cible principale : Flutter web.** Point d'entrée `mobile/lib/main_web.dart`. Ce sont les mêmes écrans que sur mobile, avec SQLite en WASM. C'est la référence de parité (`AGENTS.md`, `docs/parite-web-mobile.md`).
- **Portail historique : `web/`.** PWA en JavaScript sans framework (environ 2 944 lignes dans `web/app.mjs`), servie sous `/portal/`.
  - Selon `web/README.md:3`, il est conservé pour retrouver les « préparations historiques », sans migration des données.
  - Il n'a reçu aucun changement fonctionnel depuis le 17/10 (`8e57365`).

**Pipeline Vercel** (`vercel.json` : `npm ci` → `bash scripts/build-universal-web.sh` → `web/universal-dist`) :
1. Si `flutter` n'est pas dans le PATH, le script clone Flutter 3.47.5 dans `.flutter-sdk/` (`scripts/build-universal-web.sh:5-11`).
2. `npm run build:web` (`scripts/app.mjs:16-27`) charge `.env.local` puis `.env`, valide `STATOO_PUBLIC_API_URL`, **exécute tous les `web/tests/*.test.mjs`**, copie le portail dans `web/dist/` et écrit `web/dist/config.json`.
3. Dans `mobile/`, il enchaîne `flutter pub get --enforce-lockfile`, `dart run sqflite_common_ffi_web:setup` puis `flutter build web --release --target lib/main_web.dart --no-web-resources-cdn --dart-define=STATOO_API=${STATOO_PUBLIC_API_URL:-https://statoo-api.onrender.com}`.
4. `scripts/package-universal-web.mjs` copie `mobile/build/web` à la racine, `web/dist` sous `portal/`, et génère un `sw.js` racine versionné par hash.

**Autres commandes.**
- `npm run build` ajoute `compileall` et `pytest` backend (`scripts/app.mjs:29-33`).
- `npm start` sert l'API et `/portal/` sur `127.0.0.1:8000`.

## 2. Points d'entrée

- **Chargement.** `web/index.html` charge le module `app.mjs`. Celui-ci lit `./config.json`, puis `apiAddress()` (`web/config.mjs:1-18`) prend l'origine courante si `api_url` est vide. `client.connect` impose HTTPS hors localhost.
- **Service worker du portail** (`web/sw.js`).
  - Version de cache **manuelle** (`2026-10-17-merged-1`), figée par `pwa.test.mjs:158`.
  - Navigation réseau d'abord, ressources en cache d'abord.
  - Mise à jour par le bouton « Mettre à jour Statoo ».
- **Service worker universel.** Généré par `package-universal-web.mjs:56-64`. Le shell Flutter `mobile/web/app-shell.js` gère ses mises à jour.

## 3. Données côté navigateur

**Portail.**
- `sessionStorage['statoo-connection']` contient le jeton, l'API et le groupe.
- `localStorage` utilise le préfixe `statoo:<api>|<group>|<account>:` pour `snapshot`, `draft:*` et `pending`.
- `statoo-registration-draft` est stocké sans mot de passe.
- Purge au logout ou sur 401.

**Validation.** Schémas Zod dans `web/validation.mjs`. Zod est vendorisé dans `web/vendor/zod.mjs` par `npm run vendor:web`.

## 4. Domaine dupliqué en JavaScript

- **`web/domain.mjs`.**
  - Capacités par rôle, identiques à celles du backend et du mobile.
  - `prepareSport` : équilibre ±1, minimum 6, buts ≤ score, calcul du résultat.
  - `prepareFinance` et sérialisation au format SQLite mobile.
- **`web/summary.mjs`.** Classement 3/1/`draw_points` et ordre de départage identique au mobile.

C'est la **troisième implémentation** des mêmes règles (Dart, Python, JS), maintenue à la main. Le fixture `web/tests/fixtures/mobile-snapshot.json` ne couvre que le format d'échange.

## 5. Authentification

- Le portail se connecte par `/auth/login` ou `/groups`.
- Le jeton Bearer est en sessionStorage.
- Les contrôles de rôle côté client sont cosmétiques.
- **Absent du portail** : récupération, changement de mot de passe, code de récupération, co-admins (ACCESS-01/02/03/07, Flutter uniquement).

## 6. Endpoints consommés (15)

Tous passent par `PortalClient.request` (`web/client.mjs:144`) :
- `POST /auth/login`, `POST /groups`, `GET /groups/{g}`, `POST /auth/logout`, `POST /groups/{g}/sync`.
- `PUT /groups/{g}/members`, `POST /groups/{g}/accounts`, `PUT /groups/{g}/accounts/{id}/roles`.
- `PUT /groups/{g}/shared-access`, `PUT /groups/{g}/sport-settings`, `PUT /groups/{g}/financial-settings`.
- `POST /groups/{g}/opening` et `/opening/approve`, `POST /groups/{g}/documents/{d}/{o}/resolve` et `/transfer`.

**Erreurs et file d'attente.**
- Timeout de 30 s.
- La file `pending` est conservée sur erreur réseau ou 5xx et retirée sur 400/403/409/422.
- Le rejeu est **manuel**, contrairement à l'outbox automatique du mobile.

## 7. Tests

- **Unitaires** (`npm run test:web`, `node --test web/tests/*.test.mjs`).
  - 61 tests passés le 14/11/2026, sans serveur.
  - Ils sont exécutés à chaque build, Vercel compris.
- **e2e Playwright** (`*.e2e.mjs`).
  - Ils exigent **Google Chrome** (`channel: "chrome"`) et des serveurs lancés à la main :
    - `web/tests/serve.py` sur 18085 ;
    - `universal-dist` sur 18087 et `serve-parity.py` sur 18088 pour `test:web:parity`.
  - Les deux serveurs Python utilisent SQLite en mémoire.
  - Ils ne sont pas lancés dans cet onboarding.
- **Tests sans script npm.** `accessible-commands-flutter`, `collective-access`, `group-entry`, `ios-input-focus`, `live-integration`, `manager-access`, `portable-photos-flutter`, `responsive-flutter`, `startup-group-flutter`, `universal-pwa`, `audit/client.audit.mjs` et `web/prototypes/live-stats/*`.
- **Risque de base réelle [déduit].** `live-integration` (port 19095) et `group-entry`, `collective-access`, `manager-access` (ports 191xx) visent un build Flutter dont l'API est figée à la compilation. Si ce build n'a pas reçu de `--dart-define`, ils créent des groupes sur l'API de production.

## 8. Dette

- **Portail figé, embarqué deux fois.** Il est servi sous `/portal/` sur Vercel et sur l'API FastAPI, et ses tests bloquent chaque build.
- **Duplications.** Règles métier ×3 ; deux service workers ; deux logiques de mise à jour ; deux manifests.
- **Code restant.** `web/prototypes/live-stats/` est un prototype déjà intégré dans Flutter.
- **Aucun TODO** dans `web/` et `scripts/`.
- **Mauvais emplacement.** `android/` et `ios/` à la racine sont des artefacts générés, versionnés par erreur dans `493d62d` (30/10) : caches `.gradle` (environ 9,7 Mo), `local.properties` avec des chemins locaux, `Generated.xcconfig`. Les vrais projets natifs sont dans `mobile/android` et `mobile/ios`.

## 9. Risques

- **Sécurité.**
  - Aucune CSP ni en-tête de sécurité (`index.html`, `vercel.json`).
  - Le portail et l'app Flutter partagent la même origine sur Vercel, donc le même stockage.
  - Snapshot financier en clair dans localStorage.
- **Build.**
  - `scripts/app.mjs:6-8` privilégie `backend/.venv/Scripts/python.exe` (Windows).
  - Sans `flutter` dans le PATH, le build fait un clone réseau d'environ 1 Go.
  - La version du cache SW est manuelle.
- **Configuration Vercel / Render.**
  - Sans `STATOO_PUBLIC_API_URL` sur Vercel, Flutter vise la production Render et le portail vise l'origine Vercel (portail cassé).
  - `web/README.md:121` décrit encore un déploiement Vercel basé sur `web/dist` : c'est obsolète, `vercel.json` utilise `web/universal-dist`.
  - `neon.ts` n'est utilisé par aucun script de build.
