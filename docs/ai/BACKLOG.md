# Backlog Produit & Dette Technique Statoo

Formule de priorité : $\text{Priorité} = \frac{\text{Valeur Métier} \times \text{Risque}}{\text{Effort}}$

---

### [TECH-01] Nettoyage des alertes de linter et warnings Dart — ✅ LIVRÉ (Sprint 1)
- **En tant que** développeur / mainteneur,  
  **je veux** éliminer les 2 warnings et les 8 incohérences de style dans `finance` et les tests,  
  **afin de** garantir une analyse statique `dart analyze` sans ambiguïté et empêcher l'introduction de régressions silencieuses.
- **Critères d'acceptation** :
  - *Given* la commande `dart analyze lib test` exécutée dans `mobile/`,
  - *When* le code est analysé,
  - *Then* aucun avertissement (`warning`) n'est remonté (notamment sur `session_permissions_test.dart` et `manager_validation_test.dart`).
  - *Then* les méthodes asynchrones de `FinanceRepository` et les blocs de contrôle respectent les règles linter.
- **Points** : 2
- **Priorité** : Haute (Valeur 4 × Risque 3 ÷ Effort 2 = 6)
- **Rôles mobilisés** : `test-engineer`, `implementer`, `reviewer`, `mobile`

---

### [SPORT-01] Transaction SQLite atomique pour la validation et clôture de séance — ✅ LIVRÉ (Sprint 1)
- **En tant que** capitaine / organisateur de match,  
  **je veux** que la clôture d'une séance (validation des règles métier, bascule de statut `CLOSED`, enregistrement des scores et libération de la séance active) soit exécutée au sein d'une transaction SQLite atomique unique,  
  **afin d'** éliminer tout risque d'incohérence en base ou de séance active fantôme en cas de crash ou d'interruption.
- **Critères d'acceptation** :
  - *Given* une séance au statut `DRAFT` avec scores et participations valides,
  - *When* la méthode de clôture est déclenchée,
  - *Then* la validation des règles `SessionCloseRules` et les mutations SQL s'exécutent dans une transaction unifiée.
  - *Then* en cas d'échec ou d'exception à n'importe quelle étape, aucun changement d'état n'est persisté et la séance reste active.
- **Points** : 3
- **Priorité** : Haute (Valeur 5 × Risque 5 ÷ Effort 3 = 8.3)
- **Rôles mobilisés** : `architect`, `test-engineer`, `implementer`, `reviewer`, `mobile`

---

### [DATA-01] Versioning et fiabilisation des 7 vues SQL dans AppDatabase
- **En tant qu'** architecte de données,  
  **je veux** versionner formellement le schéma des 7 vues SQL (`v_standings`, `v_top_scorers`, etc.) plutôt que de les recréer aveuglément à froid à chaque ouverture,  
  **afin d'** accélérer le démarrage de l'application et sécuriser la cohérence du schéma SQLite entre versions.
- **Critères d'acceptation** :
  - *Given* une base de données existante avec des données de séance,
  - *When* l'application démarre et ouvre `AppDatabase`,
  - *Then* les vues ne sont recréées que si la version du schéma a été incrémentée.
  - *Then* tous les calculs d'agrégats (points, buts, passes, MVP) restent 100% conformes aux tests actuels.
- **Points** : 3
- **Priorité** : Moyenne (Valeur 4 × Risque 4 ÷ Effort 3 = 5.3)
- **Rôles mobilisés** : `architect`, `test-engineer`, `implementer`, `reviewer`, `mobile`

---

### [PERF-01] Gestion du cycle de vie de connexion SQLite en arrière-plan
- **En tant qu'** utilisateur mobile,  
  **je veux** que l'application libère les verrous et mette en sommeil propre sa connexion SQLite lors du passage en arrière-plan (`AppLifecycleState.paused` / `detached`),  
  **afin d'** éviter toute corruption de base de données ou verrouillage persistant (recommandation CDC).
- **Critères d'acceptation** :
  - *Given* l'application mobile en cours d'exécution avec une connexion active,
  - *When* l'OS bascule l'application en arrière-plan (`paused`),
  - *Then* les transactions en cours sont flushées et la connexion SQLite est mise en veille sécurisée.
  - *When* l'application revient au premier plan (`resumed`),
  - *Then* la connexion est instantanément réactivée sans perturber les providers Riverpod.
- **Points** : 3
- **Priorité** : Moyenne (Valeur 3 × Risque 4 ÷ Effort 3 = 4)
- **Rôles mobilisés** : `test-engineer`, `implementer`, `reviewer`, `mobile`

---

### [PARITY-01] Typage strict des fixtures et suppression des appels dynamiques dans l'import PWA
- **En tant que** développeur parité web-mobile,  
  **je veux** remplacer les types `dynamic` par des modèles typés dans `pwa_wire_import_test.dart`,  
  **afin de** détecter à la compilation tout changement de schéma du format de synchronisation PWA / mobile.
- **Critères d'acceptation** :
  - *Given* les fixtures de synchronisation importées du web vers SQLite,
  - *When* le test `test/features/shared/pwa_wire_import_test.dart` est exécuté,
  - *Then* tous les accès aux champs JSON s'effectuent via des interfaces ou classes typées,
  - *Then* `dart analyze` ne rapporte plus d'`avoid_dynamic_calls`.
- **Points** : 1
- **Priorité** : Moyenne (Valeur 3 × Risque 2 ÷ Effort 1 = 6)
- **Rôles mobilisés** : `test-engineer`, `implementer`, `reviewer`, `web-parity`
