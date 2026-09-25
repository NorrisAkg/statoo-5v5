---
paths:
  - "lib/core/data/**"
  - "lib/features/*/data/**"
---

# Couche données (SQLite)

- Toujours passer par `AppDatabase.instance` / `await _appDatabase.database` ; jamais de second `openDatabase`.
- Chaque repository = une interface abstraite + `Sqlite<Nom>Repository`, dans le même fichier, pour pouvoir le surcharger en test.
- **Isolation multi-tenant** : toute requête sur une donnée de groupe filtre `team_id = ?`. Les lectures par identifiant (`getSession(id)`, `getPlayer(id)`) restent sûres seulement si l'identifiant provient déjà d'une liste scopée ; ne pas en ajouter d'autres sans filtre.
- Requêtes paramétrées (`where: 'x = ?', whereArgs: [...]`) ; jamais d'interpolation de valeurs dans le SQL.
- Écritures multiples liées (séance + participations, restore) : dans `db.transaction`.
- Booléens stockés en `INTEGER` 0/1, dates en ISO-8601 `TEXT`.
- **Changement de schéma** : suivre le skill `db-migration` (bump de `version`, branche `onUpgrade` idempotente, liste `_dropViews` tenue à jour, backup_service adapté).
- Vue SQL ajoutée ou modifiée : l'ajouter aussi à `_dropViews`, sinon l'ancienne définition survit (`CREATE VIEW IF NOT EXISTS`).
