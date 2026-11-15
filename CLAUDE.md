@AGENTS.md

# Espace de travail Statoo (monorepo)

`statoo-5v5/` est **un seul dépôt git** (`origin` : `git@github.com:NorrisAkg/statoo-5v5.git`, branche de travail `staging`). Il regroupe trois applications et la documentation transverse. Aucun sous-dossier n'est un dépôt indépendant.

Les consignes persistantes (TDD, revue de code, parité web-mobile, design) sont dans `AGENTS.md`, importé ci-dessus. Elles priment.

## Applications

| Dossier | Rôle | Détails |
|---|---|---|
| `mobile/` | App Flutter : Android, iOS et **Flutter web** (`lib/main_web.dart`), SQLite local. Référence fonctionnelle. | [mobile/CLAUDE.md](mobile/CLAUDE.md) |
| `backend/` | API FastAPI des groupes partagés (comptes, rôles, synchro, finances). Neon PostgreSQL sur Render. | [backend/CLAUDE.md](backend/CLAUDE.md) |
| `web/` | Portail JavaScript historique (`/portal/`), tests Playwright de parité et sortie du packaging web | [web/CLAUDE.md](web/CLAUDE.md) |
| `scripts/` | Build (`app.mjs`, `build-universal-web.sh`, `package-universal-web.mjs`, `vendor-zod.mjs`) et sondes en ligne | — |
| `docs/` | Documentation transverse | voir plus bas |

Les dossiers `android/` et `ios/` à la racine ne contiennent que des artefacts générés, versionnés par erreur. Les projets natifs sont dans `mobile/android` et `mobile/ios`.

Déploiement, décrit sans être déclenché par le dépôt :
- `vercel.json` publie `web/universal-dist`, c'est-à-dire Flutter web plus `/portal/`.
- `render.yaml` déploie le service `statoo-api` depuis `backend/`.
- `neon.ts` contient la politique des branches Neon.

## Commandes globales (depuis la racine)

```bash
npm run test:web                 # tests unitaires du portail et du packaging (72)
npm run build:web                # tests unitaires + portail dans web/dist
npm run build                    # backend compileall + pytest + build:web
npm start                        # API + portail sur http://127.0.0.1:8000/portal/
bash scripts/build-universal-web.sh   # build Vercel complet -> web/universal-dist
```

Les commandes propres à chaque application sont dans les `CLAUDE.md` des dossiers.

Particularités de l'environnement :
- Flutter est installé dans `~/development/flutter/bin`, hors du PATH bash.
- Le venv Python est dans `backend/.venv/bin`. Les docs historiques citent les chemins Windows `.venv/Scripts`.

## État vérifié le 14/11/2026

| Commande | Résultat |
|---|---|
| `flutter test` (mobile) | 1482/1482 sur `fix/mobile-red-tests` (15/11) ; `staging` (`2a9a3c7`) : 1333 OK, 16 KO |
| `dart analyze lib test` | 0 erreur, 71 infos |
| `.venv/bin/pytest` (backend) | 442 OK |
| `npm run test:web` | 72 OK (15/11) |
| `npm run build:web` | OK |

Il n'y a aucune CI.

## Conventions transverses

- Le français est la langue de l'UI, des messages d'erreur API et de la documentation.
- Commits au format Conventional Commits avec scope et identifiant de backlog, par exemple `feat(auth): … [ACCESS-02]`.
- Tout est scopé par groupe : `team_id` côté mobile, `group_id` côté API.
- Les règles sport, finance et rôles existent en **trois copies** : `mobile/lib/features/sessions/domain/`, `backend/app/main.py` et `web/domain.mjs`. Toute modification doit aligner les trois et passer les tests de parité.
- Sans `--dart-define=STATOO_API`, Flutter vise **l'API de production**.
- Le skill de commit du projet est dans `.agents/skills/commit/`. Les agents Claude du projet (`statoo-reviewer`, `design-fidelity`) et les skills (`db-migration`, `new-feature`) sont dans `.claude/`.

## Règles git communes

- Lecture libre : `status`, `log`, `diff`, `branch`, `remote`, `show`.
- Ne jamais faire de `commit`, `add`, `push`, `pull`, `fetch`, `checkout`, `stash`, `reset`, `rebase`, `merge`, ni créer de branche, sans demande explicite.
- Branches : `staging` pour l'intégration, `feat/<ID>-<slug>` pour les lots. `origin/main` (août 2026, ancienne pile Nuxt/Capacitor) est en retard sur `staging`.
- Ne jamais ouvrir ni versionner de fichiers `.env*` (sauf `.env.example`), de clés ou de `CLAUDE.local.md`.
- Ne lancer aucune commande qui écrit dans Neon ou en production (`scripts/neon_smoke.py`, e2e reliés à l'API publique) sans accord.

## Documentation

- [docs/onboarding/etat-des-lieux.md](docs/onboarding/etat-des-lieux.md) : synthèse, risques, actions suggérées.
- [docs/architecture/vue-densemble.md](docs/architecture/vue-densemble.md) : schéma et contrats entre applications.
- [docs/domain/glossaire.md](docs/domain/glossaire.md) : vocabulaire métier.
- [docs/onboarding/questions-ouvertes.md](docs/onboarding/questions-ouvertes.md) : points à arbitrer.
- Références existantes :
  - `docs/design-system.md` (UI) ;
  - `docs/outbox-sync.md` ;
  - `docs/parite-web-mobile.md` ;
  - `docs/shared-group-and-finance.md` ;
  - `docs/ai/BACKLOG.md` (lots ACCESS-xx, FEAT-xx).
- Documents historiques (12/10), partiellement obsolètes : `docs/architecture.md`, `docs/business-rules.md`, `docs/decisions-and-risks.md`, `docs/ai/DIAGNOSTIC.md` (chiffres de tests dépassés).
