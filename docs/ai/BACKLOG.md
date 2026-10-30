# Backlog Produit & Dette Technique Statoo

Formule de priorité : $\text{Priorité} = \frac{\text{Valeur Métier} \times \text{Risque}}{\text{Effort}}$

---

## Stories Terminées

### [DATA-01] Versioning et fiabilisation des 7 vues SQL dans AppDatabase — ✅ LIVRÉ (Sprint 2)
- **En tant qu'** architecte de données,  
  **je veux** fiabiliser et vérifier la présence des 7 vues SQL (`v_standings`, `v_top_scorers`, etc.) et des triggers multi-tenant de façon idempotente plutôt que de les détruire/recréer aveuglément à chaque ouverture,  
  **afin d'** accélérer le démarrage de l'application et sécuriser l'auto-guérison du schéma SQLite en cas d'incohérence.
- **Points** : 3 | **Statut** : Complété (commit `5c2dffc`)

### [TECH-01] Nettoyage des alertes de linter et warnings Dart — ✅ LIVRÉ (Sprint 1)
- **En tant que** développeur / mainteneur,  
  **je veux** éliminer les 2 warnings et les incohérences de style,  
  **afin de** garantir une analyse statique `dart analyze` sans ambiguïté et empêcher l'introduction de régressions silencieuses.
- **Points** : 2 | **Statut** : Complété

### [SPORT-01] Transaction SQLite atomique pour la validation et clôture de séance — ✅ LIVRÉ (Sprint 1)
- **En tant que** capitaine / organisateur de match,  
  **je veux** que la clôture d'une séance (validation des règles métier, bascule de statut `CLOSED`, enregistrement des scores et libération de la séance active) soit exécutée au sein d'une transaction SQLite atomique unique,  
  **afin d'** éliminer tout risque d'incohérence en base ou de séance active fantôme en cas de crash ou d'interruption.
- **Points** : 3 | **Statut** : Complété

---

## Sprint 2 en Cours (4 points restants)

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
  - *Then* tous les accès aux champs JSON s'effectuent via des interfaces ou classes typées.
  - *Then* `dart analyze` ne rapporte plus d'`avoid_dynamic_calls`.
- **Points** : 1
- **Priorité** : Moyenne (Valeur 3 × Risque 2 ÷ Effort 1 = 6)
- **Rôles mobilisés** : `test-engineer`, `implementer`, `reviewer`, `web-parity`
