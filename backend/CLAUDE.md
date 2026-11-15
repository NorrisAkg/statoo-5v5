# backend/ — API FastAPI Statoo

Ce fichier complète le `CLAUDE.md` et l'`AGENTS.md` racine. L'analyse détaillée est dans [docs/architecture/analyse.md](docs/architecture/analyse.md).

## Stack (venv vérifié le 14/11/2026)
- Python 3.12.3. Versions verrouillées (15/11) : FastAPI 0.163.0, Starlette 1.10, SQLAlchemy 2.1.8, psycopg 3.3, uvicorn 0.54, python-dotenv. Le `.venv` local date d'avant le lock (FastAPI 0.143.2, opentelemetry-api 1.45.1 vulnérable) : le recréer avec la commande ci-dessous.
- `requirements*.txt` déclarent les bornes ; versions réelles dans `requirements.lock` (prod, Render) et `requirements-dev.lock`, avec empreintes (DEP-001, 15/11). Python fixé à 3.12.3 sur Render (`PYTHON_VERSION`). Régénération : `backend/README.md`.
- PostgreSQL Neon en hébergement (Render, voir `render.yaml`). Ailleurs, SQLite `sqlite:///statoo.db`.

## Commandes (depuis `backend/`, Linux)
```bash
python3.12 -m venv .venv && .venv/bin/pip install --require-hashes -r requirements-dev.lock
.venv/bin/pytest -q                           # 14/11 : 442 réussis en ~8 min, SQLite en mémoire uniquement
.venv/bin/uvicorn app.main:app --reload        # API locale + /docs + /portal/
```
- Les README utilisent les chemins Windows `.venv/Scripts/...`. Sous Linux, c'est `.venv/bin/...`.
- Depuis la racine, `npm start` lance l'API et le portail sur `127.0.0.1:8000`.

## Architecture locale
- `app/main.py` : schémas Pydantic, toutes les routes (closures dans `create_app`) et les validateurs sport.
- `app/finance.py` : point financier et `totals`. `app/models.py` : tables `groups(state JSON)`, `tokens`, `registration_operations`. `app/security.py` : PBKDF2 et SHA-256 des jetons. `app/portal.py` : liste blanche de `/portal/`.
- Chaque groupe est **un agrégat JSON** verrouillé par `FOR UPDATE`. Sur SQLite (dev, tests), la dépendance `db()` sérialise en plus les sessions avec un verrou `asyncio` (connexion partagée) ; sur PostgreSQL il n'y a aucun verrou applicatif (correctif PERF-001 du 14/11 : l'ancien `threading.Lock` global gelait l'API sous ~40 requêtes concurrentes). Les compteurs de tentatives sont protégés par un verrou court `counters`. Il n'y a **aucune migration** : `create_all` s'exécute au démarrage.
- Tests de concurrence : `tests/test_concurrency_deadlock.py` démarre un vrai uvicorn sur un port éphémère (un `TestClient` ne reproduit pas l'épuisement du pool de threads). Pour simuler PostgreSQL sans verrou, `monkeypatch.setattr("app.main._serialize_sessions", lambda engine: False)` sur une base SQLite fichier.
- Variables d'environnement (noms uniquement) : `DATABASE_URL`, `DATABASE_URL_UNPOOLED`, `CORS_ORIGINS`, `STATOO_PUBLIC_API_URL`, `RENDER`, `RENDER_GIT_BRANCH`, `STATOO_TRUSTED_PROXY_HOPS`, `STATOO_CLIENT_IP_HEADER`.
- Limites de tentatives (SEC-002/003/005, 14/11) : IP client = adresse du socket par défaut ; derrière un proxy, `STATOO_TRUSTED_PROXY_HOPS` (entrée de X-Forwarded-For comptée depuis la droite) ou `STATOO_CLIENT_IP_HEADER` (en-tête posé par l'hébergeur, jamais `X-Forwarded-For`). **Sur Render, l'une des deux est obligatoire** : sinon `create_app` refuse de démarrer. Limites : connexion 20/min/IP, 10 échecs/15 min par compte et par IP, 50 par compte ; création de groupe 5/h/IP (rejeux et 422 non comptés) ; vérifications de mot de passe 5 échecs/min par acteur (seau commun aux trois routes) ; récupération 10/min/IP et 5/15 min par compte. Compteurs en mémoire, bornés à `MAX_THROTTLE_KEYS` clés. `app/config.py` charge `<racine>/.env.local` et `<racine>/.env`.

## Conventions
- Messages d'erreur en français via `fail(status, message)`, format `{"detail": ...}`. Pour les erreurs de validation, renvoyer un 422 générique, sans écho des valeurs.
- Toute route de groupe passe par `scoped` (isolation par `group_id`) et `require` (rôles).
- Les mutations sont idempotentes par `operation_id`.
- Chaque test crée sa propre app : `create_app('sqlite:///:memory:')`.

## Interdits
- Lancer `scripts/neon_smoke.py` ou `scripts/check-online-api.py` sans accord : ils écrivent dans Neon ou contactent la production, et `neon_smoke.py` est obsolète (voir l'analyse, §8).
- Écrire un test qui utilise `app.main.app` (l'instance du module) avec `TestClient` : elle pointerait sur `DATABASE_URL`.
- Changer la forme de `groups.state` sans prévoir la compatibilité des clients mobile et web.
- Ouvrir les fichiers `.env*`.
