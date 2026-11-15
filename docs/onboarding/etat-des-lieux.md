# État des lieux Statoo — 14/11/2026

Branche `staging` (`2a9a3c7`, à jour avec `origin/staging`). Ce document est une synthèse exécutive. Les détails sont dans [la vue d'ensemble](../architecture/vue-densemble.md), [le glossaire](../domain/glossaire.md), [les questions ouvertes](questions-ouvertes.md) et les fichiers `*/docs/architecture/analyse.md`.

## Le produit

Statoo sert à gérer un groupe d'amis qui joue au foot à 5. On y enregistre les séances (classiques ou tournoi à 3 équipes), les compositions, les buts, passes et cartons, le classement, le joueur du mois et la trésorerie (cotisations, pénalités, dépenses).

L'app fonctionne **d'abord en local** (SQLite). Un groupe peut devenir **« partagé »** via une API. Il dispose alors de comptes et de rôles de bureau (président, trésorier, etc.) et d'une synchronisation versionnée avec arbitrage des conflits.

## Structure

Il s'agit d'**un seul dépôt git** (`git@github.com:NorrisAkg/statoo-5v5.git`) qui contient trois applications. Ce ne sont pas des dépôts séparés.

| App | État | Tests vérifiés le 14/11 |
|---|---|---|
| `mobile/` Flutter (Android, iOS, web) | Actif. Livraisons ACCESS-01/02/03/07. Export CSV (FEAT-01) en cours, fichiers non suivis et non branchés. | `flutter test` sur `staging` : **1333 OK / 16 KO** ; sur `fix/mobile-red-tests` : 1351/1351. `dart analyze` : 0 erreur, 71 infos. |
| `backend/` FastAPI | Actif. Code dans un seul fichier, agrégat JSON, aucune migration. | `pytest` : **442/442** (≈ 8 min) |
| `web/` portail JS + packaging | Portail gelé depuis le 17/10. Le packaging Vercel est actif. | `test:web` : **61/61**. `build:web` OK. Prettier : 14 fichiers non conformes. |

- Il n'y a **aucune CI**. Le seul garde-fou automatique : Vercel exécute les tests unitaires web à chaque build.
- `origin/main` (`e6a0fc7`, août) correspond à l'ancienne pile Nuxt/Capacitor : il est obsolète par rapport à `staging`.

## Risques majeurs

1. **La documentation affirme une suite mobile verte, elle ne l'est pas.** `AGENTS.md` annonce « 836 tests » et `docs/ai/DIAGNOSTIC.md` « 836/836, 100 % ». La mesure donne 1349 tests, dont 16 en échec :
   - 7 échecs viennent de doublures de test qui n'ont pas de getter `isOpen` (probablement depuis PERF-01 [déduit]) ;
   - 5 viennent d'un vrai bug produit : 82 lignes de texte mal encodé (« DÃ©tail sÃ©ance ») et un BOM dans `session_detail_screen.dart` depuis `4b3ed6d` ;
   - 1 test visait un sélecteur de carton devenu du code mort (`80d2a00`), et 1 test lançait une vraie requête SQLite sous FakeAsync (`493d62d`).
   - Le 14/11, tout a été corrigé sur la branche `fix/mobile-red-tests` (non commité). Un garde-fou anti-mauvais encodage y est ajouté : `test/core/source_encoding_test.dart`.
2. **Les URL par défaut pointent sur la production.** `STATOO_API` vaut par défaut `statoo-api.onrender.com` (code Flutter et script de build). Les e2e non scriptés et `scripts/neon_smoke.py` (obsolète, il laisse un groupe dans Neon) peuvent écrire en production.
3. **Concurrence et capacité du backend.** Un verrou `threading.Lock` global sérialise toutes les requêtes. L'agrégat JSON est entièrement copié à chaque requête et grossit sans limite. Il n'y a ni limite de taille de corps, ni rate limit sur `POST /groups`. Le throttling se fait par IP, alors que derrière le proxy Render tous les clients ont probablement la même IP [déduit].
4. **Les règles métier existent en trois copies** (Dart, Python, JS), sans contrat partagé ni versioning d'API. Un bug serveur a été confirmé par lecture : `resolve` n'applique pas la mise à jour des `obligations`.
5. **Des artefacts générés sont versionnés.** `android/` et `ios/` à la racine (caches Gradle d'environ 9,7 Mo, `local.properties` avec chemins locaux) ont été ajoutés dans `493d62d`. `docs/` contient environ 400 journaux `.txt` d'exécution de tests.

## Actions suggérées (aucune n'a été faite)

- Corriger ou requalifier les 16 tests mobiles en échec, puis mettre à jour les chiffres d'`AGENTS.md` et de `docs/ai/DIAGNOSTIC.md`.
- Retirer `android/` et `ios/` de la racine de l'index git, puis les ajouter au `.gitignore`.
- Mettre en place une CI minimale : `dart analyze`, `flutter test`, `pytest`, `npm run test:web`.
- Pointer le défaut de `STATOO_API` sur une valeur non productive, ou rendre la variable obligatoire. Corriger ou supprimer `scripts/neon_smoke.py`.
- Retirer le verrou global sur PostgreSQL. Ajouter une limite de corps et un rate limit sur l'inscription. Configurer `--proxy-headers` sur Render.
- Décider du sort du portail historique (voir les questions ouvertes).
- Ranger `docs/` : archiver les journaux `.txt` et les fichiers `tdd-*`. Les documents généraux restés à la racine (`README.md`, `reflexions.md`, `GEMINI.md`, `specs/`, `audits/`) pourraient migrer vers `docs/`, sous réserve d'accord.
