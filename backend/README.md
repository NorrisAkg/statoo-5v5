# API Statoo

FastAPI + SQLAlchemy. PostgreSQL/Neon pour l’hébergement, SQLite pour le développement et les tests.

```powershell
python -m venv .venv
.venv/Scripts/python.exe -m pip install -r requirements-dev.txt
.venv/Scripts/python.exe -m uvicorn app.main:app --reload
.venv/Scripts/python.exe -m pytest
```

La documentation OpenAPI est disponible sur `/docs`, la santé sur `/health`.

Variables :
- `DATABASE_URL` : URL PostgreSQL Neon avec TLS ; uniquement côté serveur.
- `CORS_ORIGINS` : origines exactes du portail web, séparées par des virgules.

Les comptes individuels identifient les gestionnaires. Le compte collectif est en lecture seule. Les mots de passe sont salés et hachés PBKDF2 ; seuls les condensats des jetons opaques sont stockés. Les permissions sont vérifiées à chaque requête.

Chaque groupe est conservé dans un agrégat JSON transactionnel. Un verrou PostgreSQL sérialise ses changements. Ce modèle vise les petits groupes ; il faudra prévoir des migrations versionnées et une normalisation si le volume augmente. Le schéma initial est créé au démarrage ; aucune suppression automatique.

`render.yaml` à la racine cible ce dossier. Configurer les secrets sur Render, les sauvegardes et la restauration PostgreSQL séparément. Aucune infrastructure n’est créée par le code.

Voir [règles et limites](../docs/shared-group-and-finance.md).
