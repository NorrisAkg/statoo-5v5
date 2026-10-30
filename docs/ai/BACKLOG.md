# Backlog Produit & Dette Technique Statoo

Formule de priorité : $\text{Priorité} = \frac{\text{Valeur Métier} \times \text{Risque}}{\text{Effort}}$

---

## Stories Terminées

### [PERF-01] Gestion du cycle de vie de connexion SQLite en arrière-plan — ✅ LIVRÉ (Sprint 2)
- **En tant qu'** utilisateur mobile,  
  **je veux** que l'application libère les verrous et mette en sommeil propre sa connexion SQLite lors du passage en arrière-plan (`AppLifecycleState.paused` / `detached`),  
  **afin d'** éviter toute corruption de base de données ou verrouillage persistant (recommandation CDC).
- **Points** : 3 | **Statut** : Complété (commit `0d1e1ba`)

### [PARITY-01] Typage strict des fixtures et suppression des appels dynamiques dans l'import PWA — ✅ LIVRÉ (Sprint 2)
- **En tant que** développeur parité web-mobile,  
  **je veux** remplacer les types `dynamic` par des modèles typés dans `pwa_wire_import_test.dart`,  
  **afin de** détecter à la compilation tout changement de schéma du format de synchronisation PWA / mobile.
- **Points** : 1 | **Statut** : Complété (commit `4a62fdb`)

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

## Backlog à Planifier (Sprint 3)

### [API-01] Élimination de la dépréciation Starlette httpx sur les tests API
- **En tant que** développeur backend,  
  **je veux** moderniser le client de test Starlette (`httpx` -> test client asynchrone / `httpx2`),  
  **afin d'** éliminer le warning de dépréciation Starlette dans pytest.
- **Points** : 1
- **Priorité** : Basse (Valeur 2 × Risque 1 ÷ Effort 1 = 2)
- **Rôles mobilisés** : `backend-api`, `reviewer`

### [DOC-01] Synchronisation de la documentation d'architecture avec les flux outbox
- **En tant que** nouveau contributeur,  
  **je veux** une documentation à jour des mécanismes d'outbox et de retry offline,  
  **afin de** comprendre immédiatement la tuyauterie de synchronisation mobile/web.
- **Points** : 1
- **Priorité** : Basse (Valeur 2 × Risque 1 ÷ Effort 1 = 2)
- **Rôles mobilisés** : `architect`, `reviewer`
