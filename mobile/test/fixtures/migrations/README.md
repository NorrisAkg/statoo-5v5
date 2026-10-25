# Schémas historiques pour les migrations

- `v6.json` : instructions SQL de création des tables/vues de `1a3af10`, fichier historique `lib/core/data/app_database.dart`, version SQLite 6.
- `v7.json` : mêmes instructions depuis `2b67c06`, version SQLite 7.

Ce sont les schémas de ces commits, sans rétro-étiquetage d’un schéma actuel.
Les métadonnées `commit` et `version` permettent de retrouver leur provenance.
Les données fictives sont ajoutées par `test/core/data/database_migration_test.dart`.
Les tests n’exigent pas Git : ils utilisent les instructions embarquées ici et
créent chaque base dans un répertoire temporaire distinct.

Extraction utilisée : lire le fichier au commit indiqué, conserver les chaînes
triple-quoted passées à `db.execute` entre `_createSchema` et `seedDemoData`.
Chaque fixture comporte cinq tables, une insertion de marqueur et sept vues.
Le marqueur `meta.schema_version = 1` est celui de ces anciennes versions ;
le véritable `PRAGMA user_version` est initialisé par `openDatabase(version: ...)`.
