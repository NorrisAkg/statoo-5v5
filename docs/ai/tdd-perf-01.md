# Plan d'Architecture TDD — Story [PERF-01]

## Objectif
Assurer la libération propre des verrous et la mise en veille de la connexion SQLite lorsque l'application passe en arrière-plan (`AppLifecycleState.paused` ou `detached`), et sa réactivation transparente et immédiate au retour au premier plan (`AppLifecycleState.resumed`).

## Scénarios de Test (TDD - Test Engineer)
1. **Fermeture unitaire et réouverture (`AppDatabase.close`)** :
   - Quand `close()` est appelé, la connexion SQLite sous-jacente est fermée (`isOpen == false`).
   - Le prochain appel à `database` réouvre une connexion valide et conserve l'intégralité des données.
2. **Transition de cycle de vie (`paused` / `detached`)** :
   - La notification du cycle de vie `paused` libère la connexion SQLite.
   - La notification du cycle de vie `detached` libère également la connexion.
3. **Réveil transparent (`resumed`)** :
   - Quand l'application repasse en `resumed`, un appel à une requête (ex: `allSessionsProvider`, repository) réactive la connexion sans exception `DatabaseClosedException`.

## Implémentation Prévue
- `AppDatabase` :
  - `if (_database != null && _database!.isOpen) return _database!;`
  - Méthode `Future<void> close()` qui ferme et réinitialise `_database`.
  - Méthode `Future<void> handleLifecycle(AppLifecycleState state)` réagissant aux états `paused` et `detached`.
- `main.dart` :
  - `MyApp` converti en `StatefulWidget` / `WidgetsBindingObserver` pour observer `didChangeAppLifecycleState` et invoquer `AppDatabase.instance.handleLifecycle(state)`.
