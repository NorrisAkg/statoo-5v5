# Audit Statoo — 11. Dépendances et conformité

- **Domaine** : dépendances (vulnérabilités, obsolescence, épinglage, dépendances inutilisées, vendorisation), licences, outillage.
- **Date** : 14/11/2026. Arbre de travail de la branche `fix/mobile-red-tests` (HEAD `2a9a3c7`).
- **Méthode** : statique et exécutée en lecture seule.
  - Sorties déjà produites le 14/11 : `docs/audit/raw/npm-audit.log` et `.json`, `npm-outdated.log`, `pip-audit.log`, `pip-audit-venv.log`, `pip-freeze.txt`, `pub-outdated.log`.
  - Commandes locales : `backend/.venv/bin/pip show`, lecture des `METADATA` du venv, lecture de `package-lock.json`, `node_modules/*/package.json`, `mobile/.dart_tool/package_config.json`, des fichiers `LICENSE` du cache pub (`~/.pub-cache`) et de `mobile/build/web/assets/NOTICES`.
  - `grep` des imports de chaque dépendance directe.
  - Régénération de `web/vendor/zod.mjs` **dans le scratchpad** avec l'esbuild local, pour comparer les empreintes.
- **Limites** :
  - Aucun appel réseau : pas de `pip list --outdated`, pas de consultation des registres. L'abandon éventuel d'un paquet n'est pas vérifiable.
  - **Aucun outil d'avis de sécurité Dart** n'est disponible localement (pas d'OSV-Scanner) : les 169 paquets Dart **n'ont pas été analysés** pour les vulnérabilités. `flutter pub outdated` ne donne que l'obsolescence.
  - La gravité exacte des avis Python (CVE/PYSEC) n'est pas connue hors ligne : seuls l'identifiant et la version corrective figurent dans le journal.
  - Les versions réellement installées sur Render ne sont pas observables depuis le dépôt.
  - `docs/audit/raw/pip-audit-install.log` est vide (0 ligne). La date d'installation de pip-audit est déduite des horodatages du venv.

## Synthèse

Pas de vulnérabilité connue côté npm (`found 0 vulnerabilities`, 64 paquets). Côté Python, le seul avis qui touche une dépendance de **production** concerne `opentelemetry-api 1.45.1` (CVE-2026-126360), tiré par `fastapi 0.143.2`. Les avis sur `pip 24.0` et `certifi` ne concernent que le venv local : `certifi` vient de `httpx` (dépendance de dev) et de `pip-audit`. Le défaut principal du domaine est **structurel** : le backend n'a pas de lockfile et le `pip-audit -r requirements-dev.txt` « propre » n'a pas audité les versions installées. Personne ne sait donc ce qui tourne en production.

Les fronts sont mieux tenus :
- `package-lock.json` v3 et `pubspec.lock` sont versionnés et appliqués au build (`npm ci`, `--enforce-lockfile`) ;
- le Flutter SDK est épinglé ;
- le bundle Zod vendorisé est **reproductible au bit près**.

Côté hygiène :
- dépendances inutilisées : `@neon/env`, `cupertino_icons`, `flutter_lints`, et `@neon/config` placé en dépendance de production ;
- deux épinglages exacts sans justification (`http`, `sqflite_common_ffi_web`) ;
- le `sqlite3.wasm` est téléchargé sans contrôle d'intégrité à chaque build Vercel ;
- les versions annoncées dans `AGENTS.md` sont fausses.

Licences : aucune GPL ni AGPL. Trois copyleft faibles :
- `psycopg` en LGPL-3.0 (serveur) ;
- `certifi` en MPL-2.0 (dev) ;
- `dbus` en MPL-2.0 (transitif Linux).

Le projet n'a **aucune licence propre**.

**Note proposée : 3/5.** Les fronts sont reproductibles et sans vulnérabilité connue. Le backend n'est ni reproductible ni audité sur ses versions réelles. Aucun scan de vulnérabilités n'est automatisé, et l'écosystème Dart n'est pas scanné du tout.

## Tableau récapitulatif

| ID | Sévérité | Titre | Fichier principal | Effort |
|---|---|---|---|---|
| DEP-001 | Majeur | Backend sans lockfile : versions de production inconnues, audit `pip-audit -r` non représentatif | `backend/requirements.txt` | S |
| DEP-002 | Mineur | `opentelemetry-api 1.45.1` vulnérable (CVE-2026-126360), dépendance de production via FastAPI | `backend/requirements.txt:1` | XS |
| DEP-003 | Mineur | Venv local périmé et pollué par l'outillage d'audit (`pip 24.0`, 13 avis ; arbre `pip-audit`) | `backend/.venv` | XS |
| DEP-004 | Mineur | `@neon/env` inutilisé, `@neon/config` en `dependencies` : 21 paquets « prod » installés à chaque build | `package.json:15-16` | XS |
| DEP-005 | Mineur | Dépendances Flutter inutilisées : `cupertino_icons`, `flutter_lints` (doublon de `very_good_analysis`) | `mobile/pubspec.yaml:36,68` | XS |
| DEP-006 | Mineur | Épinglages exacts non justifiés et retards de version (2 majeures Dart, 1 npm, 66 verrous en retard) | `mobile/pubspec.yaml:56-57` | S |
| DEP-007 | Mineur | `sqlite3.wasm` téléchargé depuis GitHub à chaque build Vercel, sans contrôle d'intégrité | `scripts/build-universal-web.sh:16` | S |
| DEP-008 | Mineur | Versions déclarées dans `AGENTS.md` différentes des lockfiles et de l'environnement | `AGENTS.md:10-12` | XS |
| DEP-009 | Mineur | Aucune analyse de vulnérabilités automatisée ; dépendances Dart jamais scannées | — | S |
| DEP-010 | Mineur | Le projet n'a pas de licence ; métadonnées par défaut dans `pubspec.yaml` | racine, `mobile/pubspec.yaml:2` | XS |
| DEP-011 | Mineur | L'app mobile n'expose pas les licences tierces (pas de `showLicensePage`) | `mobile/lib/` | XS |
| DEP-012 | Info | Copyleft faible présent : `psycopg` LGPL-3.0, `certifi` MPL-2.0, `dbus` MPL-2.0 ; aucune GPL ni AGPL | `backend/requirements.txt:4` | — |
| DEP-013 | Info | SDK Flutter cloné par tag sans vérification de révision | `scripts/build-universal-web.sh:8` | XS |

Total : 0 critique, 1 majeur, 10 mineurs, 2 info.

---

### DEP-001 — Backend sans lockfile : versions de production inconnues, audit `pip-audit -r` non représentatif
- Sévérité : Majeur / Domaine : dépendances / Statut : confirmé (conséquence sur Render [déduit])
- Preuve :
  - `backend/requirements.txt:1-5` ne contient que des bornes : `fastapi>=0.115,<1`, `uvicorn[standard]>=0.30,<1`, `SQLAlchemy>=2.0.33,<3`, `psycopg[binary]>=3.2,<4`, `python-dotenv>=1.0,<2`. `backend/requirements-dev.txt:1-3` : `-r requirements.txt`, `pytest>=8,<10`, `httpx>=0.27,<1`. Il n'y a ni lockfile, ni `constraints.txt`, ni `pip-tools` ou `uv.lock`.
  - `render.yaml:7` : `buildCommand: pip install -r requirements.txt`. Render résout donc à chaque build les dernières versions compatibles, sur une version de Python non fixée (cf. OPS-005).
  - `docs/audit/raw/pip-audit.log` : « No known vulnerabilities found » sur `requirements-dev.txt`. Le même jour, `docs/audit/raw/pip-audit-venv.log` signale `opentelemetry-api 1.45.1` vulnérable dans le venv. Avec `-r`, pip-audit a résolu ses propres versions, plus récentes [déduit], et non celles installées. Les deux audits ne portent pas sur le même ensemble.
  - FastAPI est en 0.x, avec une borne `<1` qui accepte des dizaines de mineures (0.115 à 0.143 et au-delà). Starlette, tirée transitivement, est déjà en 1.8.0 (`pip-freeze.txt`).
- Impact : impossible de dire quelles versions tournent en production, ni de rejouer un build à l'identique. Une nouvelle mineure de FastAPI ou de Starlette peut casser l'API au prochain déploiement sans changement de code. Un audit de sécurité sur le manifeste ne prouve rien sur l'existant.
- Recommandation :
  - Générer un lockfile avec empreintes (`pip-compile --generate-hashes` ou `uv pip compile`) en `requirements.lock`, et l'utiliser dans `render.yaml` (`pip install --require-hashes -r requirements.lock`).
  - Fixer `PYTHON_VERSION`.
  - Auditer le lockfile, pas le manifeste.
- Effort : S

### DEP-002 — `opentelemetry-api 1.45.1` vulnérable, dépendance de production via FastAPI
- Sévérité : Mineur / Domaine : sécurité des dépendances / Statut : confirmé (gravité réelle [déduit])
- Preuve :
  - `docs/audit/raw/pip-audit-venv.log` : `opentelemetry-api 1.45.1 CVE-2026-126360 1.45.2`.
  - `backend/.venv/bin/pip show opentelemetry-api` : `Required-by: fastapi`. `pip show fastapi` : `Requires: annotated-doc, opentelemetry-api, pydantic, starlette, …`.
  - Installé le 15/10/2026 avec FastAPI : horodatage de `opentelemetry_api-1.45.1.dist-info` (2026-10-15 20:12:31), le même que `fastapi-0.143.2.dist-info`.
  - Ce n'est donc **pas** un artefact de l'installation de pip-audit (14/11 16:40). L'application ne l'importe pas directement : `grep opentelemetry backend/app` ne renvoie rien.
- Impact : le paquet est installé en production à chaque build Render. Sans SDK OpenTelemetry configuré, l'API est en principe inerte [déduit], ce qui limite l'exposition. La gravité de la CVE n'est pas consultable hors ligne.
- Recommandation : recréer le venv, puis vérifier que la version résolue est ≥ 1.45.2. L'épingler dans le futur lockfile (DEP-001) et consulter l'avis pour qualifier l'exposition.
- Effort : XS

### DEP-003 — Venv local périmé et pollué par l'outillage d'audit
- Sévérité : Mineur / Domaine : outillage / Statut : confirmé
- Preuve :
  - `pip-audit-venv.log` : 13 lignes d'avis sur `pip 24.0` (PYSEC-2026-1795, -1796, -2875, -2876, -196, -3721 ; corrections de 25.3 à 26.2). `pip-24.0.dist-info` est le pip d'amorçage du venv (Python 3.12.3).
  - `certifi 2026.7.22` (PYSEC-2026-4320, corrigé en 2026.10.18) : `pip show certifi` donne `Required-by: httpcore, httpx, requests`. `httpx` est une dépendance de **dev** (`requirements-dev.txt:3`) et `requests` vient de `pip_audit`. Aucune dépendance de `requirements.txt` ne tire `certifi`. Le paquet est donc **absent de la production** [déduit de l'arbre `Requires`].
  - `pip_audit-2.10.1` a été installé le 14/11/2026 à 16:40 dans `backend/.venv` (horodatage du `dist-info`). Il a ajouté une quinzaine de paquets étrangers au projet : `requests`, `urllib3`, `CacheControl`, `msgpack`, `cyclonedx-python-lib`, `packageurl-python`, `py-serializable`, `license-expression`, `boolean.py`, `defusedxml`, `sortedcontainers`, `pip_api`, `pip-requirements-parser`, `pyparsing`, `platformdirs`, `rich`, `markdown-it-py`, `mdurl`, `tomli`, `tomli_w`, `filelock` (`pip show … Required-by`). `pip-freeze.txt` les inclut.
- Impact : un `pip freeze` fait sur ce venv pour créer un lockfile embarquerait l'outillage d'audit. Le pip vulnérable ne sert qu'en local.
- Recommandation : recréer `backend/.venv` à partir de `requirements-dev.txt` (ou du futur lockfile) avec un pip à jour. Installer pip-audit hors du venv applicatif (`pipx run pip-audit`).
- Effort : XS

### DEP-004 — `@neon/env` inutilisé, `@neon/config` en `dependencies`
- Sévérité : Mineur / Domaine : dépendances npm / Statut : confirmé
- Preuve :
  - `package.json:15-16` : `"@neon/config": "^1.9.1"` et `"@neon/env": "^1.6.2"` en `dependencies`.
  - `grep -rln "@neon/env"` hors `node_modules` : seulement `package.json`, `package-lock.json` et les rapports d'audit. **Aucun import.**
  - `@neon/config` n'est importé que par `neon.ts:1` (`import { defineConfig } from "@neon/config/v1"`), un fichier de politique lu par la CLI `neon deploy` (`README.md:32`), pas par l'application ni par les scripts de build.
  - `docs/audit/raw/npm-audit.json` : `"prod":21`. Ces 21 paquets « de production » sont l'arbre `@neon/*`, `@neon/sdk`, `yargs`, etc. (`package-lock.json`). Le portail n'a lui-même aucune dépendance runtime npm : Zod est vendorisé.
  - `npm-outdated.log` : `@neon/env 1.6.2 → 2.1.3` (majeure en retard), `@neon/config 1.9.1 → 1.14.0`.
  - Recoupe OPS-018.
- Impact : installation inutile à chaque `npm ci` Vercel (`vercel.json:4`), surface de chaîne d'approvisionnement accrue et bruit dans les audits.
- Recommandation : supprimer `@neon/env`. Déplacer `@neon/config` en `devDependencies`, ou le retirer si la CLI Neon n'est plus utilisée.
- Effort : XS

### DEP-005 — Dépendances Flutter inutilisées : `cupertino_icons`, `flutter_lints`
- Sévérité : Mineur / Domaine : dépendances Dart / Statut : confirmé
- Preuve :
  - `mobile/pubspec.yaml:36` `cupertino_icons: ^1.0.8`. `grep -rl "package:cupertino_icons/" lib test` : 0 fichier. `grep -rn CupertinoIcons mobile/lib` : 0 occurrence. La police est pourtant déclarée dans `mobile/build/web/assets/FontManifest.json` (réduite par tree-shaking à 1 472 octets).
  - `mobile/pubspec.yaml:68` `flutter_lints: ^6.0.0` et `:73` `very_good_analysis: ^11.0.0`. `mobile/analysis_options.yaml:1` n'inclut que `package:very_good_analysis/analysis_options.yaml`, et aucun autre `analysis_options` ne référence `flutter_lints`.
- Vérifiées et **utilisées** :
  - `riverpod_annotation` : `lib/core/theme/theme_provider.dart:3`, `lib/core/router/app_router.dart:3` ;
  - `image` : `lib/core/media/player_photo.dart:8` ;
  - `shared_preferences` : 7 fichiers de `lib/` ;
  - `path` : `lib/core/data/app_database.dart:2` ;
  - `http` : `lib/core/data/shared_http_browser.dart:4` ;
  - `sqflite_common_ffi_web` : `lib/main_web.dart:3` ;
  - `sqflite_common_ffi` : tests uniquement, c'est bien une dépendance de dev ;
  - `json_annotation` : aucun import direct, mais requis par `json_serializable` pour le code `*.g.dart`. `freezed_annotation` le réexporte (`freezed_annotation.dart:5`). La déclaration directe est légitime.
- Impact : dépendances mortes à maintenir (`cupertino_icons 2.0.0` est proposée en majeure), double jeu de règles de lint qui prête à confusion.
- Recommandation : retirer `cupertino_icons` et `flutter_lints`, puis relancer `dart analyze lib test` et `flutter test`.
- Effort : XS

### DEP-006 — Épinglages exacts non justifiés et retards de version
- Sévérité : Mineur / Domaine : dépendances / Statut : confirmé
- Preuve :
  - `mobile/pubspec.yaml:56-57` : `sqflite_common_ffi_web: 1.2.0` et `http: 1.6.0` sont épinglés exactement, contre `^` partout ailleurs. Ils ont été introduits par `8e57365` (`git log -S`), sans commentaire ni justification. `pub-outdated.log` : `sqflite_common_ffi_web *1.2.0 *1.2.0 1.2.2`. L'épinglage bloque un correctif de niveau patch.
  - Majeures en retard (`pub-outdated.log`) : `google_fonts 8.2.1 → 9.0.0`, `cupertino_icons 1.0.9 → 2.0.0` (inutilisé, DEP-005). npm : `@neon/env 1.6.2 → 2.1.3`.
  - « 66 upgradable dependencies are locked (in pubspec.lock) to older versions » (`pub-outdated.log`), dont des correctifs mineurs de `flutter_riverpod 3.5.0`, `go_router 18.1.4`, `sqflite 2.4.6` et `image 4.13.1`.
  - Le transitif de dev `riverpod_analyzer_utils` est verrouillé sur une préversion `1.0.0-dev.12`, alors que 1.0.0 est disponible.
  - npm (`npm-outdated.log`) : `playwright 1.62.1 → 1.65.1`, `prettier 3.9.10 → 3.10.1`. `esbuild 0.28.2` et `zod 4.6.7` (épinglés) ne sont pas listés, donc à jour.
  - Python : obsolescence non mesurable hors ligne (limite).
- Impact : dette de mise à jour modérée. L'épinglage exact empêche de recevoir des correctifs sans action manuelle.
- Recommandation : documenter en commentaire la raison des deux épinglages (compatibilité avec le `sqlite3.wasm` livré ? DEP-007) ou passer à `^`. Planifier un `flutter pub upgrade` mensuel suivi des tests, puis évaluer `google_fonts 9`.
- Effort : S

### DEP-007 — `sqlite3.wasm` téléchargé depuis GitHub à chaque build Vercel, sans contrôle d'intégrité
- Sévérité : Mineur / Domaine : chaîne d'approvisionnement / Statut : confirmé (comportement du paquet lu dans le cache pub)
- Preuve :
  - `scripts/build-universal-web.sh:16` : `dart run sqflite_common_ffi_web:setup`.
  - `~/.pub-cache/hosted/pub.dev/sqflite_common_ffi_web-1.2.0/lib/src/setup/setup_io.dart:227-229` : `var uri = sqlite3WasmReleaseUri; … var wasmBytes = await readBytes(uri); await File(wasmFile).writeAsBytes(wasmBytes);`. L'URL vient de `setup_common.dart:7-8` (`https://github.com/simolus3/sqlite3.dart/releases/download/$sqlite3WasmRelease`) avec `sqlite3_wasm_version.dart:2` `'sqlite3-3.6.0/sqlite3.wasm'`. Aucune vérification d'empreinte.
  - Le fichier téléchargé écrase `mobile/web/sqlite3.wasm`, qui est versionné (`git ls-files mobile/web` → `mobile/web/sqlite3.wasm`, `mobile/web/sqflite_sw.js`).
  - Aujourd'hui, les empreintes du fichier versionné et des deux sorties de build sont identiques : `sha256sum` → `13d3f11d…88a4` pour `mobile/web/sqlite3.wasm`, `mobile/build/web/sqlite3.wasm` et `web/universal-dist/sqlite3.wasm`.
  - Le paquet Dart `sqlite3` est verrouillé en `3.5.2` (`mobile/pubspec.lock`), alors que le wasm vient de la release `sqlite3-3.6.0`. La compatibilité est assurée par le choix de l'auteur de `sqflite_common_ffi_web` [déduit].
- Impact : le build dépend de la disponibilité de GitHub. Un binaire exécuté dans le navigateur de tous les utilisateurs web est récupéré sans contrôle d'intégrité, ce qui contourne `--enforce-lockfile`.
- Recommandation : le fichier étant déjà versionné, retirer l'étape `setup` du build Vercel, ou la lancer avec `--no-sqlite3-wasm` si l'option est exposée en CLI [à vérifier]. Vérifier l'empreinte SHA-256 dans le script et régénérer volontairement lors des montées de version.
- Effort : S

### DEP-008 — Versions déclarées dans `AGENTS.md` différentes des lockfiles
- Sévérité : Mineur / Domaine : documentation des dépendances / Statut : confirmé (recoupe OPS-009)
- Preuve : `AGENTS.md:10-12` comparé aux sources.

  | Déclaré (`AGENTS.md`) | Réel | Source |
  |---|---|---|
  | Freezed 3.1.0 | `freezed` (générateur) **4.0.2** ; `freezed_annotation` 3.1.0 | `mobile/pubspec.yaml:70`, `pubspec.lock` |
  | FastAPI 0.143.0 | 0.143.2 | `pip-freeze.txt` |
  | Python 3.13.5 | 3.12.3 | `pip-freeze.txt` (dernière ligne), `backend/CLAUDE.md:6` |
  | Node.js v22.23.2 | v22.17.1 ; `npm` du PATH 6.14.18 (nvm v14.21.3) | `node -v`, `which -a npm` |
  | Flutter 3.47.5 / Dart 3.13.4 | conformes | `~/development/flutter/bin/cache/flutter.version.json` |
  | Riverpod 3.4.3, GoRouter 18.0.1, sqflite 2.4.4, Zod 4.6.7, esbuild 0.28.2, SQLAlchemy 2.1.4 | conformes | `pubspec.lock`, `node_modules/*/package.json`, `pip-freeze.txt` |

  - `npm-audit.log:1` : npm 6.14.18 échoue sur `package-lock.json` en `lockfileVersion: 3` (`package-lock.json:3`).
  - `package.json` n'a pas de champ `engines`. Il n'y a ni `.nvmrc`, ni `.python-version`, ni `runtime.txt`.
- Impact : un contributeur ou un agent suit des versions fausses. Freezed 3 et 4 ont des API de génération différentes [déduit].
- Recommandation : corriger `AGENTS.md`, en distinguant `freezed_annotation` et `freezed`. Ajouter `"engines": {"node": "22.x"}` et `.nvmrc`, puis `.python-version`.
- Effort : XS

### DEP-009 — Aucune analyse de vulnérabilités automatisée ; dépendances Dart jamais scannées
- Sévérité : Mineur / Domaine : processus / Statut : confirmé
- Preuve :
  - Pas de CI (cf. OPS-001) et aucun script `audit` dans `package.json:4-13`.
  - Les audits npm et pip du 14/11 ont été lancés à la main pour cet audit. `pip-audit` a été installé ce jour-là (DEP-003).
  - Côté Dart, pub n'a pas de commande d'audit et aucun OSV-Scanner n'est installé localement : 169 paquets (`mobile/.dart_tool/package_config.json`) n'ont **aucune** couverture.
- Impact : une vulnérabilité publiée sur une dépendance (par exemple `flutter_secure_storage`, `http`, `image` qui décode des images utilisateurs) passerait inaperçue.
- Recommandation : ajouter en CI `npm audit --omit=dev`, `pip-audit` sur le lockfile backend, et `osv-scanner --lockfile mobile/pubspec.lock --lockfile package-lock.json`. Activer Dependabot ou Renovate sur GitHub (écosystèmes `pub`, `npm`, `pip`).
- Effort : S

### DEP-010 — Le projet n'a pas de licence
- Sévérité : Mineur / Domaine : conformité / Statut : confirmé
- Preuve : `ls LICENSE* COPYING*` à la racine et dans `mobile/` → absents. `package.json:3` `"private": true`, `mobile/pubspec.yaml:5` `publish_to: 'none'`. `mobile/pubspec.yaml:2` garde la description générée `"A new Flutter project."`.
- Impact : sans licence, le code est sous droits réservés par défaut. C'est acceptable pour un produit privé, mais rien ne le dit explicitement : statut ambigu pour les contributeurs et les agents externes. La description par défaut apparaît dans les métadonnées.
- Recommandation : ajouter un `LICENSE` (propriétaire, « tous droits réservés », ou licence libre si c'est l'intention) et une description réelle dans `pubspec.yaml`.
- Effort : XS

### DEP-011 — L'app mobile n'expose pas les licences tierces
- Sévérité : Mineur / Domaine : conformité / Statut : confirmé
- Preuve :
  - `grep -rn -E "showLicensePage|LicensePage|AboutListTile|showAboutDialog" mobile/lib` : aucun résultat.
  - Le build web embarque `mobile/build/web/assets/NOTICES` (1,4 Mo, 1 698 séparateurs), généré par Flutter, mais aucun écran n'y donne accès.
  - Le portail copie bien la licence de Zod (`scripts/vendor-zod.mjs:21-24` → `web/vendor/ZOD-LICENSE.txt`, inclus via `vendor` dans `scripts/app.mjs:22`).
  - Les polices Poppins sont livrées avec `OFL.txt` (`mobile/assets/google_fonts/`, `web/fonts/`).
- Impact : les licences BSD et MIT, majoritaires dans les dépendances Dart, demandent de reproduire la notice dans la documentation ou les autres éléments fournis avec la distribution binaire. Un écran « Licences » est l'usage attendu sur les stores [déduit].
- Recommandation : ajouter une entrée « Licences » dans les réglages, qui appelle `showLicensePage` (le registre Flutter est alimenté automatiquement).
- Effort : XS

### DEP-012 — Copyleft faible présent, aucune GPL ni AGPL
- Sévérité : Info / Domaine : licences / Statut : confirmé
- Preuve :
  - **Backend** (champ `License-Expression` des `METADATA` du venv) :
    - `psycopg` et `psycopg-binary` 3.3.6 : `LGPL-3.0-only`. C'est une dépendance de production : `requirements.txt:4`, et `backend/app/models.py:33-35` réécrit les URL en `postgresql+psycopg://`.
    - `certifi` : `MPL-2.0`, en dev ou audit seulement (DEP-003).
    - Le reste est MIT, BSD, Apache-2.0 ou PSF.
  - **npm** (`package-lock.json`, 64 paquets) : MIT (55), Apache-2.0 (5 : `@neon/*`, `playwright`), ISC (4). Aucun copyleft.
  - **Dart** (fichiers `LICENSE` de `~/.pub-cache` pour les 169 paquets de `package_config.json`) : toutes les dépendances directes sont MIT, BSD-2/3 ou Apache-2.0 (`image_picker`). Seule exception transitive : `dbus 0.8.0`, en **MPL-2.0** (`~/.pub-cache/hosted/pub.dev/dbus-0.8.0/LICENSE:1`), tiré par `file_picker_linux` et présent dans `NOTICES:2758-2759`.
  - Pas de licence « inconnue ». Les paquets SDK (`flutter_localizations`, `flutter_test`, `flutter_web_plugins`) n'ont pas de fichier propre mais relèvent de la licence BSD de Flutter.
- Impact : LGPL côté serveur sans distribution du binaire, donc obligations limitées [déduit]. La MPL-2.0 de `dbus` est un copyleft par fichier, qui ne concerne qu'une éventuelle cible Linux de bureau. Aucune contrainte bloquante.
- Recommandation : aucune action immédiate ; conserver ce relevé et le refaire à chaque ajout de dépendance (cf. DEP-009).

### DEP-013 — SDK Flutter cloné par tag sans vérification de révision
- Sévérité : Info / Domaine : outillage / Statut : confirmé
- Preuve : `scripts/build-universal-web.sh:5-11`. Si `flutter` est absent, le script lance `git clone --depth 1 --branch 3.47.5 https://github.com/flutter/flutter.git "$SDK"`. Le tag est épinglé (bon point), mais la révision n'est pas contrôlée. Le SDK local est en `frameworkRevision 6a19cca56475dbfba1478ee68d7bd0c2ef891da1` (`flutter.version.json`).
- Impact : faible. Un tag est mutable en théorie, et le moteur ainsi que Dart sont ensuite téléchargés par Flutter.
- Recommandation : après le clone, vérifier `git -C "$SDK" rev-parse HEAD` contre la révision attendue.
- Effort : XS

## Hypothèses à vérifier

1. **Version d'`opentelemetry-api` réellement installée sur Render** et gravité de CVE-2026-126360 (DEP-002), à lire dans les journaux de build Render.
2. **Licence de la police `remix.ttf`** livrée par le paquet `remixicon 4.9.3`. Le paquet Dart se déclare MIT (`LICENSE`, `README.md:76-78`), mais la police vient du projet amont Remix Icon, dont la licence a pu évoluer (licence maison) [non vérifiable hors ligne]. Vérifier la licence amont de la version de la police.
3. **Abandon de dépendances** : non vérifiable hors ligne. À contrôler sur pub.dev et PyPI : dates de dernière publication, notamment `remixicon`, `sqflite_common_ffi_web` et `file_picker`.
4. **Vulnérabilités Dart** : à mesurer avec `osv-scanner --lockfile mobile/pubspec.lock` (DEP-009).
5. **Pourquoi `http` et `sqflite_common_ffi_web` sont épinglés exactement** (DEP-006) : le message de `8e57365` ne le dit pas.
6. Ce que `pip-audit -r requirements-dev.txt` a réellement résolu (DEP-001) : le journal n'affiche pas les versions.

## Points positifs (Info)

- `npm audit` : 0 vulnérabilité sur 64 paquets (`npm-audit.json`, `metadata.vulnerabilities.total = 0`).
- `package-lock.json` (v3, empreintes d'intégrité) et `mobile/pubspec.lock` sont versionnés. Le build Vercel les applique strictement : `vercel.json:4` `npm ci`, `scripts/build-universal-web.sh:15` `flutter pub get --enforce-lockfile`.
- **Vendorisation de Zod reproductible** : `web/vendor/zod.mjs` régénéré dans le scratchpad avec la configuration de `scripts/vendor-zod.mjs:6-20` (esbuild 0.28.2, zod 4.6.7 de `node_modules`) donne la **même empreinte SHA-256** (`3aef20fb…3e43`) que le fichier versionné. La licence de Zod est copiée à côté. Seule réserve : le bundle ne porte pas de bannière de version.
- `zod` et `esbuild` sont épinglés exactement. Ce sont les deux paquets qui produisent du code livré au navigateur.
- Le SDK Flutter local et celui du build Vercel sont alignés sur 3.47.5 / Dart 3.13.4.
- Polices Poppins livrées avec leur licence OFL.

## Renvois vers d'autres domaines

- Absence de CI, de lockfile backend et de version Python fixée : domaine DevOps, OPS-001, OPS-005, OPS-009, OPS-018 (`docs/audit/10-devops.md`).
- `google_fonts` utilisé dans 23 fichiers : vérifier qu'aucun téléchargement de police depuis Google n'a lieu à l'exécution (vie privée et hors-ligne), domaine performance / Flutter web (H).
- Décodage d'images utilisateurs par `image` (`lib/core/media/player_photo.dart:8`) : surface d'entrée à couvrir côté sécurité (domaine sécurité).

## Vérification croisée (Phase 4, 14/11/2026)

Tous les constats Critique et Majeur de ce rapport ont été relus et **confirmés** (aucun retrait, aucune requalification). Verdicts : [raw/verification-phase4.md](raw/verification-phase4.md).
