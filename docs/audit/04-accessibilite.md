# Audit Statoo — 04. Accessibilité (WCAG 2.2 AA)

- **Domaine** : accessibilité. Référentiel : WCAG 2.2, niveau AA. Préfixe : A11Y-.
- **Date** : 14/11/2026. Arbre de travail de la branche `fix/mobile-red-tests` (HEAD `2a9a3c7`).
- **Méthode** :
  - **Statique** sur `mobile/lib`. J'ai compté les `IconButton`, `FloatingActionButton` et `TextField`/`TextFormField` avec un script qui équilibre les parenthèses, puis j'ai relu chaque cas à la main. J'ai cherché par `grep` `Semantics`, `liveRegion`, `GestureDetector`, `VisualDensity`, `textScaler` et `disableAnimations`. J'ai calculé les ratios de contraste WCAG de toutes les paires de tokens de `mobile/lib/core/theme/app_colors.dart`, en clair et en sombre.
  - **Exécuté** sur le build Flutter web release local (`http://127.0.0.1:18090`, API isolée `127.0.0.1:18085`), avec Playwright et Chrome. Les requêtes hors `127.0.0.1` sont bloquées. L'arbre d'accessibilité vient de CDP `Accessibility.getFullAXTree` et de `locator.ariaSnapshot()`, car `page.accessibility.snapshot()` n'existe plus dans la version de Playwright installée. Écrans couverts : onboarding, création d'équipe, effectif initial, accès Admin, accueil, liste et fiche joueur, feuille « Nouveau joueur », nouvelle séance (étapes 1 et 2) et détail de séance en cours. J'ai testé la navigation au clavier (Tab, Maj+Tab, Entrée, Espace, Échap) sur l'onboarding, le formulaire de création d'équipe, l'accueil et la feuille « Nouveau joueur ». J'ai mesuré le texte à 200 % (taille de police racine du document à 32 px) et la redistribution à 320 px.
  - **Portail `web/`** : revue statique rapide (`index.html`, `app.mjs`, `styles.css`).
- **Limites** :
  - Aucun outil automatique (axe, pa11y, Lighthouse) n'est installé et je n'en ai pas installé. Aucun test avec un vrai lecteur d'écran (TalkBack, VoiceOver, NVDA). L'arbre observé est celui que Flutter web expose au navigateur. Il diffère de l'arbre natif Android et iOS.
  - Le thème clair n'a pas été observé à l'écran. Les contrastes sont calculés sur couleurs pleines, sans les teintes alpha.
  - Les parcours « groupe partagé » (connexion API) et finances n'ont pas été exécutés. L'API locale a été relancée vers 16:25 après un test de charge d'un autre agent (PERF-001). Aucune de mes étapes ne dépendait de l'API, car j'ai choisi « Continuer sur cet appareil ». Aucun constat ci-dessous ne vient d'un échec réseau.
  - Les comptages statiques sont approximatifs : un nom accessible peut venir d'un `Semantics` parent. Chaque cas cité a été relu.
- Scripts : scratchpad `a11y/` (hors dépôt). Captures : `docs/audit/raw/captures/accessibilite-01-focus-peu-visible.png`, `accessibilite-02-focus-hors-modale.png`.

## Synthèse

L'application a de bonnes bases. Le texte agrandi est respecté sans plafond, et des tests à 200 % existent. La page déclare `lang="fr"` et la redistribution à 320 px tient sans défilement horizontal. Les écrans du cœur métier (composition, détail de séance) donnent un nom explicite à presque tous leurs boutons, et la navigation basse expose `aria-current`.

Quatre défauts importants touchent les personnes qui naviguent au **clavier** ou au **lecteur d'écran** :

- L'indicateur de focus de Flutter web est presque invisible : 1,15:1 par rapport à l'état non focalisé.
- Plusieurs commandes construites avec `GestureDetector` ne sont pas atteignables au clavier : « Suivant » de l'onboarding, « Voir tout », « Sauvegarder », « Photo ».
- 16 `IconButton` et 1 `FloatingActionButton` n'ont pas de nom accessible. Parmi eux : « Ajouter un joueur », le retour de la fiche joueur et les fermetures de feuilles.
- Plusieurs champs de saisie n'ont pour nom que leur texte d'exemple, et ce nom disparaît dès que le champ est rempli.

Viennent ensuite des défauts de second rang : le focus sort des feuilles modales, les changements de score ne sont pas annoncés, les états sélectionnés ne sont pas exposés, les titres de section ne sont pas balisés et les animations de l'onboarding tournent en boucle.

**Note proposée : 2,5/5.** Aucun parcours n'est totalement bloqué : l'onboarding peut être passé avec « Passer » et la plupart des actions métier sont nommées et focalisables. Mais un utilisateur au clavier ne voit pas où il se trouve, et un utilisateur de lecteur d'écran rencontre des boutons muets sur des actions principales. Aucun test automatisé de règle d'accessibilité (`meetsGuideline`) ne protège ces acquis.

## Tableau récapitulatif

| ID | Sévérité | Titre | Fichier principal | Effort |
|---|---|---|---|---|
| A11Y-001 | Majeur | Indicateur de focus clavier quasi invisible sur Flutter web (1,15:1) | `mobile/lib/core/theme/app_theme.dart` | S |
| A11Y-002 | Majeur | Commandes `GestureDetector` exposées comme boutons mais hors de l'ordre de tabulation | `mobile/lib/features/onboarding/presentation/onboarding_screen.dart` | M |
| A11Y-003 | Majeur | 16 `IconButton`, 1 FAB et 1 bouton « + » sans nom accessible | `mobile/lib/features/players/presentation/players_screen.dart` | S |
| A11Y-004 | Majeur | Champs nommés seulement par leur `hintText`, nom perdu une fois le champ rempli | `mobile/lib/features/players/presentation/new_player_bottom_sheet.dart` | S |
| A11Y-005 | Mineur | Le focus sort des feuilles modales vers la navigation basse | `mobile/lib/features/players/presentation/players_screen.dart` | S |
| A11Y-006 | Mineur | Messages d'état non annoncés (score, but enregistré, erreur de saisie) | `mobile/lib/features/sessions/presentation/session_detail_screen.dart` | S |
| A11Y-007 | Mineur | États sélectionnés non exposés (format de jeu, mode de restauration, page d'onboarding) | `mobile/lib/features/team/presentation/create_team_screen.dart` | S |
| A11Y-008 | Mineur | Titres de section non balisés, titre d'accueil dupliqué | `mobile/lib/features/home/presentation/home_screen.dart` | S |
| A11Y-009 | Mineur | Animations infinies de l'onboarding sans pause ni respect de la réduction de mouvement | `mobile/lib/features/onboarding/presentation/onboarding_screen.dart` | XS |
| A11Y-010 | Mineur | Paires de contraste sous 4,5:1 non couvertes par UI-006 et bordures de champs sous 3:1 | `mobile/lib/core/theme/app_colors.dart` | S |
| A11Y-011 | Mineur | Noms ambigus ou répétitifs (« Supprimer ce joueur » ×N, « Stats 0 0 », « 1 buts ») | `mobile/lib/features/players/presentation/players_screen.dart` | XS |
| A11Y-012 | Mineur | Contenu décoratif lu par le lecteur d'écran, statistiques de la fiche joueur sans structure | `mobile/lib/features/onboarding/presentation/onboarding_screen.dart` | S |
| A11Y-013 | Mineur | Cibles compactes sous la règle interne de 48 dp (WCAG 2.5.8 respecté sur les mesures) | `mobile/lib/features/settings/presentation/settings_screen.dart` | XS |
| A11Y-014 | Mineur | Aucun test automatisé des règles d'accessibilité Flutter | `mobile/test/accessibility/commands_test.dart` | S |

Décompte : 0 critique, 4 majeurs, 10 mineurs.

## Constats

### A11Y-001 — Indicateur de focus clavier quasi invisible sur Flutter web
- Sévérité : Majeur / Domaine : accessibilité, clavier / Statut : confirmé (exécuté)
- Critères : 2.4.7 Visibilité du focus, 1.4.11 Contraste du contenu non textuel.
- Preuve :
  - Onboarding en thème sombre, 393×852, une pression sur Tab : le focus passe sur « Passer » (`flt-semantics role=button`, 71×32). J'ai comparé deux captures de la même zone, sans focus puis avec focus : 1 988 pixels changent sur 4 560, et la couleur dominante passe de `rgb(11,15,20)` à `rgb(13,33,28)`. **Le ratio entre les deux états est de 1,15:1**. Capture : `docs/audit/raw/captures/accessibilite-01-focus-peu-visible.png`.
  - L'élément focalisé du DOM sémantique (`FLT-SEMANTICS`) a `outline: auto 1px rgb(16,16,16)`, posé sur un nœud transparent et donc invisible. Seul le surlignage Material de focus est rendu.
  - `mobile/lib/core/theme/app_theme.dart` ne définit ni `focusColor` ni aucun style de focus (un `grep focusColor|highlightColor` ne renvoie rien).
  - Sur le formulaire de création d'équipe, le bouton « 6v6 » focalisé puis activé à l'Espace ne se distingue que par son état sélectionné. Le focus seul n'est pas repérable.
- Impact : sur Flutter web, un utilisateur au clavier ne voit pas quel élément a le focus. La navigation devient pratiquement impossible sans souris.
- Recommandation : définir dans `AppTheme`, pour les deux thèmes, un `focusColor` contrasté et des bordures de focus explicites (`WidgetStateProperty` sur `focused` dans les styles de boutons, `focusedBorder` des champs). Cible : au moins 3:1 contre les couleurs adjacentes. Ajouter un test widget qui vérifie le style focalisé du bouton principal.
- Effort : S

### A11Y-002 — Commandes `GestureDetector` hors de l'ordre de tabulation
- Sévérité : Majeur / Domaine : accessibilité, clavier / Statut : confirmé (exécuté pour 4 commandes ; [déduit] pour les autres)
- Critères : 2.1.1 Clavier, 4.1.2 Nom, rôle et valeur.
- Preuve :
  - Exécuté. Inventaire des `flt-semantics[role=button]` : « Suivant » (onboarding), « Classement Voir tout » et « Aucune sauvegarde cloud Sauvegarder » (accueil) ont `tabindex=null`. Les autres boutons ont `tabindex="0"`.
  - Sur l'onboarding, la séquence de Tab est « Passer » → `body` → `summary` « Application » → « Passer ». **« Suivant » n'est jamais atteint.**
  - Sur l'accueil, 22 Tab passent par « Réglages », « Nouvelle séance », « Joueur du mois », les cartes, les finances et la navigation, mais jamais par « Voir tout » ni par « Sauvegarder ».
  - Dans la feuille « Nouveau joueur », le bouton « Photo » n'est jamais atteint (cycle : Nom → Surnom → Annuler → navigation basse → Nom).
  - Code correspondant :
    - `mobile/lib/features/onboarding/presentation/onboarding_screen.dart:242` (`GestureDetector(onTap: _nextPage`) ;
    - `mobile/lib/features/home/presentation/home_screen.dart:579` et `:908` ;
    - `mobile/lib/features/players/presentation/new_player_bottom_sheet.dart:189`.
  - Autres `GestureDetector` cliquables, même motif, non exécutés :
    - `mobile/lib/features/settings/presentation/settings_screen.dart:568` et `:640` (choix Fusionner / Remplacer de la restauration) ;
    - `mobile/lib/features/shared/presentation/recovery_confirmation_sheet.dart:148` (case d'acquittement) ;
    - `mobile/lib/features/sessions/presentation/sessions_screen.dart:152` (filtres, déjà relevé en UI-010) ;
    - `mobile/lib/features/sessions/presentation/team_tab_pill.dart:31`.
  - Le widget partagé `mobile/lib/core/widgets/app_card.dart:32` enveloppe aussi `onTap` dans un `GestureDetector`, et 12 des 54 `AppCard(` reçoivent un `onTap`. Leur focalisabilité n'a pas été vérifiée une par une (voir Hypothèses).
- Impact : au clavier, l'onboarding ne se parcourt pas page par page : seul « Passer » permet d'avancer. « Voir tout » (classement), le raccourci « Sauvegarder », l'ajout de photo et le choix du mode de restauration sont inaccessibles sans pointeur.
- Recommandation : remplacer ces `GestureDetector` par `InkWell`, `TextButton`, `ChoiceChip` ou `RadioListTile`, qui sont focalisables et activables à Entrée et Espace. Modifier `AppCard` pour utiliser `InkWell`. Ajouter un test qui parcourt l'écran avec `FocusTraversal` ou `sendKeyEvent(Tab)` et vérifie que chaque commande est atteinte.
- Effort : M

### A11Y-003 — Boutons icônes sans nom accessible
- Sévérité : Majeur / Domaine : accessibilité, lecteur d'écran / Statut : confirmé
- Critères : 4.1.2 Nom, rôle et valeur, 1.1.1 Contenu non textuel.
- Preuve :
  - Statique : 16 `IconButton` sur 60 n'ont ni `tooltip` ni `Semantics` parent. Une icône de police Remix n'a pas de libellé, donc le bouton est muet. Liste :
    - `recovery_request_sheet.dart:172,244,271` et `recovery_confirmation_sheet.dart:96` (fermer, retour) ;
    - `player_detail_screen.dart:43,82,131,143` (retour, actions) ;
    - `edit_player_bottom_sheet.dart:144` (fermer) ;
    - `players_screen.dart:216` (effacer la recherche) ;
    - `settings_screen.dart:50` (retour), `:108` et `:133` (−/+ joueurs minimum) ;
    - `mvp_weights_section.dart:106,129` (−/+ des pondérations MVP) ;
    - `team_switcher_bottom_sheet.dart:96` (fermer).
  - Statique : `FloatingActionButton` de `mobile/lib/features/players/presentation/players_screen.dart:186` sans `tooltip`. Celui de `sessions_screen.dart:89` en a un.
  - Statique : `OutlinedButton` « + » (créer puis ajouter un autre joueur) avec une simple `Icon` en enfant, sans libellé (`mobile/lib/features/players/presentation/new_player_bottom_sheet.dart:350-371`).
  - Exécuté, liste Joueurs : un `button` sans nom apparaît en plus des boutons nommés (ce n'est que le FAB « ajouter un joueur »). Fiche joueur : le premier élément est un `button` sans nom (retour). Feuille « Nouveau joueur » : `button [disabled]` sans nom entre « Annuler » et « Créer ».
- Impact : sur la liste Joueurs, l'action principale d'ajout est annoncée « bouton », sans plus. Le retour de la fiche joueur et la fermeture de plusieurs feuilles ne sont pas identifiables. Les boutons −/+ des réglages ne disent pas ce qu'ils modifient.
- Recommandation : ajouter `tooltip:` en français (« Retour », « Fermer », « Ajouter un joueur », « Effacer la recherche », « Diminuer le nombre minimal de joueurs »…). Pour l'`OutlinedButton`, utiliser `Semantics(label: 'Créer et ajouter un autre joueur')` ou `OutlinedButton.icon`. Étendre `test/accessibility/commands_test.dart` (A11Y01 couvre déjà le retour de certains écrans) à ces écrans.
- Effort : S

### A11Y-004 — Champs nommés seulement par leur texte d'exemple
- Sévérité : Majeur / Domaine : accessibilité, formulaires / Statut : confirmé
- Critères : 1.3.1 Information et relations, 3.3.2 Étiquettes ou instructions, 4.1.2 Nom, rôle et valeur, 2.5.3 Étiquette dans le nom.
- Preuve :
  - Statique : 15 champs sur 36 n'ont ni `labelText` ni `label`. Le libellé visible est un `Text` frère, non relié au champ. Par exemple :
    - `new_player_bottom_sheet.dart:237` (`hintText: 'Karim Benali'`, libellé visible « Nom * » à la ligne 222) et `:298` (« Kaka » pour « Surnom ») ;
    - `create_team_screen.dart:242` et `:377` ;
    - `add_team_players_screen.dart:245,302` ;
    - `recovery_request_sheet.dart:332` ;
    - `financial_point_screen.dart:637`, champ de taux dans un `AlertDialog`, ni libellé ni indication.
  - Le motif correct existe déjà, avec un `Semantics(label:)` autour du champ : `create_team_screen.dart:290`, `shared_group_screen.dart:1062`, `financial_point_screen.dart:852`.
  - Exécuté, création d'équipe : le champ de nom est exposé `textbox "ex: FC Urban, Les Galactiques..."` alors que le libellé visible est « Nom de l'équipe ou du groupe * ». Feuille Nouveau joueur : `textbox "Karim Benali"`.
  - Exécuté, effectif initial : après saisie de « Alice », le champ devient `textbox: Alice`, **sans nom**. Le nom venait du texte d'exemple, qui disparaît.
- Impact : le lecteur d'écran annonce un exemple (« Karim Benali ») au lieu de la question (« Nom »). Une fois le champ rempli, il n'annonce plus rien. La commande vocale « cliquer sur Nom » échoue.
- Recommandation : utiliser `labelText` (ou `label`), ou envelopper le champ dans `Semantics(label: <libellé visible>)` comme dans `create_team_screen.dart:290`. Garder `hintText` pour l'exemple. Ajouter un test qui vérifie `tester.getSemantics(find.byType(TextField)).label` avant et après saisie. Les champs de recherche (`players_screen.dart:204`, `finances_screen.dart:808`, `add_late_players_bottom_sheet.dart:418`) peuvent garder un nom de type « Rechercher un joueur », mais via `labelText` ou `Semantics`.
- Effort : S

### A11Y-005 — Le focus sort des feuilles modales
- Sévérité : Mineur / Domaine : accessibilité, clavier / Statut : confirmé (exécuté sur « Nouveau joueur »)
- Critères : 2.4.3 Parcours du focus, 1.3.2 Ordre séquentiel logique.
- Preuve :
  - Exécuté. La feuille « Nouveau joueur » est ouverte depuis l'onglet Joueurs. Tab passe de « Annuler » à « Accueil », « Séances », « Joueurs », « Classement » et « Stats » de la navigation basse, restée active et visible derrière la feuille. L'arbre d'accessibilité contient encore ces 5 boutons. Capture : `docs/audit/raw/captures/accessibilite-02-focus-hors-modale.png` (« Séances » focalisé sous la feuille).
  - Statique : 19 `showModalBottomSheet`, dont un seul avec `useRootNavigator: true` (`mobile/lib/features/ranking/presentation/mvp_rules_bottom_sheet.dart:22`). Les autres s'ouvrent dans le navigateur imbriqué du shell, donc au-dessus du contenu mais sous la navigation basse [déduit].
- Impact : l'utilisateur au clavier ou au lecteur d'écran quitte la feuille sans l'avoir fermée. Il peut changer d'onglet avec une saisie en cours.
- Recommandation : passer `useRootNavigator: true` aux feuilles ouvertes depuis les onglets, ou factoriser un `showAppBottomSheet` qui le fait. Tester le cycle de focus dans la feuille.
- Effort : S

### A11Y-006 — Messages d'état non annoncés
- Sévérité : Mineur / Domaine : accessibilité, lecteur d'écran / Statut : confirmé
- Critère : 4.1.3 Messages d'état.
- Preuve :
  - Exécuté sur le détail de séance. J'ai enregistré « Ajouter un but pour Bruno » puis « Aucun passeur ». Le score passe à « 1 - 0 » et le texte « Enregistré sur cet appareil » apparaît. Un `MutationObserver` sur les zones `aria-live` ne relève aucune annonce du score ni de la confirmation : seul l'écho Flutter du bouton touché (« Ajouter un but pour Bruno ») passe dans la zone polie.
  - Exécuté sur l'effectif initial. « Ajouter ce joueur » avec un nom vide marque le champ `[invalid]` et affiche « Veuillez saisir le prénom ou nom du joueur ». Aucune annonce dans `flt-announcement-*`, et le message n'est pas rattaché au champ.
  - Statique : `liveRegion: true` n'apparaît que 3 fois (`edit_player_bottom_sheet.dart:123`, `shared_group_screen.dart:573`, `collective_access_section.dart:289`). Aucun `SemanticsService.announce`.
- Impact : en saisie en direct, un utilisateur de lecteur d'écran ne sait pas si le but est enregistré ni quel est le nouveau score, sauf à explorer l'écran.
- Recommandation : envelopper le score de `session_header.dart` dans `Semantics(liveRegion: true)`, ou appeler `SemanticsService.announce` après chaque action de saisie et d'annulation. Utiliser `errorText` de `InputDecoration` pour les erreurs : il est relié au champ. Les `SnackBar` Material sont déjà annoncés (voir Points positifs).
- Effort : S

### A11Y-007 — États sélectionnés non exposés
- Sévérité : Mineur / Domaine : accessibilité / Statut : confirmé
- Critères : 4.1.2 Nom, rôle et valeur, 1.3.1 Information et relations.
- Preuve :
  - Exécuté, création d'équipe : les boutons « 4v4 », « 5v5 », « 6v6 » et « 7v7 » apparaissent sans état `selected`, `pressed` ni `current`, alors que « 5v5 » est sélectionné par défaut. Code : `mobile/lib/features/team/presentation/create_team_screen.dart:315-322` (`InkWell` sans `Semantics(selected:)`).
  - Exécuté, onboarding : l'indicateur de page (3 points) n'est pas exposé. Rien n'indique « page 1 sur 3 » (`onboarding_screen.dart:219-237`, `_buildPageIndicator`).
  - Statique : Fusionner / Remplacer de la restauration (`settings_screen.dart:568,640`) n'indique la sélection que par la couleur de la bordure.
  - À l'inverse, la navigation basse et le type de séance exposent `aria-current` (voir Points positifs).
- Impact : au lecteur d'écran, on ne sait pas quel format ni quel mode de restauration est retenu. Le second cas touche une opération destructive.
- Recommandation : utiliser `ChoiceChip`, `SegmentedButton` ou `RadioListTile`, ou ajouter `Semantics(selected:, inMutuallyExclusiveGroup: true)`. Pour l'onboarding, ajouter `Semantics(label: 'Page ${i+1} sur 3')`.
- Effort : S

### A11Y-008 — Titres de section non balisés
- Sévérité : Mineur / Domaine : accessibilité, structure / Statut : confirmé
- Critères : 1.3.1 Information et relations, 2.4.6 En-têtes et étiquettes.
- Preuve :
  - Statique : aucun `Semantics(header: true)` dans `mobile/lib`. Les seuls `header:` de `grep` sont des couleurs (`app_colors.dart:117,149,188,216`).
  - Exécuté : chaque écran n'expose qu'un titre, le titre de l'`AppBar` (niveau 2). Les titres internes sont du texte simple : « Classement » sur l'accueil, « Créez votre équipe », « Nouveau joueur » (feuille), « Quand joue-t-on ? », « Suivez vos matchs 5v5 » (onboarding, aucun titre sur l'écran).
  - Exécuté, accueil : le titre est exposé « Les Testeurs Les Testeurs ». Le nom du groupe est lu deux fois.
- Impact : la navigation par titres des lecteurs d'écran ne permet pas de sauter de section en section sur l'accueil, la fiche joueur ou les formulaires.
- Recommandation : créer un widget `SectionTitle` qui applique `Semantics(header: true)` et l'utiliser pour les titres de section et de feuille. Corriger la double lecture du titre d'accueil, par exemple avec `excludeSemantics` sur le texte dupliqué.
- Effort : S

### A11Y-009 — Animations infinies de l'onboarding
- Sévérité : Mineur / Domaine : accessibilité, mouvement / Statut : confirmé (statique)
- Critère : 2.2.2 Mettre en pause, arrêter, masquer. 2.3.3 (AAA) est cité à titre indicatif.
- Preuve : `mobile/lib/features/onboarding/presentation/onboarding_screen.dart:461-464` (`..repeat()` de 4 s, particules), `:710-713` (`..repeat()` de 3 s, rotation) et `:872-875` (`..repeat(reverse: true)`, pulsation). Aucun test de `MediaQuery.disableAnimationsOf` dans ce fichier, et aucun contrôle de pause. Le bon modèle existe : `session_celebration.dart:43,62` respecte `disableAnimationsOf`.
- Impact : du mouvement continu de plus de 5 s, à côté du texte, sans moyen de l'arrêter. Il gêne les personnes sensibles au mouvement ou ayant des troubles de l'attention.
- Recommandation : ne pas lancer `repeat()` si `MediaQuery.disableAnimationsOf(context)` est vrai. Sur le web, Flutter reflète `prefers-reduced-motion` [déduit, à vérifier].
- Effort : XS

### A11Y-010 — Contrastes : paires non couvertes par UI-006, et bordures de champs
- Sévérité : Mineur / Domaine : accessibilité, couleurs / Statut : confirmé (calcul) ; usages exacts [déduit]
- Critères : 1.4.3 Contraste minimal, 1.4.11 Contraste du contenu non textuel.
- Preuve : ratios calculés à partir de `mobile/lib/core/theme/app_colors.dart:164-219`. Je ne reprends pas les cas déjà conclus dans `docs/audit/03-ui.md` (UI-006 : `gold` clair, podium, `primary300` clair, indications en `foreground600` sombre, `foreground500` clair sur fond de page, lettre blanche sur orange).

  | Thème | Texte | Fond | Ratio |
  |---|---|---|---|
  | Clair | `primary500` `#15803D` | `background950` `#E9EEF3` | 4,30 |
  | Clair | `secondary500` `#C2410C` | `background950` | 4,44 |
  | Clair | `warning` `#B45309` | `background950` | 4,30 |
  | Clair | `card` `#A16207` | `background950` | 4,22 |
  | Clair | `accent400` `#2563EB` | `background950` | 4,43 |
  | Clair | `primary500`, `warning`, `card`, `foreground500` | `background700` `#E2E8F0` | 4,07 ; 4,07 ; 3,99 ; 3,86 |
  | Clair | `secondary400` `#EA580C` | `background900` (blanc) | 3,56 |
  | Sombre | `danger` `#EF4444` | `background800` / `background700` | 4,26 / 4,00 |
  | Sombre | `accent500` `#3B82F6` | `background800` / `background700` | 4,36 / 4,09 |
  | Sombre | blanc | `primary500` `#22C55E` | 2,28 |
  | Sombre | blanc | `danger` | 3,76 |

  Contenu non textuel : la bordure `background700` mesure 1,16:1 contre `background900` et 1,28:1 contre `background950` en sombre (1,23 et 1,06 en clair). C'est la seule délimitation des champs remplis, par exemple `new_player_bottom_sheet.dart:239-244`.
- Impact : textes d'état et liens colorés en limite de lisibilité sur le fond de page clair. Les champs de saisie se distinguent mal de leur conteneur. Ces paires ne sont risquées que si elles servent réellement en petit texte ; le recensement des usages reste à faire.
- Recommandation : foncer légèrement `primary500`, `secondary500`, `warning` et `card` clairs, ou interdire ces tokens en petit texte sur `background950` et `background700`. Utiliser `onPrimaryDark` sur les fonds verts en sombre. Ajouter dans `test/core/theme/contrast_test.dart` une matrice texte/fond par rôle et un contrôle à 3:1 des bordures de champ.
- Effort : S

### A11Y-011 — Noms ambigus ou répétitifs
- Sévérité : Mineur / Domaine : accessibilité, libellés / Statut : confirmé (exécuté)
- Critères : 2.4.6 En-têtes et étiquettes, 2.4.4 Fonction du lien (selon le contexte).
- Preuve :
  - Liste Joueurs : 9 boutons « Supprimer ce joueur » identiques (`players_screen.dart:306`, `tooltip: 'Supprimer ce joueur'`). Seul le groupe parent porte le nom du joueur.
  - Accueil : « Stats 0 0 », « Joueurs 10 », « Séances 0 ». Ce sont des valeurs sans unité.
  - Détail de séance : « Bruno: 1 buts, 0 passes… ». Accord au singulier manquant et deux-points sans espace.
  - En revanche, la composition (« Équipe A pour Alice », « Retirer Alice de la séance ») est exemplaire.
- Impact : dans la liste des boutons d'un lecteur d'écran, on ne sait pas quel joueur sera supprimé, alors que c'est une action destructive.
- Recommandation : `tooltip: 'Supprimer ${player.name}'`, des libellés de cartes de la forme « 10 joueurs », et une fonction d'accord pour « but » et « buts ».
- Effort : XS

### A11Y-012 — Contenu décoratif lu, statistiques sans structure
- Sévérité : Mineur / Domaine : accessibilité, alternatives / Statut : confirmé (exécuté)
- Critères : 1.1.1 Contenu non textuel, 1.3.1 Information et relations.
- Preuve :
  - Onboarding : l'illustration décorative est exposée comme `group "SÉANCE · MATCH #12 A Équipe A 5 - 3 B Équipe B 5 buts ✓ 3 buts"` (`onboarding_screen.dart:165-167`, `_ScoreboardIllustration`, sans `ExcludeSemantics`).
  - Fiche joueur : toute la synthèse forme un seul bloc de texte (« SYNTHÈSE MATCHS (J) 0 V / N / D 0 / 0 / 0 POINTS 0 PTS/MATCH 0.00 … »), où les libellés et les valeurs ne sont pas associés.
  - À l'inverse, `core/widgets/player_avatar.dart:91` exclut l'avatar et la photo de l'arbre (`ExcludeSemantics`), puisque le nom est lu à côté.
- Impact : sur l'onboarding, un faux score est lu comme du contenu. Les statistiques de la fiche joueur forment une suite de nombres difficile à interpréter.
- Recommandation : envelopper les illustrations d'onboarding dans `ExcludeSemantics`. Regrouper chaque statistique avec `MergeSemantics` ou `Semantics(label: 'Buts : 0')`.
- Effort : S

### A11Y-013 — Cibles compactes sous la règle interne de 48 dp
- Sévérité : Mineur / Domaine : accessibilité, ergonomie tactile / Statut : confirmé
- Critère : 2.5.8 Taille de la cible (minimum, 24×24 px), **respecté** sur toutes les cibles mesurées. L'écart concerne la règle des 48 dp de `docs/design-system.md:68`.
- Preuve :
  - Mesures Playwright : « Passer » 71×32, « Retour », « Réglages » et « Supprimer ce joueur » 40×40, « Rejoindre un groupe partagé » 259×32, « Nouvelle séance » 361×40, « Annuler » 110×36.
  - Statique : `VisualDensity.compact` à 10 endroits, dont `settings_screen.dart:184-185` qui combine `visualDensity: VisualDensity.compact` et `tapTargetSize: MaterialTapTargetSize.shrinkWrap`. Également `session_detail_screen.dart:274,865` et `new_session_screen.dart:587,993,1153`.
  - Les filtres de Séances (environ 36 dp) sont déjà relevés en UI-010.
- Impact : aucune non-conformité AA, mais un confort tactile réduit, en particulier au bord du terrain.
- Recommandation : retirer `shrinkWrap` et garder une zone tactile d'au moins 48 dp autour des commandes compactes.
- Effort : XS

### A11Y-014 — Aucun test automatisé des règles d'accessibilité Flutter
- Sévérité : Mineur / Domaine : tests / Statut : confirmé
- Critère : sans objet (prévention des régressions sur 1.4.3, 2.5.8 et 4.1.2).
- Preuve : `grep -rln "meetsGuideline|androidTapTargetGuideline|textContrastGuideline|labeledTapTargetGuideline" mobile/test` ne renvoie rien. `test/accessibility/commands_test.dart` contient des tests ciblés de noms et de texte à 200 % (A11Y01 à A11Y12), utiles mais limités à quelques écrans.
- Impact : les défauts A11Y-003, A11Y-004 et A11Y-013 peuvent revenir sans qu'aucun test échoue.
- Recommandation : ajouter, pour chaque écran principal en thème clair et en thème sombre, `expect(tester, meetsGuideline(labeledTapTargetGuideline))`, `androidTapTargetGuideline` et `textContrastGuideline`.
- Effort : S

## Hypothèses à vérifier

- **`AppCard(onTap:)`** (12 usages) : sur l'accueil, « Joueurs 10 », « Séances 0 », « Stats » et « Finances du groupe » sont focalisables (`tabindex=0`), ce qui laisse penser qu'une partie des cartes passe par un `InkWell` ou un autre nœud. La focalisabilité des cartes construites par `app_card.dart:32` reste à vérifier une par une.
- **`team_tab_pill.dart:27-33`** : `Semantics(button: true, selected:)` autour d'un `GestureDetector`. Le nom est correct, mais la focalisabilité au clavier n'a pas été mesurée.
- **Ordre de lecture de la composition** : pour « Chloe », « Retirer Chloe de la séance » apparaît avant « Équipe A pour Chloe ». Pour les autres joueurs, il apparaît après. Possible artefact de rendu de liste, à confirmer.
- **Lecteurs d'écran natifs** (TalkBack, VoiceOver) : non testés. L'arbre natif peut différer de l'arbre web, par exemple pour les `hintText` qui deviennent des indications Android.
- **Thème clair à l'écran** : non observé. Les ratios de A11Y-010 sont théoriques.
- **Saisie clavier rapide** : une saisie Playwright sans délai a perdu des caractères dans les champs Flutter web. Avec 120 ms entre les touches, tout fonctionne. Je n'en tire pas de constat (artefact probable de l'automatisation).

## Points positifs (Info)

- **Langue** : `mobile/web/index.html:2` et `web/index.html:2` déclarent `lang="fr"` (3.1.1). Le chargement Flutter expose `role="status"`.
- **Texte agrandi** : aucun plafonnement de `textScaler`. Plusieurs écrans s'adaptent :
  - `onboarding_screen.dart:152` remplace l'illustration par une icône ;
  - `adaptive_bottom_navigation.dart:52-59` passe à une navigation défilante ;
  - `new_session_screen.dart:291,455` ;
  - `financial_point_screen.dart:51`.

  Exécuté à 200 % (police racine à 32 px) : l'accueil et la nouvelle séance restent lisibles, et le texte de l'onboarding défile (`SingleChildScrollView`, `:176`). Tests à 200 % existants : `test/accessibility/commands_test.dart:319,358`, `financial_point_screen_test.dart:356`, `group_entry_test.dart:347`, `session_detail_kebab_menu_test.dart:411`, `shared_decisions_test.dart:226` (1.4.4).
- **Redistribution** : à 320×640, `scrollWidth` = `clientWidth` = 320, sans défilement horizontal (1.4.10).
- **Sémantique forcée sur le web** : `mobile/lib/main_web.dart:12` (`ensureSemantics()`).
- **États courants exposés** : la navigation basse (`adaptive_bottom_navigation.dart:75-77`) et le type de séance exposent `aria-current="true"`.
- **Écrans métier bien nommés** : composition (« Équipe A pour Alice », « Marquer Alice présent ») et détail de séance (« Ajouter un but pour Bruno », « Annuler la dernière action [disabled] »). Les dialogues sont exposés en `alertdialog`.
- **Clavier** : Échap ferme la feuille « Nouveau joueur ». Espace active « 6v6 ». L'ordre de tabulation du formulaire de création d'équipe suit l'ordre visuel.
- **Validation** : le champ vide de l'effectif initial passe à `aria-invalid` (3.3.1).
- **Images** : avatars et photos exclus de l'arbre, puisque le nom est adjacent (`player_avatar.dart:91`).
- **Mouvement** : la célébration de fin de séance respecte `disableAnimations` (`session_celebration.dart:43,62`).
- **SnackBar** : les 51 `showSnackBar` utilisent le `SnackBar` Material, annoncé comme zone live par le framework [déduit du comportement standard de Flutter].
- **Portail `web/`**, toujours servi :
  - `field()` pose `aria-label`, `aria-invalid` et `aria-describedby` sur les erreurs (`web/app.mjs:101-133,170`) ;
  - le bouton afficher/masquer a `aria-pressed` (`:196-205`) ;
  - la navigation a `aria-label` et `aria-current="page"` (`:1101-1119`) ;
  - les étapes ont `aria-current="step"` (`:2001`) ;
  - les messages passent par `role="status" aria-live="polite"` (`web/index.html:35`) ;
  - le focus est visible (`styles.css:89-94`, contour de 3 px) et les animations sont conditionnées à `prefers-reduced-motion` (`styles.css:131,902`) ;
  - le logo du splash a `alt=""`.

  Aucun défaut majeur relevé dans cette revue rapide.

## Renvois vers d'autres domaines

- **Performance et réseau (H), sécurité et vie privée** : au démarrage, l'app Flutter web tente de charger des polices de secours depuis `fonts.gstatic.com` (Noto Sans Symbols 2, SC, TC, HK, JP). Ces requêtes ont été bloquées par `page.route`. Elles sont probablement déclenchées par des glyphes absents de Poppins, par exemple « ✓ » dans l'illustration de l'onboarding. L'erreur console « A bad HTTP response code (404) was received when fetching the script » est déjà connue (domaine H).
- **UI (03)** : UI-006 (contrastes), UI-010 (filtres et « Sauvegarder », cibles et sémantique) et UI-005 (messages d'erreur bruts) recoupent A11Y-002, A11Y-010 et A11Y-013. Les recommandations doivent être traitées ensemble.
- **Shell PWA** : `mobile/web/app-shell.js:10-11` ajoute un `<details><summary>Application</summary>` en haut de chaque écran. Il est focalisable et bien nommé, mais il s'intercale dans l'ordre de tabulation entre la fin de l'app et son début. À arbitrer côté produit et web.
- **Sauvegarde et restauration (données)** : le choix Fusionner / Remplacer (`settings_screen.dart:568,640`) n'est ni focalisable ni annoncé (A11Y-002, A11Y-007). Il porte sur une opération destructive.

## Vérification croisée (Phase 4, 14/11/2026)

A11Y-001 à A11Y-004 relus par la session principale et **confirmés** : aucun style de focus dans `mobile/lib/core/theme/app_theme.dart` (grep `focus` vide) ; `GestureDetector` pour « Suivant » (`onboarding_screen.dart:242-256`) ; `FloatingActionButton` sans `tooltip` (`players_screen.dart:186`) ; A11Y-004 établi par l'arbre d'accessibilité à l'exécution.
