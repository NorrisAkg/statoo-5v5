# Plan d'Architecture TDD — Story [DATA-01]

## Objectif
Fiabiliser et versionner les 7 vues SQL et triggers multi-tenant dans `AppDatabase` pour éviter leur recréation systématique aveugle à chaque ouverture (`onOpen`), tout en assurant l'auto-réparation et la migration transparente si la version des vues change.

## Scénarios de Test (TDD - Test Engineer)
1. **Création initiale (Fresh DB)** : Les 7 vues et 2 triggers sont créés, et `views_version = 1` est écrit dans `meta`.
2. **Réouverture idempotente sans modification** : À l'ouverture d'une base déjà à jour, les vues ne sont pas recréées inutilement.
3. **Mise à niveau de version des vues (Upgrade views)** : Si `views_version` dans `meta` est inférieur ou absent, `onOpen` recrée les vues et met à jour `meta`.
4. **Auto-guérison (Missing view detection)** : Si une vue est manquante dans `sqlite_master`, l'ouverture régénère l'ensemble des vues.
5. **Non-régression complète** : Toutes les migrations historiques (v6, v7, v8) et calculs d'agrégats statistiques restent 100% intacts.

## Implémentation Prévue (`AppDatabase`)
- Constante publique/annotée `@visibleForTesting static const int currentViewsVersion = 1;`
- Constante `static const String viewsVersionKey = 'views_version';`
- Stockage de la version dans `meta` lors de `_createViews`.
- Méthode `_ensureViews(Database db)` appelée dans `onOpen` remplaçant le drop/create aveugle.
