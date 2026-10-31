# Backlog Produit & Dette Technique Statoo

Formule de priorité : $\text{Priorité} = \frac{\text{Valeur Métier} \times \text{Risque}}{\text{Effort}}$

---

## Stories Terminées

### [DOC-01] Synchronisation de la documentation d'architecture avec les flux outbox — ✅ LIVRÉ (Sprint 3)
- **En tant que** nouveau contributeur,  
  **je veux** une documentation à jour des mécanismes d'outbox et de retry offline,  
  **afin de** comprendre immédiatement la tuyauterie de synchronisation mobile/web.
- **Points** : 1 | **Statut** : Complété (commit `331a941`)

### [API-01] Élimination de la dépréciation Starlette httpx sur les tests API — ✅ LIVRÉ (Sprint 3)
- **En tant que** développeur backend,  
  **je veux** éliminer le warning de dépréciation Starlette dans pytest,  
  **afin de** maintenir la suite de tests backend 100% verte sans avertissement.
- **Points** : 1 | **Statut** : Complété (commit `8e5d515`)

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

---

## Backlog Produit Futur & Perspectives

Toutes les stories de dette technique identifiées lors de la prise en main (Sprints 1, 2 et 3 — total 14 points) sont désormais **100% livrées, testées et documentées**.

### Prochaines Évolutions Métier Candidates (Sprint 4)

#### [FEAT-01] Export des statistiques de saison en PDF / CSV
- **En tant que** capitaine ou trésorier,  
  **je veux** exporter le bilan de la saison et les feuilles de match sous format PDF / CSV partageable,  
  **afin de** faciliter la communication hors application et l'assemblée générale.
- **Points** : 3
- **Priorité** : Moyenne (Valeur 4 × Risque 2 ÷ Effort 3 = 2.6)

#### [FEAT-02] Notifications push locales pour les rappels de match
- **En tant que** joueur,  
  **je veux** recevoir un rappel local la veille d'une séance programmée,  
  **afin de** ne pas oublier le rendez-vous.
- **Points** : 2
- **Priorité** : Basse (Valeur 3 × Risque 1 ÷ Effort 2 = 1.5)


---

## Epic ACCESS — Refonte du cycle de vie des accès (créateur, admin, récupération)

### Décisions produit validées (31/10/2026)
- Le mode **local-first est conservé** : un groupe se crée hors ligne, sans compte. L'appareil créateur est le « créateur local » avec tous les droits sur ses données.
- Le **compte ADMIN est créé à l'activation du partage** (en ligne), pas à la création du groupe.
- L'admin **n'est pas forcément un joueur** : choix « Je suis ce joueur » ou « Je ne joue pas » (nom d'affichage).
- **Récupération** : code de secours à usage unique (hash serveur uniquement) + réinitialisation par un autre admin. La question secrète est rejetée (réponses devinables, déconseillée par l'OWASP).
- **Rappel de sauvegarde** pour tout groupe local ni partagé ni sauvegardé.

### Constats du code qui contraignent la conception
- `ADMIN` est un rôle **singulier** (`SINGULAR = ROLES - {MEMBER}`, `backend/app/main.py:31`). `add_account` refuse un second ADMIN (409 « Un rôle unique est déjà attribué », `main.py:389`) et `roles` impose un transfert motivé. **Il n'existe donc aucun co-administrateur** : la réinitialisation « par un autre admin » exige de lever cette contrainte (ACCESS-02).
- `reset_manager_password` (`main.py:417`) n'est accessible qu'à un ADMIN et **refuse de changer son propre mot de passe** (409, `main.py:420`). Aucun endpoint ne permet à un admin de changer son mot de passe (ACCESS-03).
- **Incohérence de politique** : `Credentials`/`verify` acceptent 8 à 200 caractères, alors que `reset_manager_password` exige exactement 8 caractères alphanumériques avec majuscule, minuscule et chiffre (`main.py:422-426`).
- Le compte ADMIN est créé avec `member_id: None` (`main.py:303-304`) : le modèle supporte déjà un admin non-joueur, mais l'audit n'a aucun nom lisible.
- `POST /groups` est idempotent via `operation_id` et rejoue en renvoyant un jeton (`main.py:281-291`). **Un code de secours généré côté serveur ne pourrait pas être ré-affiché au rejeu** : décision d'architecture à trancher dans ACCESS-01.

### [ACCESS-03] Changement de son propre mot de passe et politique de mot de passe unifiée — ✅ LIVRÉ (Commit 28fc6f7)
- **En tant qu'** administrateur (ou gestionnaire),  
  **je veux** changer mon propre mot de passe depuis mon compte authentifié, avec la même politique de mot de passe partout,  
  **afin de** ne plus dépendre d'un tiers pour renouveler mes identifiants et d'éviter les règles contradictoires.
- **Points** : 2 | **Statut** : Complété (commit `28fc6f7`)
- **Critères d'acceptation** :
  - *Given* un compte individuel authentifié, *When* il envoie l'ancien et le nouveau mot de passe valides, *Then* le mot de passe est remplacé, les autres jetons du compte sont révoqués, le jeton courant reste valide, l'action est auditée.
  - *Given* un ancien mot de passe incorrect, *When* la demande est envoyée, *Then* 400/401 et aucune modification.
  - *Given* le compte collectif, *When* la demande est envoyée, *Then* 422 (compte individuel requis).
  - *Given* un mot de passe acceptable à l'inscription mais refusé à la réinitialisation (ou l'inverse), *Then* il n'existe plus d'écart : une seule politique documentée et testée.


### [ACCESS-01] Code de secours administrateur à usage unique — ✅ LIVRÉ (Commit 5e86c25)
- **En tant qu'** administrateur,  
  **je veux** un code de secours généré à l'activation du partage, utilisable une seule fois pour reprendre la main si j'oublie mon mot de passe,  
  **afin de** ne jamais bloquer mon groupe.
- **Décision d'architecture validée** : code généré côté client et envoyé dans `Registration` (hash PBKDF2 stocké sur le serveur, rejeu idempotent via `canonical_body.pop('recovery_code', None)` si absent).
- **Points** : 5 | **Statut** : Complété (commit `5e86c25`)
- **Critères d'acceptation validés** :
  - *Given* une création de groupe réussie, *When* l'admin est créé avec un code de secours, *Then* seul le **hash** PBKDF2 du code est stocké dans `admin['recovery']` (jamais le clair) et masqué dans le snapshot (`{'configured': bool, 'created_at': ...}`).
  - *Given* un `operation_id` rejoué après une coupure réseau, *When* le serveur répond, *Then* l'admin conserve un code de secours valide et connu (aucune perte, aucune duplication, empreinte canonique préservée).
  - *Given* un identifiant, le groupe et un code valides, *When* `POST /auth/recover` reçoit un nouveau mot de passe et un nouveau code de secours, *Then* le mot de passe est remplacé, **tous** les jetons du compte sont révoqués, le nouveau code remplace l'ancien (rotation obligatoire), un nouveau jeton Bearer est émis avec `recovery_rotated: True`, l'action est auditée `account_recovered`.
  - *Given* un code déjà utilisé, incorrect, ou un groupe/identifiant inconnu, *When* la récupération est tentée, *Then* 401 avec message générique (aucune fuite d'existence du compte, timing constant via hash factice PBKDF2) et la limitation de débit s'applique (10/min par IP, 5/15min par compte).
  - *Given* un groupe existant, *When* l'admin connecté demande la régénération via `PUT /groups/{id}/account/recovery-code`, *Then* son mot de passe actuel est vérifié, l'opération est idempotente et auditée.
  - *Given* le compte collectif ou un gestionnaire, *Then* aucun code de secours n'est exposé.
  - Isolation multi-tenant : un code d'un groupe ne fonctionne pas sur un autre.
- **Priorité** : Haute (Valeur 5 × Risque 5 ÷ Effort 5 = 5)
- **Rôles mobilisés** : `architect`, `test-engineer`, `implementer`, `backend-api`, `reviewer`

### [ACCESS-02] Co-administrateurs et réinitialisation d'un admin par un autre admin
- **En tant qu'** administrateur,  
  **je veux** pouvoir nommer un ou plusieurs co-administrateurs capables de réinitialiser mon accès,  
  **afin que** le groupe ne dépende pas d'un seul compte ni d'un code papier.
- **Décision à valider** : lever la contrainte « rôle singulier » pour `ADMIN` uniquement (les autres rôles de bureau restent uniques).
- **Critères d'acceptation** :
  - *Given* un ADMIN, *When* il attribue `ADMIN` à un second compte individuel, *Then* c'est accepté sans transfert ; les autres rôles singuliers restent refusés en double.
  - *Given* deux ADMIN, *When* l'un réinitialise le mot de passe de l'autre, *Then* c'est accepté, les jetons de la cible sont révoqués, l'action est auditée avec l'acteur.
  - *Given* un seul ADMIN, *When* on tente de lui retirer le rôle, *Then* 409 (dernier admin protégé, comportement actuel conservé).
  - *Given* un non-ADMIN (PDT, VP, TR…), *When* il tente de nommer ou réinitialiser un admin, *Then* 403.
  - Aucune régression sur `ready()` (rôles obligatoires ADMIN/PDT/TR) ni sur les 406 tests backend.
- **Points** : 3
- **Priorité** : Moyenne (Valeur 3 × Risque 3 ÷ Effort 3 = 3)
- **Rôles mobilisés** : `architect`, `test-engineer`, `implementer`, `backend-api`, `reviewer`

### [ACCESS-04] Identité de l'admin : joueur de l'effectif ou organisateur non-joueur
- **En tant qu'** administrateur,  
  **je veux** indiquer si je suis un joueur du groupe ou un organisateur qui ne joue pas, avec un nom d'affichage,  
  **afin que** l'historique d'audit désigne clairement qui a fait quoi.
- **Critères d'acceptation** :
  - *Given* l'activation du partage, *When* l'admin choisit « Je suis ce joueur » et un membre, *Then* le compte admin porte ce `member_id` (membre existant de l'effectif).
  - *Given* « Je ne joue pas » avec un nom d'affichage valide, *When* le groupe est créé, *Then* `member_id` reste nul et le nom d'affichage est conservé (longueur bornée, non vide).
  - *Given* un `member_id` inconnu, *Then* 422 ; un nom d'affichage vide avec « Je ne joue pas », *Then* 422.
  - *Given* l'audit, *When* il est affiché, *Then* l'acteur est un nom lisible et non un UUID ; les groupes existants (sans nom) gardent un repli explicite.
  - Compatibilité : une inscription sans ces champs (ancien client) reste acceptée.
- **Points** : 3
- **Priorité** : Moyenne (Valeur 3 × Risque 2 ÷ Effort 3 = 2)
- **Rôles mobilisés** : `architect`, `test-engineer`, `implementer`, `backend-api`, `mobile`, `reviewer`

### [ACCESS-05] Activation du partage : créateur local → ADMIN avec code de secours
- **En tant que** créateur d'un groupe local,  
  **je veux** activer le partage en ligne en quelques champs et obtenir mon code de secours,  
  **afin de** devenir administrateur sans avoir eu besoin de compte pour créer mon groupe hors ligne.
- **Dépend de** : ACCESS-01, ACCESS-04.
- **Critères d'acceptation** :
  - *Given* aucune connexion réseau, *When* l'utilisateur crée un groupe, *Then* la création réussit sans compte (comportement local-first inchangé).
  - *Given* un groupe local, *When* l'utilisateur active le partage, *Then* il choisit son identité (ACCESS-04), un mot de passe (l'identifiant est proposé à partir du nom, modifiable), et le compte commun des membres.
  - *Given* la création réussie, *When* l'écran du code de secours s'affiche, *Then* le code est visible une seule fois, copiable/partageable, et la sortie exige la confirmation « j'ai noté mon code ».
  - *Given* une coupure réseau pendant l'activation, *When* l'utilisateur réessaie, *Then* l'opération est rejouée sans doublon de groupe ni perte du code.
  - Design : `docs/design-system.md` lu, Poppins, `context.colors`, thèmes clair/sombre, 320/393 dp, texte agrandi, icônes `remixicon`.
  - Parité web : même flux sur Flutter Web.
- **Points** : 5
- **Priorité** : Haute (Valeur 5 × Risque 4 ÷ Effort 5 = 4)
- **Rôles mobilisés** : `architect`, `test-engineer`, `implementer`, `mobile`, `web-parity`, `reviewer`

### [ACCESS-07] Récupération d'accès depuis l'écran de connexion
- **En tant qu'** administrateur ayant oublié son mot de passe,  
  **je veux** utiliser mon code de secours depuis l'écran « Rejoindre »,  
  **afin de** reprendre l'administration sans support.
- **Dépend de** : ACCESS-01.
- **Critères d'acceptation** :
  - *Given* l'écran de connexion, *When* l'utilisateur choisit « Mot de passe oublié », *Then* il saisit identifiant du groupe, identifiant, code de secours et nouveau mot de passe.
  - *Given* une récupération réussie, *Then* l'utilisateur est connecté, le **nouveau** code de secours est affiché une fois, l'ancien est invalide.
  - *Given* un code erroné ou déjà utilisé, *Then* message générique, aucune indication sur l'existence du compte, et l'écran supporte les erreurs réseau et la limitation de débit.
  - Texte agrandi, clavier ouvert et 320 dp sans débordement ; parité Flutter Web.
- **Points** : 3
- **Priorité** : Haute (Valeur 5 × Risque 4 ÷ Effort 3 = 6.7)
- **Rôles mobilisés** : `test-engineer`, `implementer`, `mobile`, `web-parity`, `reviewer`

### [ACCESS-06] Rappel de sauvegarde pour les groupes locaux non partagés
- **En tant que** créateur d'un groupe resté local,  
  **je veux** être averti tant que mes données ne sont ni partagées ni sauvegardées,  
  **afin de ne pas tout perdre** si mon appareil est perdu ou cassé.
- **Critères d'acceptation** :
  - *Given* un groupe local ni partagé ni sauvegardé, *When* l'utilisateur ouvre l'accueil, *Then* un bandeau non bloquant propose « Sauvegarder » (réutilise `BackupService`) ou « Activer le partage ».
  - *Given* une sauvegarde exportée ou un partage activé, *Then* le bandeau disparaît et la date de dernière sauvegarde est conservée dans `meta` (clé scopée par `team_id`).
  - *Given* l'utilisateur ferme le bandeau, *Then* il réapparaît après un délai défini (pas à chaque ouverture).
  - Multi-tenant : l'état du rappel est indépendant par groupe.
  - Aucune modification de `participations` ni des vues SQL ; migration `meta` seulement si nécessaire et réversible.
- **Points** : 3
- **Priorité** : Haute (Valeur 4 × Risque 4 ÷ Effort 3 = 5.3)
- **Rôles mobilisés** : `architect`, `test-engineer`, `implementer`, `mobile`, `reviewer`

### Découpage proposé (24 points, trop pour un seul sprint)

| Lot | Stories | Points | Objectif |
|---|---|---|---|
| A — Fondations backend | ACCESS-03, ACCESS-01, ACCESS-02 | 10 | Récupération et co-admins côté serveur |
| B — Parcours mobile/web | ACCESS-04, ACCESS-05, ACCESS-07 | 11 | Activation du partage et récupération utilisables |
| C — Filet de sécurité local | ACCESS-06 | 3 | Protéger les groupes jamais partagés |

Ordre recommandé : ACCESS-03 → ACCESS-01 → ACCESS-07 (valeur la plus haute, débloque la récupération), puis ACCESS-04/05, puis ACCESS-02 et ACCESS-06.

### Idées écartées pour l'instant (à rechiffrer plus tard)
- Invitation joueur par lien WhatsApp / QR code de vestiaire (deep link).
- Séparation de l'écran en cartes « Accès joueurs » / « Staff ».
- Profils métier (Capitaine, Trésorier…) à la place des sigles de rôles.
- Invitation sécurisée d'un gestionnaire avec code d'activation temporaire.
