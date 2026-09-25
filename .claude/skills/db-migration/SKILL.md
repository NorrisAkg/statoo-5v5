---
name: db-migration
description: Procédure pour modifier le schéma SQLite de Statoo (table, colonne, index, vue SQL) sans casser les bases existantes ni le backup. À utiliser dès qu'un changement touche lib/core/data/app_database.dart, une vue v_*, ou la forme des données sauvegardées.
---

# Migration du schéma SQLite

Les utilisateurs ont des bases en production locale : un schéma modifié sans migration les casse au prochain lancement, sans retour possible.

## 1. Lire l'existant

- `lib/core/data/app_database.dart` : `version` courante, `_createSchema`, `_createViews`, `_dropViews`, `onUpgrade`.
- `lib/features/settings/data/backup_service.dart` et `domain/backup_payload.dart` : ce qui est exporté/restauré.
- `grep` des repositories qui lisent la table ou la vue concernée.

## 2. Tables et colonnes

1. Modifier `_createSchema` (installations neuves).
2. Incrémenter `version` dans `openDatabase`.
3. Ajouter dans `onUpgrade` une branche `if (oldVersion < N) { ... }`, **idempotente** : vérifier `PRAGMA table_info(<table>)` avant un `ALTER TABLE ADD COLUMN`, `CREATE INDEX IF NOT EXISTS`, backfill des lignes existantes (ex. `team_id` par défaut).
4. SQLite ne sait pas supprimer ni changer le type d'une colonne proprement : recréer la table (`CREATE TABLE x_new` → `INSERT INTO x_new SELECT` → `DROP` → `ALTER TABLE RENAME`) dans une transaction, `PRAGMA foreign_keys = OFF` le temps de l'opération.
5. Toute donnée de groupe porte `team_id` avec `REFERENCES teams(id) ON DELETE CASCADE` ; `participations.player_id` reste en `ON DELETE RESTRICT` (archivage).

## 3. Vues SQL

- Les vues sont supprimées puis recréées à chaque `onOpen` : pas besoin de bump de version pour une vue seule.
- Une vue nouvelle **doit** figurer dans `_dropViews`, dans l'ordre des dépendances (dépendantes d'abord) — sinon `CREATE VIEW IF NOT EXISTS` conserve l'ancienne définition.
- Toute vue d'agrégat partitionne par `team_id` et ne compte que `status = 'CLOSED'` (+ `is_ranked = 1` pour les classements).
- Mettre à jour le modèle `fromMap` correspondant et son test (`test/features/ranking/ranking_models_test.dart`, `test/features/stats/group_totals_test.dart`).

## 4. Backup

- Une colonne ajoutée doit être exportée et restaurée ; un fichier de backup **antérieur** (sans la colonne) doit rester restaurable : valeur par défaut au restore, en mode fusion comme en écrasement.

## 5. Vérifier

- `dart analyze lib/core/data/app_database.dart <repositories touchés>`.
- `flutter test`.
- Si possible, tester la montée de version sur un appareil ayant l'ancienne base (`flutter run` sans désinstaller), pas seulement une installation neuve.
- Signaler à l'utilisateur la nouvelle `version` et ce que fait la migration.
