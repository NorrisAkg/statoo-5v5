# web/ — portail historique, tests de parité et packaging web

Ce fichier complète le `CLAUDE.md` et l'`AGENTS.md` racine. L'analyse détaillée est dans [docs/architecture/analyse.md](docs/architecture/analyse.md).

**À savoir :** la cible web principale est **Flutter web** (`mobile/lib/main_web.dart`). Le dossier `web/` contient le portail JavaScript historique, servi sous `/portal/` et gelé depuis le 17/10, ainsi que les tests Playwright de parité et le résultat du packaging (`web/dist`, `web/universal-dist`, ignorés par git).

## Stack
- JavaScript ES modules sans framework, Zod 4.6.7 vendorisé (`vendor/zod.mjs`), service worker `sw.js`.
- Node 22 (`/usr/local/bin/node`). Le `npm` du PATH vient de nvm en v14 : il fonctionne pour les scripts ci-dessous.
- Playwright avec Google Chrome installé (`channel: "chrome"`).

## Commandes (depuis la racine du monorepo)
```bash
npm run test:web          # 15/11 : 72/72, aucun serveur requis
npm run build:web         # tests unitaires puis copie dans web/dist/ — OK le 14/11
npm run format:web        # Prettier --write ; 14/11 : 14 fichiers non conformes en --check
npm run vendor:web        # régénère vendor/zod.mjs
bash scripts/build-universal-web.sh   # build Vercel complet (Flutter web + portail) -> web/universal-dist
```
- **e2e (`test:web:browser`, `test:web:parity`)** : il faut lancer les serveurs à la main. `web/tests/serve.py` écoute sur 18085, `universal-dist` sur 18087 et `web/tests/serve-parity.py` sur 18088, tous en SQLite mémoire. Les commandes du README utilisent `backend/.venv/Scripts/python.exe` ; sous Linux, c'est `backend/.venv/bin/python`.
- Plusieurs e2e n'ont pas de script npm (voir l'analyse, §7).

## Conventions
- Toute règle métier vient du mobile (référence) et du backend. `domain.mjs` et `summary.mjs` en sont des copies : les aligner.
- Après chaque livraison du portail, changer à la main la version du cache dans `sw.js`, ainsi que le test `tests/pwa.test.mjs`.
- Les tests unitaires bloquent le build Vercel.

## Interdits
- Déployer : `vercel.json` et `render.yaml` déclenchent les builds distants.
- Lancer les e2e `live-integration`, `group-entry`, `collective-access` ou `manager-access` sans vérifier l'API cible : elles peuvent créer des groupes en production.
- Ajouter une fonctionnalité au portail sans décision produit, puisqu'il est gelé.
