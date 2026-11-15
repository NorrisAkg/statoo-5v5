# Audit Statoo — Synthèse

Date : 14/11/2026. Périmètre : monorepo `statoo-5v5` (un seul dépôt git), arbre de travail de `fix/mobile-red-tests` (HEAD `2a9a3c7`, identique à `staging`, plus des modifications non commitées). Méthode : 11 rapports de domaine (`01` à `11`), suites de tests et outils exécutés en local, parcours réels sur Flutter web local (Playwright + Chrome, API en mémoire), puis vérification croisée de tous les constats Critique et Majeur ([raw/verification-phase4.md](raw/verification-phase4.md)).

**189 constats** : 2 Critique, 42 Majeur, 133 Mineur, 12 Info. Après fusion des doublons, il reste **1 Critique distinct** (l'interblocage du backend, vu par quatre domaines) et **34 Majeurs distincts**. Liste complète : [index.csv](index.csv).

## Diagnostic global

Statoo est un produit fonctionnellement riche et bien testé côté client : 1 358 tests mobiles, 442 tests backend et 61 tests web passent tous ; le domaine Dart est pur et l'isolation entre groupes tient à chaque couche (aucune fuite inter-tenant trouvée). Le risque se concentre côté serveur et exploitation. Un verrou Python global, pris dans un pool de 40 threads, fait **geler définitivement l'API** dès ~40 requêtes simultanées, sans authentification (reproduit deux fois en local). Cette API stocke chaque groupe comme un agrégat JSON qui grossit sans limite, ne possède ni migrations, ni lockfile, ni journaux, ni sauvegarde documentée, et tourne sur un plan gratuit. `staging` y fait office de production et tout build Flutter sans paramètre vise la production. Aucune CI ne protège ces déploiements. Côté produit, deux livraisons sont incomplètes : la récupération d'accès (ACCESS-07) est inutilisable faute de code de secours créé, et la suppression d'une séance laisse une cotisation due. L'accessibilité clavier et lecteur d'écran du Flutter web est insuffisante. La dette est réelle mais localisée : les correctifs les plus urgents sont petits (XS à M).

## Notes par domaine

| Domaine | Note /5 | Justification |
|---|---|---|
| A. Métier | 3 | Règles centrales alignées entre Dart, Python et JS ; mais suppression de séance qui crée une dette (MET-001), minimum de joueurs absent du mobile (MET-002), récupération inutilisable (MET-005), écarts de parité (MET-006). |
| B. Parcours UX | 3 | Parcours locaux courts (9 à 18 clics), confirmations présentes ; mais « Annuler » d'un carton qui efface une autre action (UX-001), identifiant de groupe piège (UX-003), messages d'erreur bruts. |
| C. UI | 3 | Couleurs tokenisées (1 206 `context.colors`), thèmes clair et sombre complets ; typographie hors thème, composants reconstruits, erreurs brutes, quelques contrastes faibles. |
| D. Accessibilité | 2,5 | Texte agrandi et 320 px corrects ; mais focus invisible, commandes hors tabulation, 18 boutons et 15 champs sans nom (4 Majeurs WCAG). |
| E. Architecture | 2,5 | Domaine mobile pur, analyse statique propre ; backend monolithique sans migrations, feature `shared` qui court-circuite les couches, matrice des rôles en six copies. |
| F. Sécurité | 2,5 | Hachage, jetons et contrôle d'accès par groupe corrects, aucun IDOR ni injection ; mais déni de service non authentifié (SEC-001, Critique), absence de rate limit, oracles de mot de passe. Note abaissée de 3 à 2,5 après requalification de SEC-001. |
| G. Données | 3 | Cloisonnement multi-tenant solide ; agrégat non borné, photos brutes dans l'état partagé, migration bloquante au démarrage, aucun effacement possible. |
| H. Performance | 2 | Interblocage définitif mesuré (PERF-001), sérialisation entre groupes, snapshot de 6 Mo rechargé toutes les 45 s, précache de 47,5 Mo. |
| I. Tests | 3 | Suites nombreuses, centrées sur le comportement et toutes vertes ; pas de CI, pas de couverture mesurée, chemins critiques non testés, parité limitée à une fixture. |
| J. DevOps | 1,5 | Ni CI, ni environnement de recette, ni observabilité, ni plan de sauvegarde serveur ; plan gratuit en production. |
| K. Dépendances | 3 | Aucune vulnérabilité npm, lockfiles mobile et web présents, licences compatibles ; backend sans lockfile, écosystème Dart jamais scanné, dépendances inutilisées. |
| **Global** | **2,5** | Moyenne des notes de domaine (2,6), arrondie au demi-point inférieur pour tenir compte du constat critique. |

## Les dix constats les plus importants

| Rang | ID (doublons fusionnés) | Sévérité | Constat | Effort |
|---|---|---|---|---|
| 1 | **PERF-001** (+ SEC-001, ARC-002, DAT-003, PERF-002) | Critique | Verrou `threading.Lock` global pris dans `db()` (`backend/app/main.py:284`, `:298-300`) : avec le pool AnyIO de 40 threads, ~40 requêtes simultanées, même non authentifiées, gèlent l'API jusqu'au redémarrage. Hors interblocage, il sérialise tous les groupes (3,3 s d'attente mesurées). | S |
| 2 | **OPS-002** | Majeur | Pas de séparation d'environnements : `staging` est déployé en production, `STATOO_API` vaut `https://statoo-api.onrender.com` par défaut (`scripts/build-universal-web.sh:17`, code Flutter). | M |
| 3 | **OPS-001** (+ TST-001) | Majeur | Aucune CI ni hook git ; Render déploie sans test, Vercel ne lance que les tests du portail. | M |
| 4 | **MET-001** (+ TST-003) | Majeur | « Supprimer » une séance la transforme en échéance annulée qui laisse la cotisation due à chaque membre (solde −100 reproduit), alors que l'UI annonce une suppression ; chemin jamais testé. | M |
| 5 | **MET-005** (+ UX-002, MET-006 partiel) | Majeur | Aucun client n'envoie de code de secours et rien ne permet d'en générer un : la récupération d'accès ACCESS-07, marquée livrée, échoue toujours (401). | M |
| 6 | **SEC-003, SEC-005, SEC-002** (+ OPS-007) | Majeur | `POST /groups` sans rate limit ni limite de corps ; trois endpoints de vérification de mot de passe sans throttling ; throttling de connexion par IP probablement global derrière le proxy Render [déduit]. | S |
| 7 | **DAT-006** | Majeur | Une migration SQLite refusée lève une exception avant `runApp` : l'application ne démarre plus et l'utilisateur ne peut pas exporter ses données. | M |
| 8 | **OPS-004** + **OPS-003** | Majeur | Rien dans le dépôt pour sauvegarder ou restaurer Neon, aucun plan de reprise ; aucun log, métrique, alerte ni crash reporting. | M |
| 9 | **DAT-002 / PERF-003** (+ DAT-001) | Majeur | `groups.state` grossit sans limite (opérations, audit, photos base64 jusqu'à 2 Mio) ; chaque requête le relit en entier ; snapshot de 6 Mo téléchargé deux fois toutes les 45 s. | L |
| 10 | **UX-001** | Majeur | Le bouton « Annuler » du message de carton annule la dernière action du journal (un but disparaît, score 1-1 → 1-0). | S |

Également Majeurs et prioritaires pour un groupe d'utilisateurs : **A11Y-001 à A11Y-004** (focus invisible, commandes hors tabulation, boutons et champs sans nom), **MET-002** (minimum de joueurs), **UX-003** (identifiant `#`), **DEP-001** (lockfile backend).

## Corrections apportées en Phase 4

45 constats Critique ou Majeur vérifiés par un agent indépendant, 7 par la session principale : aucun retiré, 9 requalifiés (SEC-001 relevé en Critique ; SEC-004, SEC-006, UI-001, UI-002, PERF-004, PERF-008, TST-002 et TST-005 abaissés en Mineur), 2 non vérifiables faute d'accès à Render (SEC-002, OPS-007, gardés Majeur [déduit]). Les mentions « pytest.log tronqué » de certains rapports sont caduques : `442 passed in 650.22s`.

## Ce qui n'a pas été audité

- Configuration réelle de Render, Vercel et Neon (variables, origines CORS, branches suivies, sauvegardes, proxy) : invisible depuis le dépôt, accès production exclu.
- Builds Android et iOS, comportement sur appareil réel, lecteur d'écran réel.
- Accessibilité et performance sans axe, pa11y ni Lighthouse (non installés) : méthodes de substitution décrites dans `04` et `08`.
- Vulnérabilités des 169 paquets Dart (pas d'OSV-Scanner local).
- E2E Playwright existants non relancés (certains visent la production).
- Le panneau navigateur intégré refuse le `SharedWorker` de sqflite ; les parcours ont été faits avec Playwright et Chrome.
