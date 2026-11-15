# Analyse de l'API Statoo (`backend/`)

État constaté le 14/11/2026, branche `staging`, commit `2a9a3c7`. Lecture du code, sans exécution contre une base réelle. Sauf mention contraire, les chemins sont relatifs à `backend/`. Les déductions sont marquées **[déduit]**.

## 1. Architecture

- **6 modules, environ 1 160 lignes.** `app/main.py` (996 l.) contient presque tout : schémas Pydantic (l.46-184), helpers métier (l.187-241), fabrique `create_app` avec toutes les routes en closures (l.244-881) et validateurs sport (l.884-993).
- **Modules satellites.** `finance.py` (modèle `Point`, `totals`), `models.py` (3 tables, fabrique d'engine), `security.py` (PBKDF2, condensé des jetons), `portal.py` (fichiers statiques en liste blanche), `config.py` (dotenv).
- **Style.** Script transactionnel dans un module unique, sans routers, services ni repositories. Les dépendances FastAPI (`db`, `authenticate`, `scoped`, `require`) servent de garde. L'état métier est un dict JSON manipulé directement.
- **Dépendances.** `main` importe `finance`, `config`, `models`, `portal` et `security`, aucun cycle. `scripts/neon_smoke.py` importe `app.config` et `app.models` par `sys.path`.

## 2. Points d'entrée

- **Démarrage.** `create_app(url=None)` (main.py:244) produit l'instance de module `app = create_app()` (main.py:996), lancée par `uvicorn app.main:app` (`render.yaml`).
- **Environnement.** `load_environment()` charge `<racine>/.env.local` puis `<racine>/.env` sans écraser les variables existantes (config.py:6-10).
  - Sur Render, l'absence de `DATABASE_URL` lève une erreur (main.py:246-247).
  - Repli : `sqlite:///statoo.db`, relatif au répertoire courant (main.py:248).
- **Lifespan.** `Base.metadata.create_all` sur `DATABASE_URL_UNPOOLED` si cette variable est définie, sinon sur l'engine principal (main.py:249-261). **Aucune migration.**
- **Middlewares et routes publiques.**
  - CORS (l.276-281) : `CORS_ORIGINS`, plus 4 origines localhost uniquement si `RENDER_GIT_BRANCH=staging`.
  - Erreurs de validation : 422 générique, sans écho des valeurs (l.265-267).
  - `/portal/config.json` (l.268) et montage `/portal` sur `web/` en liste blanche (l.273-275, portal.py).
  - `/health` (l.345). `/docs` et `/openapi.json` restent publics.
- **Variables lues (noms uniquement).** `DATABASE_URL`, `DATABASE_URL_UNPOOLED`, `RENDER`, `RENDER_GIT_BRANCH`, `CORS_ORIGINS`, `STATOO_PUBLIC_API_URL`, plus `PORT` et `PYTHON` dans les scripts.

## 3. Modèle de données

**Tables** (models.py) :
- `groups(id PK, state JSON)` ;
- `tokens(digest PK, group_id FK, account_id, expires_at)` ;
- `registration_operations(id PK, group_id FK, fingerprint)`.

Aucun index secondaire, aucune FK sur `account_id`.

**Agrégat JSON par groupe** (créé à main.py:395-397) : `name`, `short_name`, `roles`, `accounts[]` (hash du mot de passe, rôles, `shared`, `recovery`), `members[]`, `documents{"<domaine>:<occurrence>"}` (owner, revision, generation, payload, history, candidates), `operations{}`, `audit[]`, `opening`, `opening_proposal`, `obligations{}`, `financial_settings`, `sport_settings`, `active_session_id`.

**Écriture.** Chaque requête authentifiée fait un `deepcopy` de l'état (l.309). La mutation se fait sur la copie, puis `group.state = state` réécrit **tout le blob**.

**Verrous.**
- `SELECT … FOR UPDATE` sur la ligne du groupe (l.308), y compris pour les GET.
- En plus, un `threading.Lock()` **global et inconditionnel** dans `db()` (l.284, 298-300) : le commentaire parle de SQLite, mais le verrou s'applique aussi sur PostgreSQL. Il sérialise toutes les requêtes du processus, tous groupes confondus.
  - **Corrigé le 14/11/2026 (PERF-001, non commité à cette date)** : verrou retiré sur PostgreSQL ; sur SQLite, verrou `asyncio` qui n'occupe aucun thread. Voir `docs/audit/08-performance.md` et `backend/tests/test_concurrency_deadlock.py`.

## 4. Domaine métier

**Rôles** (l.30-33) : `ADMIN`, `PDT`, `VP`, `TR`, `TGA`, `SG`, `SGA`, `CENSOR`, `MEMBER`.
- `SINGULAR` = tous sauf `ADMIN` et `MEMBER`. Les co-admins sont donc possibles.
- Auteurs par domaine : `sport` = ADMIN, PDT, VP, SG, SGA ; `finance` = TR, TGA.
- Un rôle singulier ne s'attribue que par transfert avec motif (l.640-645).
- ADMIN, PDT et TR sont obligatoires (l.651-653). PDT et TR doivent être attribués avant toute synchro (l.340-343).

**Documents versionnés** (`/sync`, l.752-825).
- Si l'auteur diffère du propriétaire ou si la révision est périmée, la version devient une **candidature en conflit**.
- PDT ou VP arbitre (`/resolve`, l.827) et peut transférer la propriété (`/transfer`, l.860).
- Une correction exige un motif. L'historique est conservé.

**Sport** (`validate_sport`, l.903-993).
- `team_id` doit valoir l'id du groupe.
- Équipes équilibrées à ±1, sauf `allow_uneven_teams`.
- Minimum de joueurs `sport_settings.min_players_per_session` (2 à 30, défaut 6).
- Résultat cohérent avec le score (classique) ou les victoires (tournoi). Somme des buts + buts non attribués = score. Passes ≤ buts.
- Une seule séance active : `apply_sport_lifecycle` (l.884-900), sinon 409 avec `detail = {code: 'active_session_conflict', …}`.

**Finance** (finance.py, main.py:216-241, 720-750).
- Montants entiers de 0 à 10¹². Le point couvre exactement le roster de l'échéance.
- À la première acceptation d'une séance, une **obligation** est créée au taux courant (l.816-820).
- Annulation sportive refusée s'il y a des encaissements (l.811-815).
- Les soldes d'ouverture sont proposés par TR/TGA et approuvés à l'identique par PDT/VP.
- `late_penalty` est stocké mais n'est jamais utilisé dans les calculs.

## 5. Authentification, autorisation, multi-tenant

- **Mots de passe.** PBKDF2-SHA256, 600 000 itérations, sel de 16 octets (security.py). Politique : 8 à 200 caractères, minuscule + majuscule + chiffre, différent de l'identifiant (l.198-210).
- **Jetons.** `token_urlsafe(32)`, seul le SHA-256 est stocké. Durée fixe de **30 jours**. Ni purge ni révocation globale.
- **Identifiants.** Unicité via `strip().casefold()` (l.430).
- **Compte collectif** (`shared: true`) : lecture seule, `require` refuse tout compte partagé (l.321-323).
- **Code de récupération** (`/auth/recover`, l.443-504).
  - Réservé à un ADMIN individuel. Hash factice si le compte est inconnu.
  - Throttling : 10/min/IP et 5/15 min par compte.
  - Rotation obligatoire après usage. Le code est perdu si le rôle ADMIN est retiré.
- **Réinitialisation inter-admin** (`POST /accounts/{id}/password`, l.577) : un ADMIN peut réinitialiser tout compte individuel sauf le sien.
- **Isolation.** Le jeton porte un `group_id`. `scoped` compare avec le chemin et renvoie 403 sinon (l.315-319). Les comptes ciblés sont toujours cherchés dans le groupe du jeton. **Aucune faille d'isolation inter-groupes trouvée.**

## 6. Endpoints exposés

| Méthode | Chemin | Rôle |
|---|---|---|
| GET | `/health`, `/portal/config.json`, `/portal/*`, `/docs` | public |
| POST | `/groups` (201, idempotent par `operation_id`) | public |
| POST | `/auth/login` (20/min/IP), `/auth/recover` | public |
| POST | `/auth/logout` | authentifié |
| GET | `/groups/{id}` (snapshot filtré par rôle) | tout compte du groupe |
| POST | `/groups/{id}/accounts` | ADMIN |
| POST | `/groups/{id}/accounts/{acc}/password/verify` · `/password` | ADMIN |
| POST | `/groups/{id}/account/password` | compte individuel |
| PUT | `/groups/{id}/account/recovery-code` | ADMIN individuel |
| PUT | `/groups/{id}/accounts/{acc}/roles` | ADMIN |
| PUT | `/groups/{id}/members` | ADMIN |
| POST/PUT | `/groups/{id}/shared-access/verify` · `/shared-access` | ADMIN |
| PUT | `/groups/{id}/financial-settings` | ADMIN, TR, TGA |
| PUT | `/groups/{id}/sport-settings` | ADMIN |
| POST | `/groups/{id}/opening` · `/opening/approve` | TR/TGA · PDT/VP |
| POST | `/groups/{id}/sync` | auteurs du domaine |
| POST | `/groups/{id}/documents/{domain}/{occ}/resolve` · `/transfer` | PDT/VP · propriétaire ou PDT/VP |

**Erreurs.** `{"detail": "message FR"}`, sauf `active_session_conflict`, dont `detail` est un objet (format incohérent).
- 400 : mot de passe vérifié incorrect.
- 401, 403, 404.
- 409 : conflit métier ou opération réutilisée.
- 422 : validation.
- 429 : throttling.
- 503 : collision d'id de groupe.

**Idempotence.**
- `/sync` : `operation_id` + empreinte SHA-256 du corps (l.757-762).
- `/groups` : table `registration_operations` et empreinte PBKDF2.

**Versioning.** Aucun (ni `/v1`, ni en-tête). La compatibilité repose sur la tolérance des champs « legacy ».

## 7. Tests

- 19 fichiers, **442 tests** passés en 8 min 12 s le 14/11/2026 (`.venv/bin/pytest`). C'est plus que les 124 fonctions `test_*`, grâce aux paramétrages.
- **Isolation de la base, confirmée.** Chaque test construit `create_app('sqlite:///:memory:')`. Il n'y a pas de `conftest.py`.
  - Réserve : importer `app.main` exécute `create_app()` au niveau module (l.996). Cela charge `.env*` et crée un engine paresseux sur `DATABASE_URL`, mais aucune connexion n'est ouverte.
- **Non couvert [déduit par grep].**
  - Expiration des jetons, `/auth/logout`.
  - PostgreSQL et concurrence réelle.
  - `resolve` finance avec obligations, résolution vers une version CANCELLED.
  - `late_penalty`, payloads volumineux, approbation de l'ouverture par son propre proposeur.

## 8. Dette

- Aucun TODO ni FIXME.
- **Bug confirmé par lecture.** `resolve` (l.827-858) ne met pas à jour `obligations[occ].cancelled` comme le fait `/sync` (l.820), et recalcule les totaux finance sans les obligations.
- Code inatteignable (l.811-815). Duplications : throttling ×3, révocation de jetons ×4, `non_blank_username` ×3, validation des membres ×2.
- **`scripts/neon_smoke.py` est obsolète.** Il envoie un `group_id` que le serveur ignore (main.py:399-402 génère `#NNNNNNNN`). L'assertion de lecture échouerait. Son nettoyage supprime un id inexistant : **le groupe réellement créé resterait dans Neon**.
- **Versions.** Depuis le 15/11/2026 (DEP-001), `requirements*.txt` déclarent les bornes et `requirements.lock` / `requirements-dev.lock` fixent les versions avec empreintes, pour toutes les plateformes. Python 3.12.3 est fixé sur Render. Avant cette date, `requirements*.txt` ne fixait que des bornes.

## 9. Risques

- **Sécurité.**
  - Aucune limite de taille de corps : `members: list[dict]` et `payload` sport libres, `operation_id` sans borne.
  - `POST /groups` sans rate limit, alors qu'il coûte environ 4 PBKDF2.
  - Throttling en mémoire par processus, sur `request.client.host`. Derrière le proxy Render, toutes les IP seraient probablement identiques **[déduit]**.
  - Énumération possible par le temps de réponse au login (pas de hash factice, l.432).
  - Le snapshot expose `audit` et les identifiants des responsables au compte collectif.
  - Pas de « quatre yeux » : un compte TGA+VP peut proposer **et** approuver l'ouverture.
- **Performance.**
  - `deepcopy` de tout l'agrégat à chaque requête. `audit`, `operations` et `history` croissent sans borne.
  - Verrou global plus PBKDF2 : vecteur simple de déni de service.
- **Fragilités.**
  - Aucune migration de schéma.
  - Erreurs 500 possibles : reprise d'inscription avec admin renommé (`StopIteration`, l.366), jeton d'un groupe supprimé.
  - Moment du commit avec les dépendances `yield` de FastAPI 0.143 : à vérifier **[déduit]**.
