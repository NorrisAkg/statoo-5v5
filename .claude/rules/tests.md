---
paths:
  - "test/**"
---

# Tests

- Arborescence miroir : `test/features/<feature>/<sujet>_test.dart`. Imports `package:statoo/...`.
- Tests de widget : `ProviderScope(overrides: [...])` + `MaterialApp(theme: AppTheme.darkTheme, localizationsDelegates, locale fr_FR)`, et `initializeDateFormatting('fr_FR', null)` dans `setUpAll`.
- Surcharger les providers de données (`xxxProvider.overrideWith(...)` ou un repository factice) plutôt que d'ouvrir la vraie base : `sqflite` ne tourne pas sous `flutter test` sans `sqflite_common_ffi`.
- Chaque règle métier du domaine (barème, clôture, éligibilité, départage) a son test unitaire pur.
- Lancer le fichier ciblé (`flutter test test/features/<f>/x_test.dart`) pendant l'itération, la suite complète (~30 s) avant commit.
