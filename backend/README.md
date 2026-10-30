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

## Identifiants de connexion

Les identifiants Admin, collectif et gestionnaires doivent contenir au moins un
caractère autre qu'un espace. Les espaces extérieurs sont retirés au stockage et
à la connexion ; l'unicité utilise la comparaison insensible à la casse
`strip().casefold()`. La casse d'affichage, les accents et les espaces intérieurs
ne sont pas réécrits. Les mots de passe ne sont pas normalisés.

Une collision Admin/collectif à l'inscription est refusée en 422. Une collision
avec un compte existant lors de la création d'un gestionnaire ou d'une rotation
collective reste refusée en 409, sans modifier les accès existants. Les refus
d'identifiant entièrement blanc sont en 422.

Les données brutes de l'inscription restent utilisées pour l'empreinte de reprise
existante ; une tentative avec espaces reste rejouable avec les mêmes informations.
Les doublons ou identifiants vides historiques ne sont pas réparés automatiquement.
Scénarios et preuves : [suivi F06](../docs/tdd-login-identifiers-2026-10-26.md).

## Documents sportifs synchronisés

`POST /groups/{id}/sync` refuse les documents sportifs invalides en 422 avant
leur enregistrement, y compris comme candidature de conflit. La date doit être
une date civile ISO (`YYYY-MM-DD`) ou un timestamp ISO avec secondes, fraction
facultative et fuseau facultatif. Chaque participation doit avoir un `id` stable
et unique dans le document, un joueur connu et une liaison à la séance.

Les formats sont `CLASSIC_2` (valeur historique si le champ est absent) et
`TOURNAMENT_3`. Le classique n'accepte que les camps A/B, même en cas de
dérogation d'équilibre. Les compteurs sont des entiers non négatifs ; les options
natives `allow_uneven_teams` et `is_ranked` sont des entiers 0/1. Les victoires
déterminent le vainqueur du tournoi ; au moins une victoire est requise pour
le clôturer. Un brouillon de tournoi peut conserver zéro victoire et aucun résultat.

Ce contrôle ne répare pas les documents historiques déjà enregistrés. Le choix
explicite de conserver la version courante lors d'un arbitrage reste possible.
Scénarios, preuves et limites : [suivi F03](../docs/tdd-sport-validation-2026-10-25.md).

### Erreurs de validation

Les erreurs de modèle de requête et de modèle financier interne renvoient un
statut 422 avec `{"detail": "Les données saisies sont invalides. Vérifiez les champs requis et leur format."}`.
La réponse ne reprend pas les valeurs, le corps, les chemins de champs ou les
messages internes des validateurs, qui peuvent contenir des secrets. Les refus
métier explicites conservent leurs messages et statuts. Cette protection ne
nettoie pas les journaux des reverse proxies ou des outils externes.
Scénarios et preuves : [suivi F09](../docs/tdd-validation-secrets-2026-10-26.md).

### Fichiers publics du portail historique

Le montage `/portal/` sert uniquement les fichiers explicitement listés dans
`app/portal.py`. Les tests, fixtures, prototypes, README et sorties de build
présents sous `web/` répondent 404. Un nouveau fichier n'est pas automatiquement
public, même dans `icons/`, `fonts/` ou `vendor/`. Toute nouvelle ressource du
portail doit être ajoutée à cette liste et couverte par les tests de chargement.
`/portal/config.json` reste une route dynamique limitée à l'adresse publique API.
Scénarios et preuves : [suivi F10](../docs/tdd-portal-exposure-2026-10-26.md).
