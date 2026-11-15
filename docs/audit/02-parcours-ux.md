# Audit Statoo — 02. Parcours utilisateur et ergonomie

- **Domaine** : parcours utilisateur, ergonomie, navigation, feedbacks (préfixe UX-).
- **Date** : 14/11/2026.
- **Méthode** : **exécuté**. Les parcours tournent dans Flutter web release (`mobile/build/web`, servi sur `http://127.0.0.1:18090`, compilé avec `STATOO_API=http://127.0.0.1:18085`). Ils sont pilotés par Playwright avec Chrome et la sémantique Flutter activée. L'API locale isolée (SQLite en mémoire) sert pour le parcours 4. Viewport 393x852 en thème clair pour les parcours 1 à 5. Le parcours 2 a été refait de bout en bout en 320x640 en thème sombre, sur un contexte vierge. Les constats sont recoupés par lecture du code. « [déduit] » marque ce qui est inféré.
- **Limites** :
  - Les clics sont comptés sur le chemin le plus court réellement exécuté. Mes propres tâtonnements d'automatisation (par exemple des clics hors écran) ne sont pas comptés.
  - Le premier essai de création du groupe partagé est resté sur « Connexion en cours… ». La cause était l'interblocage de l'API locale provoqué par le test de charge de l'agent performance (PERF-001), pas l'application. L'API a été relancée et son état réinitialisé. Le parcours 4 a été refait en entier après la relance. Seul le comportement de l'UI pendant l'attente est retenu (UX-017).
  - Tous les appels externes ont été bloqués par `page.route`. Les seuls tentés sont des polices `fonts.gstatic.com` (renvoi H).
  - Non testés : le parcours « Rejoindre » depuis `/bienvenue` sur un second appareil, le mode tournoi à 3 équipes, les rôles non-admin sur le point financier, et le texte agrandi.
- **Identifiants de test** : le test a utilisé des mots de passe aléatoires créés pour l'occasion, sur l'API locale en mémoire. Ils ne sont pas reproduits ici.

## Synthèse

Le parcours local est court et cohérent. Une équipe de 11 joueurs se crée en 9 clics, avec une saisie au clavier (Entrée-Entrée par joueur). Une séance tirée au sort se joue et se clôture en 18 clics. Les destructions de séance, de joueur et l'archivage demandent toutes une confirmation. Les règles bloquantes (minimum de joueurs, écart d'effectif) produisent des messages clairs au bon moment.

Trois défauts majeurs touchent l'intégrité de la saisie et l'accès au groupe partagé :
1. Le bouton « Annuler » du snackbar de carton annule la **dernière action du journal**, pas le carton. Reproduit : un but adverse a été supprimé à la place du carton (UX-001).
2. Un Admin créé depuis l'application n'a **jamais de code de secours**. Le flux « Mot de passe oublié ? » qui lui est proposé est donc voué à l'échec (UX-002).
3. L'identifiant du groupe affiché est `#13120987`. Saisi sans `#`, il produit « 401: Identifiants incorrects », un message trompeur (UX-003).

S'y ajoutent des frictions sur les erreurs du groupe partagé : aucune validation côté client, code HTTP affiché, déconnexion sans confirmation qui laisse le mot de passe dans le formulaire. Il y a aussi des impasses de navigation sur le web après un rechargement et des contraintes de place en 320x640.

**Note proposée : 3/5.** Le cœur sportif est fluide et bien protégé contre les erreurs destructrices. En revanche, l'annulation mal ciblée peut fausser un score sans que l'utilisateur le voie, et l'accès partagé (création, connexion, récupération) accumule des messages trompeurs et une récupération inopérante.

## Tableau récapitulatif

| ID | Sévérité | Titre | Fichier principal | Effort |
|---|---|---|---|---|
| UX-001 | Majeur | « Annuler » du snackbar de carton annule la dernière action du journal, pas le carton | `mobile/lib/features/sessions/presentation/live_stats_panel.dart:121` | S |
| UX-002 | Majeur | Récupération d'accès impossible : aucun code de secours créé ni régénérable depuis l'app | `mobile/lib/features/shared/presentation/shared_group_screen.dart:159` | M |
| UX-003 | Majeur | Identifiant de groupe sans `#` refusé avec « 401: Identifiants incorrects » | `mobile/lib/features/shared/presentation/shared_group_screen.dart:136` | XS |
| UX-004 | Mineur | Déconnexion sans confirmation, feedback « Données mises à jour. », mot de passe laissé dans le formulaire | `shared_group_screen.dart:1651` | S |
| UX-005 | Mineur | Création de groupe partagé sans validation client, erreurs génériques préfixées du code HTTP | `mobile/lib/core/data/shared_http_error.dart:17` | S |
| UX-006 | Mineur | Doublon de joueur accepté à l'ajout initial et retrait sans confirmation ni annulation | `mobile/lib/features/team/presentation/add_team_players_screen.dart:41` | XS |
| UX-007 | Mineur | Écrans hors onglets sans flèche Retour après rechargement ou lien direct | `mobile/lib/core/router/app_router.dart:82` | S |
| UX-008 | Mineur | Retour navigateur depuis une séance démarrée : assistant « Nouvelle séance » réinitialisé | `mobile/lib/features/sessions/presentation/new_session_screen.dart:213` | S |
| UX-009 | Mineur | Point financier : cotisations préremplies « payées » par défaut, montant `0` non sélectionné | `mobile/lib/features/finance/presentation/financial_point_screen.dart` | S |
| UX-010 | Mineur | Onboarding : « Étape 2 sur 2 » suivie d'une 3e étape, libellés trompeurs | `add_team_players_screen.dart:98` | XS |
| UX-011 | Mineur | 320x640 : onglet « Stats » tronqué, actions de l'assistant non collantes, bande fixe de 64 px | `mobile/lib/core/widgets/browser_app_frame.dart:21` | S |
| UX-012 | Mineur | Saisie en direct : cartons non découvrables, résumé de clôture « Équipe A », zone vide dans la célébration | `session_detail_screen.dart:1226` | S |
| UX-013 | Mineur | Classement : égalités départagées par ordre alphabétique avec médailles distinctes | `mobile/lib/features/ranking/data/ranking_repository.dart:86` | S |
| UX-014 | Mineur | Contrôles sans libellé accessible (retour, FAB, fermer, champs) | `mobile/lib/features/players/presentation/player_detail_screen.dart:82` | S |
| UX-015 | Mineur | Création de gestionnaire : mot de passe généré jamais montré, aucun feedback de création | `shared_group_screen.dart` (`_addAccount`) | S |
| UX-016 | Info | « Score absent » inatteignable dans l'UI, déséquilibre bloqué dès le démarrage | `new_session_screen.dart` | — |
| UX-017 | Mineur | Attente réseau de 90 s sans annulation, bouton figé sur « Connexion en cours… » | `mobile/lib/core/data/shared_http_browser.dart:21` | S |
| UX-018 | Mineur | Fonctions d'accès sans UI (ACCESS-03, régénération du code), minimum de joueurs figé en mode partagé | `docs/architecture/vue-densemble.md:52-53` | M |

## Parcours exécutés

### Parcours 1 : premier lancement (393x852, clair)

| Étape | Écran (route) | Action | Clics cumulés | Champs saisis |
|---|---|---|---|---|
| 1 | `/onboarding` (3 pages) | Suivant, Suivant, Commencer (ou « Passer » : 1 clic) | 3 | 0 |
| 2 | `/bienvenue` | « Créer un groupe » | 4 | 0 |
| 3 | `/creer-equipe?partage=1` | Envoi à vide : « Veuillez renseigner le nom de votre équipe » (bon feedback) | (5) | 0 |
| 4 | idem | Nom « FC Audit » (format 5v5 présélectionné), « Continuer vers l'effectif » | 6 | 1 |
| 5 | `/ajouter-joueurs-initiaux?partage=1` | 11 joueurs saisis au clavier (nom, Entrée, Entrée) : le focus revient sur le nom | 7 | 12 |
| 6 | idem | « Continuer vers l'accès Admin » | 8 | 12 |
| 7 | `/groupe-partage?creation=1&installation=1` | Défilement, « Continuer sur cet appareil » | 9 | 12 |
| 8 | `/` | Accueil, états vides : « Aucune séance pour le moment », « Le classement est vide » | — | — |

**Total : 9 clics, 12 champs** (7 clics avec « Passer »). La variante partagée ajoute 3 champs et 1 clic (identifiant Admin, mot de passe Admin, mot de passe commun ; l'identifiant commun est prérempli à `membres`).

- États vides : présents et explicites sur l'accueil, l'effectif (« Aucun joueur ajouté pour le moment », « Objectif : 10 joueurs ») et le classement.
- Retour : flèche sur `/creer-equipe`. Aucune flèche sur `/ajouter-joueurs-initiaux` (seulement « Passer »).
- Frictions : UX-006 (doublon « alice » accepté, retrait immédiat), UX-010 (étapes, libellés). Le snackbar « Bienvenue sur Statoo ! Votre effectif est prê… » est tronqué à 393 px.
- Capture : `docs/audit/raw/captures/ux-01-effectif-initial-doublon.png`.

### Parcours 2 : séance classique (393x852, clair)

| Étape | Écran | Action | Clics cumulés | Champs |
|---|---|---|---|---|
| 1 | `/` | « Nouvelle séance » | 1 | 0 |
| 2 | `/seances/nouvelle` étape 1 | Date et heure préremplies, « Match classé » actif, « Continuer » | 2 | 0 |
| 3 | étape 2 | « Débuter » à 0 joueur → snackbar « Sélectionnez au moins 6 joueurs… (défini dans les réglages) » | (3) | 0 |
| 4 | étape 2 | « Tout cocher » | 3 | 0 |
| 5 | étape 2 | « Tirer au sort » (6/5). En manuel : 11 clics A/B | 4 (manuel : 14) | 0 |
| 6 | étape 2 | Test 7 contre 4 → « L'écart d'effectif entre les équipes ne peut dépasser 1 (activez l'option sinon). » | — | — |
| 7 | étape 2 | « Débuter la séance » | 5 | 0 |
| 8 | `/seances/:id` | 3 buts : « + » du buteur puis passeur ou « Aucun passeur » (2 clics par but), 1 changement d'onglet d'équipe par camp | 13 | 0 |
| 9 | idem | Carton jaune : appui sur le nom du joueur, puis « Carton jaune » | 15 | 0 |
| 10 | idem | « Clôturer la séance », confirmation « Clôturer », célébration « Continuer » | 18 | 0 |

**Total : 18 clics, 0 champ** (tirage au sort), 28 clics en composition manuelle.

- Clôture invalide : la clôture à 0-0 est proposée comme « Match nul (0 – 0) ». Le cas « score absent » est inatteignable et le déséquilibre est bloqué en amont (UX-016).
- Destructif : « Suppression » d'une séance en cours affiche « Supprimer ce match en cours ? … définitivement supprimé » (confirmé). « Annuler la dernière action » est un bouton direct.
- Retour navigateur depuis la séance démarrée : on arrive sur `/seances/nouvelle` réinitialisé, puis sur `/` (UX-008). La flèche de l'app ramène à `/`.
- Bug constaté : UX-001.
- Capture : `docs/audit/raw/captures/ux-02-cloture-dialogue-vide.png`.

**Reprise en 320x640, thème sombre, contexte vierge.** Le parcours complet a été refait : « Passer », création de « Dark FC », 8 joueurs, local, nouvelle séance, tout cocher, tirage, débuter, 1 but, clôture. Il aboutit. Écarts observés :
- l'onglet « Stats » de la barre basse est coupé (« Stat ») ;
- les boutons « Continuer » et « Débuter la séance » ne sont plus collants : il faut faire défiler toute la liste de joueurs, 3 à 4 défilements pour 8 joueurs ;
- la bande « Application » de 64 px prend 10 % de la hauteur (UX-011) ;
- le résumé de clôture affiche « Victoire Équipe A (1 – 0) » alors que l'équipe s'appelle « Union des Collines » (UX-012).

Le thème sombre est lisible et cohérent. Captures : `ux-06-accueil-320-sombre-nav-tronquee.png`, `ux-07-cloture-320-sombre.png`.

### Parcours 3 : consultation (393x852, clair)

| Étape | Écran | Action | Clics cumulés | Champs |
|---|---|---|---|---|
| 1 | `/classement` | Onglet « Classement » : Championnat, sous-onglets Points, Pts/Match, Buteurs, Passeurs, Cartons | 1 | 0 |
| 2 | idem | « MVP du mois » : filtre « Novembre 2026 », carte « Joueur du mois » (Cedric, 12.00 pts) | 2 | 0 |
| 3 | `/joueurs/:id` | Appui sur un joueur : synthèse, statistiques brutes, historique | 3 | 0 |

**Total : 3 clics.** Le joueur du mois est aussi accessible en 1 clic depuis la carte de l'accueil.

- Destructif : « Archiver » (joueur avec historique) et « Supprimer Zed ? … immédiate et définitive » (joueur sans historique) sont confirmés.
- Feedbacks : la création d'un joueur depuis le FAB se fait sans snackbar de succès. La pastille de la fiche affiche « 1 buts » (`player_detail_screen.dart:186`, sans gestion du pluriel).
- Retour navigateur depuis la fiche : retour à `/classement`, l'onglet MVP n'est pas conservé.
- Égalités : UX-013. Capture : `ux-03-fiche-joueur.png`.

### Parcours 4 : groupe partagé (API locale, 393x852)

| Étape | Écran | Action | Clics cumulés | Champs |
|---|---|---|---|---|
| 1 | `/` | Défilement, « Groupe partagé et synchronisation » | 1 | 0 |
| 2 | `/groupe-partage` | Onglet par défaut « Rejoindre » alors qu'un groupe local existe : clic « Partager » | 2 | 0 |
| 3 | idem | Envoi à vide → requête `POST /groups` 422 → « 422: Les données saisies sont invalides. Vérifiez les champs requis et leur format. » | (3) | 0 |
| 4 | idem | Mot de passe Admin de 5 caractères → même 422 générique | (4) | 2 |
| 5 | idem | Identifiant Admin, mot de passe Admin, mot de passe commun valides → 201, écran « Comptes et rôles », identifiant `#13120987` | 3 | 3 |
| 6 | idem | « Ajouter un gestionnaire » → liste des membres → Bruno → identifiant → « Trésorier » → « Créer » | 8 | 4 |
| 7 | idem | « Accès de tresorier.bruno » → « Copier les accès » (seul moyen d'obtenir le mot de passe généré) | 10 | 4 |
| 8 | idem | « Se déconnecter » (sans confirmation) | 11 | 4 |
| 9 | idem | « Rejoindre », identifiant du groupe saisi sans `#` → 401 « Identifiants incorrects » ; avec `#` → connecté | 13 | 7 |
| 10 | idem | Déconnexion, « Mot de passe oublié ? » : feuille préremplie (groupe, identifiant), code de secours, nouveau mot de passe avec checklist, confirmation | 15 | 10 |
| 11 | idem | « Réinitialiser » → `POST /auth/recover` 401 → « Récupération impossible. Vérifiez vos informations. » | 16 | 10 |

**Total : 16 clics, 10 champs** pour créer, ajouter un gestionnaire, se déconnecter, se reconnecter et tenter la récupération.

- Erreurs : UX-003, UX-004, UX-005, UX-015. La récupération est inopérante (UX-002).
- Point positif : le message d'échec de récupération est générique et ne révèle pas l'existence du compte.
- Retour : après rechargement sur `/groupe-partage`, aucune flèche Retour (UX-007).

### Parcours 5 : point financier (393x852)

| Étape | Écran | Action | Clics cumulés | Champs |
|---|---|---|---|---|
| 1 | `/seances` | Onglet Séances, carte de la séance clôturée | 2 | 0 |
| 2 | `/seances/:id` | Menu « ⋮ » → « Point financier » | 4 | 0 |
| 3 | `/seances/:id/finances` | Cotisation 100 F, tous les participants préremplis à 100 F | — | — |
| 4 | idem | « Retard / sanction » (Alice) → pénalité 200 F et motif → « Enregistrer » | 6 | 2 |
| 5 | idem | Bruno : cotisation reçue à 0 (impayé) ; Alice : pénalité reçue 200 | 6 | 4 |
| 6 | idem | « Valider le point » → récapitulatif (1000 + 200 = 1200 F, variation de caisse 1200 F) → « Confirmer » → snackbar « Point enregistré sur ce téléphone. » | 8 | 4 |
| 7 | `/finances` | Caisse 1200 F ; situation des membres : Alice 300/300, Bruno 0/100 « Cotisations impayées » −100 | +1 depuis l'accueil | 0 |

**Total : 8 clics, 4 champs** (9 clics avec `/finances`).

- Le récapitulatif avant validation est un bon garde-fou.
- Frictions : UX-009. La touche « Retard / sanction » de la première carte est recouverte par le pied fixe « Total encaissé » et « Valider le point » : il faut faire défiler pour l'atteindre.
- Après un rechargement sur `/seances/:id/finances`, il n'y a ni flèche Retour ni barre d'onglets (UX-007).
- Capture : `ux-05-point-financier-recap.png`.

## Constats

### UX-001 — « Annuler » du snackbar de carton annule la dernière action du journal, pas le carton
- Sévérité : Majeur / Domaine : Parcours (saisie en direct) / Statut : confirmé (reproduit)
- Preuve :
  - Reproduction : carton jaune à Alice (snackbar « Carton jaune attribué à Alice — Annuler », qui reste affiché), puis but de Hugo pour l'autre équipe, puis appui sur « Annuler » du snackbar, toujours visible. Résultat : le score passe de 1-1 à 1-0, le but de Hugo disparaît du journal, le carton d'Alice reste.
  - Code : `live_stats_panel.dart:113-123` affiche le snackbar après `_openDisciplineSheet`, avec `onPressed: () => mutate(null)` (ligne 121). `mutate(null)` est l'annulation générique de la dernière opération, la même que le bouton « Annuler la dernière action » (ligne 216).
  - Le snackbar persiste tant qu'une autre action ne l'a pas remplacé (constaté) et il recouvre la zone des « + » des derniers joueurs (y ≈ 828 px sur 852).
- Impact : un score ou une statistique peut être faussé sans que l'utilisateur s'en aperçoive. Le libellé promet d'annuler le carton.
- Recommandation : annuler l'opération précise (identifiant de l'opération du carton) ou masquer le snackbar dès qu'une autre action est enregistrée. Ajouter un test de widget « carton puis but puis Annuler du snackbar ».
- Effort : S

### UX-002 — Récupération d'accès impossible : aucun code de secours créé ni régénérable depuis l'app
- Sévérité : Majeur / Domaine : Parcours (accès partagé) / Statut : confirmé (code et exécution)
- Preuve :
  - La charge d'inscription `shared_group_screen.dart:159-169` ne contient pas `recovery_code`.
  - Côté API, le code est optionnel (`backend/app/main.py:101`, `383-399`) : sans lui, aucun `admin["recovery"]` n'est créé.
  - La régénération `PUT …/account/recovery-code` n'a aucun appelant. `grep -rn "recovery-code" mobile/lib web/*.mjs` ne renvoie rien, ce qui est cohérent avec `docs/architecture/vue-densemble.md:53`.
  - Exécution : « Mot de passe oublié ? » → « Réinitialiser » → `POST /auth/recover` 401 → « Récupération impossible. Vérifiez vos informations. »
  - L'écran n'a jamais affiché de code de secours à la création. [déduit] Cela vaut pour tout Admin créé depuis l'app.
- Impact : le flux livré par ACCESS-07 est exposé mais ne peut jamais aboutir. Un Admin seul qui perd son mot de passe perd l'administration du groupe. Le seul recours est un co-admin (ACCESS-02).
- Recommandation : générer et afficher un code de secours à la création (avec confirmation « je l'ai noté »), ajouter la régénération dans « Accès de … », ou masquer le lien tant qu'aucun code n'existe (le snapshot expose `recovery.configured`, `main.py:526-528`).
- Effort : M

### UX-003 — Identifiant de groupe sans `#` refusé avec « 401: Identifiants incorrects »
- Sévérité : Majeur / Domaine : Parcours (connexion) / Statut : confirmé
- Preuve : l'identifiant affiché est « #13120987 ». La saisie `13120987` avec le bon mot de passe donne `POST /auth/login` 401 et « 401: Identifiants incorrects ». La saisie `#13120987` connecte. `_connectOnce` transmet `_group.text.trim()` sans normalisation (`shared_group_screen.dart:136`). Après déconnexion, le champ « Identifiant du groupe » n'est pas prérempli, alors que l'appareil connaît le groupe.
- Impact : les membres qui recopient l'identifiant sans le `#` reçoivent un message qui accuse leurs identifiants. Risque d'appels au gestionnaire et de demandes de réinitialisation inutiles.
- Recommandation : accepter l'identifiant avec ou sans `#` (normalisation client, voire serveur) et préremplir le dernier groupe connu.
- Effort : XS

### UX-004 — Déconnexion sans confirmation, feedback trompeur, mot de passe laissé dans le formulaire
- Sévérité : Mineur / Domaine : Parcours / Statut : confirmé
- Preuve : « Se déconnecter » appelle directement `_perform(service.disconnect)` (`shared_group_screen.dart:1651`). `_perform` affiche ensuite « Données mises à jour. » (ligne 107). Après déconnexion, l'écran revient sur le formulaire « Partager » (création), avec l'identifiant Admin et les deux mots de passe toujours remplis (masqués, mais révélables par l'icône œil). Constaté sur capture.
- Impact : une déconnexion accidentelle est possible. Le message est faux. Sur un appareil partagé, le mot de passe Admin reste révélable, et un nouvel appui sur « Créer le groupe partagé » relance une inscription.
- Recommandation : demander confirmation, vider les contrôleurs de mots de passe, afficher « Vous êtes déconnecté » et revenir sur « Rejoindre ».
- Effort : S

### UX-005 — Création de groupe partagé sans validation client, erreurs génériques préfixées du code HTTP
- Sévérité : Mineur / Domaine : Parcours / Statut : confirmé
- Preuve : un formulaire vide ou un mot de passe de 5 caractères sont envoyés tels quels (`POST /groups` 422), alors que le placeholder annonce « Au moins 8 caractères ». Le message est « 422: Les données saisies sont invalides. Vérifiez les champs requis et leur format. », sans champ en erreur. Le préfixe vient de `SharedApiException.toString` → `'$statusCode: $message'` (`mobile/lib/core/data/shared_http_error.dart:17`). Même préfixe sur « 401: Identifiants incorrects ». Le formulaire de récupération, lui, valide côté client (checklist et « Les mots de passe ne correspondent pas »).
- Impact : un aller-retour réseau par essai, et l'utilisateur ne sait pas quel champ corriger.
- Recommandation : réutiliser `password_policy.dart` et la checklist de la récupération sur la création, et retirer le code HTTP des messages.
- Effort : S

### UX-006 — Doublon de joueur accepté à l'ajout initial et retrait sans confirmation
- Sévérité : Mineur / Domaine : Parcours (onboarding) / Statut : confirmé
- Preuve :
  - « alice » a été ajouté alors qu'« Alice » existait (12 joueurs listés).
  - `_addPlayer` (`add_team_players_screen.dart:41-57`) n'appelle pas `isNameTaken`, alors que `new_player_bottom_sheet.dart:76-90` refuse avec « Un joueur nommé « … » existe déjà ».
  - La corbeille (lignes 540-555) supprime immédiatement, sans confirmation ni annulation (constaté).
- Impact : des doublons apparaissent dès la création, et le même geste n'a pas la même règle selon l'écran. Le retrait accidentel est sans conséquence sur l'historique (le joueur est neuf), mais l'utilisateur n'en a aucun retour.
- Recommandation : appliquer `isNameTaken` dans l'ajout rapide et proposer « Annuler » après un retrait.
- Effort : XS

### UX-007 — Écrans hors onglets sans flèche Retour après rechargement ou lien direct
- Sévérité : Mineur / Domaine : Navigation web / Statut : confirmé
- Preuve : `/finances`, `/groupe-partage` et `/seances/:id/finances` sont déclarées sur le navigateur racine, hors du `StatefulShellRoute` (`app_router.dart:82-86`). Après `reload()` sur `/seances/:id/finances` ou `/groupe-partage`, la sémantique ne contient aucun bouton « Retour » et il n'y a pas de barre d'onglets. `/finances` ouvert par URL n'a pas non plus de flèche.
- Impact : sur le web, un F5 ou un lien partagé mène à une impasse. Seul le bouton du navigateur permet d'en sortir, et il est inutilisable dans un onglet neuf.
- Recommandation : un `leading` de repli `context.go('/')` (ou vers la route parente) quand `!context.canPop()`, comme le fait déjà `player_detail_screen.dart:82-86`.
- Effort : S

### UX-008 — Retour navigateur depuis une séance démarrée : assistant réinitialisé
- Sévérité : Mineur / Domaine : Navigation / Statut : confirmé
- Preuve : après « Débuter la séance », `new_session_screen.dart:213-214` fait `context.go('/seances')` puis `context.push('/seances/$id')`. Avec `optionURLReflectsImperativeAPIs`, l'historique conserve `/seances/nouvelle` : le retour navigateur depuis la séance affiche l'assistant vierge (nouvelle date et heure), puis l'accueil. La flèche de l'app ramène à l'accueil.
- Impact : comportement incohérent entre la flèche et le bouton du navigateur, avec un risque de recommencer une séance. Le garde-fou « séance déjà en cours, brouillon » (ligne 718) limite les dégâts.
- Recommandation : remplacer l'entrée d'historique (`replace`) au démarrage de la séance.
- Effort : S

### UX-009 — Point financier : cotisations préremplies « payées », saisie de montant malcommode
- Sévérité : Mineur / Domaine : Parcours finances / Statut : confirmé
- Preuve :
  - À l'ouverture, les 11 participants affichent « Cotisation reçue 100 » et « Total encaissé 1100 F ». La consigne demande d'« effacer les montants des impayés avant de valider » : le défaut est donc « payé ».
  - Le champ de pénalité contient « 0 » non sélectionné : taper « 200 » donne « 0200 » (interprété 200).
  - Le snackbar final dit « Point enregistré sur ce téléphone. » sur le web (`financial_point_screen.dart:268`).
  - Le bouton « Retard / sanction » de la première carte est sous le pied fixe.
- Impact : un trésorier pressé enregistre des encaissements fictifs. Le récapitulatif de confirmation atténue le risque sans l'éliminer.
- Recommandation : à arbitrer en métier (renvoi A). Option : défaut « non saisi » et bouton « Tous ont payé ». Sélectionner le contenu au focus, et dire « sur cet appareil ».
- Effort : S

### UX-010 — Onboarding : progression et libellés trompeurs
- Sévérité : Mineur / Domaine : Parcours (onboarding) / Statut : confirmé
- Preuve :
  - « Étape 2 sur 2 · Effectif » (`add_team_players_screen.dart:98`), puis le bouton « Continuer vers l'accès Admin » ouvre une 3e étape sans indicateur, avec un autre habillage (barre verte).
  - Le placeholder de « Votre identifiant » (Admin) est « Ex. : membres » (`shared_group_screen.dart:1074`), qui est justement l'identifiant commun prérempli plus bas.
  - En venant de l'accueil, `/groupe-partage` s'ouvre sur l'onglet « Rejoindre » alors que l'utilisateur a déjà un groupe local à partager.
  - Le snackbar de bienvenue est tronqué.
- Impact : désorientation et risque de choisir « membres » comme identifiant Admin.
- Recommandation : « Étape 2 sur 3 » plus un indicateur sur l'étape accès, placeholder « Ex. : prenom.nom », onglet « Partager » par défaut quand un groupe local non partagé existe.
- Effort : XS

### UX-011 — 320x640 : navigation tronquée, actions non collantes, bande fixe
- Sévérité : Mineur / Domaine : Ergonomie petit écran / Statut : confirmé
- Preuve :
  - Capture `ux-06` : l'onglet « Stats » est coupé à droite et « Voir tout » passe sous la barre.
  - `new_session_screen.dart:289-291` : `scrollChrome` est vrai si la largeur est inférieure à 360. « Continuer » et « Débuter la séance » ne sont alors visibles qu'en bas de liste (3 défilements pour 8 joueurs, davantage avec 20 joueurs).
  - `browser_app_frame.dart:21-24` réserve au moins 64 px en haut de chaque écran pour le menu « Application » (`mobile/web/app-shell.js`), soit 10 % de la hauteur en 640.
- Impact : effort accru sur les petits téléphones, cibles de la charte (320 dp).
- Recommandation : libellés plus courts ou icônes seules sous 360 px, garder le bouton principal collant (en réduisant son padding), et réduire la bande (menu repliable dans la barre d'app).
- Effort : S

### UX-012 — Saisie en direct et clôture : découvrabilité et libellés
- Sévérité : Mineur / Domaine : Parcours séance / Statut : confirmé
- Preuve :
  - Les cartons ne s'ouvrent que par appui sur le nom du joueur (feuille « Discipline · Alice »), sans indice visuel. La ligne n'a qu'un « + » de but.
  - La confirmation de clôture affiche « Victoire Équipe A (1 – 0) » (`session_detail_screen.dart:1226-1228`) alors que les équipes portent des noms (« Union des Collines »). Le dialogue de célébration, lui, utilise le nom.
  - Le dialogue de célébration garde une zone vide de 80 px après l'animation des confettis (`session_celebration.dart:62-75`, capture `ux-02`).
- Impact : la fonction carton est difficile à trouver et les libellés de résultat sont incohérents.
- Recommandation : icône « carton » sur la ligne ou indice « Touchez un joueur pour les cartons », utiliser `teamName` dans le résumé, et replier l'espace des confettis en fin d'animation.
- Effort : S

### UX-013 — Classement : égalités sans ex æquo
- Sévérité : Mineur / Domaine : Consultation / Statut : confirmé
- Preuve : Alice, Bruno, Cedric, David, Eric et Fabrice ont tous 3 pts et 1 V. Ils sont classés 1 à 6 par ordre alphabétique, avec médailles or, argent et bronze pour les trois premiers. `ranking_repository.dart:86` : `ROW_NUMBER() OVER (ORDER BY points DESC, wins DESC, matches_played DESC, name ASC)`. Les buts ne départagent pas (Bruno, 0 but, devant Cedric, 1 but).
- Impact : un podium arbitraire est perçu comme injuste dans un groupe d'amis.
- Recommandation : `RANK()` ou un affichage « ex æquo », et un critère de départage documenté (renvoi métier).
- Effort : S

### UX-014 — Contrôles sans libellé accessible
- Sévérité : Mineur / Domaine : Accessibilité des parcours / Statut : confirmé
- Preuve : dans l'arbre sémantique, plusieurs nœuds apparaissent sans libellé :
  - la flèche de la fiche joueur (`player_detail_screen.dart:82`, `IconButton` sans `tooltip`) ;
  - le FAB d'ajout de joueur (`players_screen.dart:186`) ;
  - le bouton de fermeture et les icônes œil de la feuille de récupération ;
  - un bouton de la boîte « Nouveau joueur » ;
  - tous les champs de saisie (aucun libellé associé).
- Impact : un lecteur d'écran ne peut pas mener les parcours 3 et 4.
- Recommandation : `tooltip` sur les `IconButton` et le FAB, `labelText` ou `Semantics(label:)` sur les champs (renvoi UI/accessibilité).
- Effort : S

### UX-015 — Création de gestionnaire : mot de passe généré jamais montré
- Sévérité : Mineur / Domaine : Parcours partagé / Statut : confirmé
- Preuve : la feuille annonce « Un mot de passe de 8 caractères sera généré automatiquement ». Après « Créer », la feuille se ferme et le compte apparaît dans la liste, sans message. Le mot de passe n'est accessible que via « Accès de tresorier.bruno » → « Copier les accès », qui le copie dans le presse-papiers sans l'afficher.
- Impact : l'Admin doit deviner où récupérer l'accès à transmettre. Si le presse-papiers est indisponible, il n'a aucun moyen de le lire.
- Recommandation : enchaîner sur un écran « Accès créé » avec copie et partage, et un affichage à la demande.
- Effort : S

### UX-016 — « Score absent » inatteignable, déséquilibre bloqué au démarrage
- Sévérité : Info / Domaine : Parcours séance / Statut : confirmé
- Preuve :
  - Le score est dérivé des buts saisis. La clôture sans but propose « Match nul (0 – 0) ». Le cas « score absent » de `AGENTS.md` §5 ne se présente donc pas dans l'UI.
  - Un 7 contre 4 est refusé dès « Débuter la séance » avec un message clair.
  - Le minimum de joueurs est rappelé avec un renvoi aux réglages.
- Impact : positif. La clôture invalide ne peut être testée que par les tests de domaine.
- Effort : —

### UX-017 — Attente réseau de 90 s sans annulation
- Sévérité : Mineur / Domaine : Feedback / Statut : confirmé (le blocage serveur venait de PERF-001, le comportement d'UI vient de l'app)
- Preuve : pendant l'interblocage de l'API locale, le bouton est resté « Connexion en cours… » et désactivé pendant plus de 30 s, avec les onglets « Rejoindre » et « Partager » désactivés et sans bouton d'annulation. Le délai client est de 90 s (`shared_http_browser.dart:21`).
- Impact : sur un réseau de terrain lent, l'utilisateur ne peut ni annuler ni comprendre l'attente.
- Recommandation : délai plus court pour la connexion (15 à 20 s), bouton « Annuler » et message de progression.
- Effort : S

### UX-018 — Fonctions d'accès sans UI, minimum de joueurs figé en mode partagé
- Sévérité : Mineur / Domaine : Couverture fonctionnelle / Statut : confirmé
- Preuve :
  - La matrice `docs/architecture/vue-densemble.md:52-53` est revérifiée par `grep` : aucun appel mobile ni portail à `POST …/account/password` (ACCESS-03) ni à `PUT …/account/recovery-code`.
  - `PUT …/sport-settings` n'est appelé que par le portail (`web/app.mjs:2573`).
  - En mode partagé, le réglage « Joueurs minimum requis » est désactivé (`settings_screen.dart:111`, `!sharedSportSettings`). Le message de la séance renvoie pourtant « aux réglages ».
- Impact : un gestionnaire ne peut pas changer son propre mot de passe. En groupe partagé, le minimum de joueurs ne se modifie que depuis le portail historique, que l'UI mobile ne mentionne pas.
- Recommandation : écran « Mon compte » (mot de passe, code de secours) et édition du minimum pour les rôles sport, ou au moins un message « modifiable par … ».
- Effort : M

## Hypothèses à vérifier

- [déduit] UX-001 peut aussi toucher l'annulation d'un carton retiré (`isDecrement`), qui déclenche le même `mutate(null)`. Non reproduit.
- [déduit] Le défaut « payé » du point financier (UX-009) vient peut-être d'une règle métier voulue (ristourne, paiement d'avance) : à arbitrer avec le domaine A.
- La touche « Retard / sanction » sous le pied fixe dépend de la hauteur d'écran. Vérifier en 320x640.
- Portail `web/` (lecture statique) : pas de récupération d'accès (`grep recovery web/app.mjs` vide), une seule confirmation `confirm()` (`web/app.mjs:864`). Il diffère donc du parcours 4 et n'offre pas le flux ACCESS-07.

## Points positifs (Info)

- Les confirmations explicites des actions destructrices précisent ce qui sera perdu : suppression de séance en cours, suppression de joueur sans historique, archivage du joueur avec historique (« ne peut être qu'archivé pour préserver les statistiques »).
- Saisie au clavier de l'effectif (Entrée, Entrée, retour du focus sur le nom), « Tout cocher », « Tirer au sort » avec noms et couleurs d'équipes.
- Saisie d'un but en 2 gestes, avec un journal des « Dernières actions » et « Modifier ce but ».
- Récapitulatif chiffré avant la validation du point financier, et vue `/finances` claire (payé, attendu, écart).
- Feuille de récupération : préremplissage, checklist de mot de passe en direct et message d'échec non énumérant.
- Thème sombre cohérent et lisible en 320x640.

## Renvois vers d'autres domaines

- **H / performance** : polices `fonts.gstatic.com` (Noto Sans Symbols 2, SC, TC, HK) demandées à l'exécution. Hors ligne, le glyphe « ✓ » de l'onboarding s'affiche en carré.
- **H / performance** : l'interblocage de l'API (verrou global `threading.Lock` sur la dépendance `db`, `backend/app/main.py:284-300`) a figé jusqu'à `/health` (PERF-001).
- **Sécurité** : le mot de passe Admin reste dans le formulaire après déconnexion (UX-004), et l'onboarding web garde l'accès Admin sur l'appareil.
- **Métier (A)** : départage du classement (UX-013) et défaut « payé » des cotisations (UX-009).
- **UI / accessibilité (C)** : sélection « Match (2 équipes) » en orange alors que le reste des sélections est vert, champ « Nom court » au style différent, flèche « ← » ou chevron « < » selon les écrans, champs sans libellé (UX-014).

## Vérification croisée (Phase 4, 14/11/2026)

UX-001, UX-002 et UX-003 relus par la session principale et **confirmés** : `mobile/lib/features/sessions/presentation/live_stats_panel.dart:118-121` (`mutate(null)` déclenche `recordLive(…, null)`, donc l'annulation de la dernière action du journal, pas du carton) ; UX-002 doublonne MET-005 (`shared_group_screen.dart:159-169`) ; UX-003 reproduit à l'exécution.
