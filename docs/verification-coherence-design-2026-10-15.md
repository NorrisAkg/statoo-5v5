# Vérification de cohérence et de cadrage — 15 octobre 2026

## Résultat et périmètre

La mémoire [design-system.md](design-system.md) est désormais obligatoire via `AGENTS.md`, `CLAUDE.md`, `GEMINI.md` et `conventions.md`. La référence contradictoire à Inter a été corrigée dans GEMINI. Cela ne signifie pas que tous les écrans existants satisfont déjà chaque règle.

Le périmètre approfondi couvre les pages et dialogues réalisés/modifiés dans cette conversation : Point financier, détail de séance, accueil/résultat, groupe partagé/arbitrage, remplacement de sauvegarde ; leur contexte proche inclut Finances, Nouvelle séance, création de groupe et Réglages. Pour éviter de confondre « nos écrans » et l’application entière, le repérage statique est élargi aux **16 écrans principaux Flutter** et aux cinq fichiers de feuilles modales. Il n’attribue pas leur création entière à cette conversation.

**Conclusion : cohérence rétablie sur les zones récemment refondues et effectivement observées ; cadrage intégral de l’ensemble non certifié.** Le rendu normal, le clavier réel et le grand texte ont été examinés sur le Point financier ; la composition à 200 % et le dialogue d’arbitrage ont leurs preuves propres. D’autres pages ne bénéficient pas encore de cette couverture. Aucun code applicatif supplémentaire n’a été modifié dans cette vérification documentaire.

## Niveaux de preuve

**Mise à jour après déblocage :** voir [reprise de cadrage et captures finales](tdd-cadrage-transversal.md). VC01, VC02, VC03 et VC03b ont été reproduits puis corrigés en TDD. Le tableau à 200 % a reçu un complément CAD07 après lecture réelle : soldes empilés. **50 tests ciblés et 415 tests complets passent**. Finances, réglages financiers et feuille joueur sont observés sur téléphone à 200 % (captures 132–134/136), réglages initiaux rétablis. Les sections de constats ci-dessous décrivent les observations initiales, pas des bugs encore présents dans le code corrigé. Onboarding reste vérifié automatiquement ; VC04/VC05 restent ouverts.

- **Écran** : capture inspectée du rendu de l’application ; preuve limitée à l’état, au thème et à l’appareil représentés.
- **Automatisé** : dernier run Flutter de **415 tests réussis** (`tdd-cadrage-regressions-finales.log`), après correction en TDD. Le run précédent à 367 concernait la refonte du Point financier avant la reprise CAD.
- **Code** : structure et styles examinés ; aucune conclusion visuelle générale tirée de cette seule lecture.
- **À tester** : ni réussite ni bug confirmé. Une structure à risque ne constitue pas une preuve de débordement.

Les captures de référence historiques `statoo-captures/` expliquent le style ; elles ne prouvent pas le rendu de la version actuelle. Aucune capture hors application ou avec police de test n’est utilisée comme validation.

## Matrice des 16 écrans principaux

| Écran / source sous mobile/lib/features | Cohérence examinée | Preuve de cadrage disponible | Ce qui reste |
|---|---|---|---|
| Accueil — home/presentation/home_screen.dart, home_session_result.dart | AppCard, PrimaryButton, palette, résultats 2/3 équipes et noms | Écran : 102/122, sombre, séance active ; automatisé ACC et tournoi restauré | Accueil complet 320 dp/200 %, noms longs, dernier tournoi clôturé sur téléphone ; tests ACC utilisent 800 × 1600. |
| Point financier — finance/presentation/financial_point_screen.dart | Cartes de contexte/membre, champs remplis, labels, montants français, pied adaptatif | Écran : 110–113, 117, 120/121 ; 27 tests ciblés, 12 variantes de largeur/texte/thème | Thème clair physique, TalkBack, rôles supplémentaires et dialogues à grand texte. Voir suivi dédié. |
| Finances — finance/presentation/finances_screen.dart | AppCard, recherche, sections et détail membre | Tests existants : 360 × 800, clair/sombre, recherche et feuille de détail | 320 dp/200 %, montants extrêmes et feuilles d’échéances ; risque VC01. |
| Groupe partagé — shared/presentation/shared_group_screen.dart | AppCard, champs remplis de page, actions principales, rôles ; dialogues secondaires distincts | Écran : connexion/gestion historique, 105–108 pour arbitrage ; formulaires à 360 × 800 clair/sombre ; arbitrage à 320 dp/200 % simulés | Tous les dialogues compte/rôles/départ/transfert, clavier réel à 200 %, grandes listes. |
| Liste des séances — sessions/presentation/sessions_screen.dart | AppBar, filtres pilules, cartes de séance | Écran : 16 et parcours 90–94 ; tests de liste et navigation | Longs noms de groupe, filtres et trois équipes à 320 dp/200 %. |
| Nouvelle séance — sessions/presentation/new_session_screen.dart | Sections AppCard, étapes, PrimaryButton, couleurs d’équipes | Écran : 82/83/85/86/91–93 ; tests fonctionnels de création/rôles | Les tests de création utilisent souvent 800 × 1400 ou plus : pas une preuve mobile étroite à texte agrandi. |
| Détail séance — sessions/presentation/session_detail_screen.dart, session_header.dart | Composition en Wrap, en-têtes flexibles, cartes, actions, variantes tournoi | Écran : 104 à 200 % ; 36 variantes 320/393 dp × 100/130/200 % × clair/sombre × trois états | Dialogues statistiques/clôture et tous les blocs tournoi à 200 % ; couleur hors thème VC05. |
| Réglages — settings/presentation/settings_screen.dart | AppBar, AppCard, sections, champs de réglage et confirmation de restauration | Écran historique : 35/42/43/45 ; tests métier de sauvegarde | Paramètres financiers à gros montants/200 % ; VC02. Les captures 36/37 ne sont pas retenues ici comme succès. |
| Création de groupe — team/presentation/create_team_screen.dart | Variante d’accueil explicite : fond du thème, AppBar transparent, badge centré, page défilante | Code ; récapitulatif d’import à vide vu (capture 12), tests de restauration | Création complète 320 dp/200 %, clavier, erreurs et nom long ; dialogue destructif VC04. |
| Joueurs initiaux — team/presentation/add_team_players_screen.dart | Même variante d’accueil, avatars et champs ; SafeArea | Code ; aucune nouvelle preuve visuelle du formulaire | Clavier, bouton final, message de succès long, 320 dp/200 %. |
| Liste joueurs — players/presentation/players_screen.dart | AppBar, recherche et cartes locales cohérentes avec la liste de référence | Écran : 77, rôle PDT ; tests de recherche/permissions | Sous-titre AppBar à hauteur fixe, groupe long, textes agrandis ; ne pas conclure à un overflow sans exécution. |
| Détail joueur — players/presentation/player_detail_screen.dart | Cartes/résultats, palette principale ; historique sportif | Code ; capture historique de référence uniquement | Statistiques et historique dense à 320 dp/200 %, score et badges longs. |
| Classement — ranking/presentation/standings_screen.dart | AppBar, sélecteur segmenté, onglets défilants, avatars | Tests existants de classement/MVP ; preuves historiques de classement importé décrites dans le rapport appareil | Sélecteur principal et tableaux à 320 dp/200 %, noms longs, lecture seule. |
| Statistiques — stats/presentation/stats_screen.dart | AppBar, KPI en AppCard, palette et hiérarchie | Code et tests de calcul ; aucun rendu courant ajouté dans ce lot | KPI à grand texte, valeurs extrêmes, thème clair et filtres. |
| Onboarding — onboarding/presentation/onboarding_screen.dart | Variante illustrée intentionnelle, palette et Poppins héritée | Deux tests de parcours en sombre ; aucune preuve de petit écran/texte agrandi | Zones texte à hauteur proportionnelle : VC03. |
| Splash — onboarding/presentation/splash_screen.dart | Marque, palette, SafeArea, illustration existante | Code ; test de démarrage ne vaut pas recette visuelle | Petit écran/200 %, animation réduite et chargement d’asset. |

## Feuilles et états secondaires

| Surface | Lecture / preuve | Validation restante |
|---|---|---|
| Changement de groupe — team_switcher_bottom_sheet.dart | Coins supérieurs 24, fond du thème, SafeArea, titres flexibles ; capture 80 | Beaucoup de groupes, nom long, 200 %, dernière action atteignable. |
| Nouveau joueur — new_player_bottom_sheet.dart | Palette et PrimaryButton ; champs remplis compacts à rayon 12 (variante existante) | En-têtes, clavier, erreurs, 320 dp/200 %. |
| Modifier joueur — edit_player_bottom_sheet.dart | SafeArea, contenu défilant, insets de clavier et PrimaryButton | Titre non flexible face à fermeture : essai VC03b. |
| Retardataires — add_late_players_bottom_sheet.dart | Recherche, liste, validation partagée ; capture 88 | Liste vide/recherche négative et grand texte avec clavier ; long libellé de validation. |
| Règles MVP — mvp_rules_bottom_sheet.dart | Palette/SafeArea, texte explicatif | Lecture complète 320 dp/200 % et contrôle du défilement. |
| Confirmation de remplacement — confirm_replacement.dart | Contenu défilant, groupes/périmètre explicités, annulation | Bouton destructif héritant du primaire : VC04 ; grande liste de groupes. |
| Arbitrage — decision_details.dart + dialogue partagé | Différences en premier, détails repliables, motif et erreur visibles ; captures 105–108 | TalkBack parlé, clavier réel, nombreuses versions ; le test sémantique ne certifie pas l’annonce vocale. |
| Départ financier, rôles, comptes, échéances et paramètres | Dialogues inventoriés dans les fichiers SharedGroupScreen, FinancesScreen et FinancialDefaultsSection | Chaque dialogue doit passer V06 ; le succès d’un dialogue ne valide pas les autres. |

## Constats à traiter ou confirmer

### VC01 — espace horizontal des finances à texte agrandi

**Probable, confiance moyenne, impact potentiellement modéré.** `finances_screen.dart:655` : l’icône et « Caisse du groupe » sont deux enfants non flexibles de Row dans une AppCard. `:575` : tableau nom + trois cellules. Aucun défaut à 360 dp/100 % n’est déduit : cette variante passe les tests. À reproduire à 320 dp, texte 200 %, nom long et valeurs à 12 chiffres. Attendu : titre et données accessibles sans dépassement. Si RED, adapter avec Wrap/Flexible ou détail empilé, sans réduire le texte ; valider les valeurs et le tap sur le membre.

### VC02 — réglages financiers, montant trailing sans contrainte souple

**Probable, confiance moyenne, impact potentiellement modéré.** `financial_defaults_section.dart:150` : Row trailing contenant un montant non flexible et un chevron, avec titre/sous-titre de ListTile. À tester à 320 dp/200 % avec 1 000 000 000 000 F. Attendu : montant complet, titre et action accessibles. Recommandation si confirmé : mettre le montant sous le libellé ou dans un Wrap contraint ; conserver l’unité et le rôle de l’action.

### VC03 / VC03b — hauteur d’onboarding et titre de feuille joueur

**À vérifier, confiance moyenne, impact potentiellement modéré.** `onboarding_screen.dart:169` : texte dans Expanded flex 40 sans défilement interne ; barre supérieure hauteur 52 (`:79`). `edit_player_bottom_sheet.dart:135` : titre de formulaire non flexible face au bouton de fermeture. Reproduire les trois slides et la feuille à 320 × 640, texte 200 %, puis avec clavier pour la feuille. Attendu : titres complets ou consultables, commandes atteignables. Pas de bug de cadrage annoncé sans reproduction. Correction éventuelle : texte défilant / titre flexible, tests avant code.

### VC04 — confirmation de destruction avec apparence primaire ordinaire

**Confirmé dans le code, rendu actuel à vérifier ; incohérence visuelle, priorité modérée.** `confirm_replacement.dart:45` : FilledButton sans style spécifique pour « Remplacer toutes les données ». Le thème lui donne l’apparence primaire de validation, contrairement aux suppressions rouges existantes. Ce n’est pas une preuve d’effacement involontaire : l’explication, le périmètre et l’annulation sont présents. Contrôler clair/sombre puis, dans un lot TDD, aligner l’action sur la convention destructive existante en préservant les contrastes et les protections de sauvegarde.

### VC05 — couleur de trophée échappant au thème

**Confirmé dans le code, impact visuel mineur.** `session_detail_screen.dart:414` : `Color(0xFFFACC15)` en dur pour le trophée du leader, alors que `context.colors.gold` existe avec une variante claire. Il ne s’agit pas d’un échec d’accessibilité établi (icône potentiellement décorative). Vérifier le tournoi clair/sombre ; remplacer par le jeton sémantique si le rôle visuel correspond, avec scénario de non-régression avant code.

Les rayons 12 des feuilles compactes, 20 des cartes et 24 des coins de feuille sont des variantes existantes documentées, pas trois bugs. Les pages d’accueil illustrées et les pages de gestion ont également des compositions intentionnellement différentes. Aucun jugement esthétique subjectif n’est présenté comme défaut fonctionnel.

## Scénarios de vérification à exécuter avant toute correction suivante

| ID | Couverture et attendu |
|---|---|
| V01 | Chaque écran : chargement, erreur, vide et contenu nominal ; hiérarchie, palette et navigation cohérentes. |
| V02 | 320/393 dp × 100/130/200 % × clair/sombre : aucun contenu essentiel tronqué, commandes atteignables, défilement réel. |
| V03 | Noms de groupe/membre longs, trois équipes, montants extrêmes : données complètes ou détail accessible, pas de collision avec les actions. |
| V04 | Clavier réel et simulé : champ actif visible, focus et saisie conservés, pas de validation masquée sans moyen de l’atteindre. |
| V05 | Pieds fixes : leur hauteur laisse le contenu utilisable ; résumés secondaires défilent au besoin. |
| V06 | Chaque dialogue/feuille, pas seulement la page hôte : grand texte + clavier, erreurs, validation/annulation, fermeture sans mutation implicite. |
| V07 | Rôles consultation/édition, séance active/en attente/clôturée/tournoi : même vocabulaire visuel et bonnes actions. |
| V08 | Palette et contraste mesurés, TalkBack/focus et cibles : rapporter les mesures, ne pas certifier par lecture du thème. |

Ordre conseillé : VC01/VC02, VC03/VC03b, puis toutes les surfaces de saisie partagées ; VC04/VC05 dans un lot de cohérence distinct. Conserver les échecs RED avant correction. Les quatre réserves et les huit majeurs gardent leurs suivis propres, qui ne sont pas remplacés par cette matrice de design.

## Limites de cette vérification

L’examen automatique avait échoué faute de quota au premier passage, sans jugement de dangerosité. Après autorisation de reprise et rétablissement du service, les tests et les contrôles physiques ont repris. Finances, réglages financiers et feuille joueur ont été observés en sombre à 200 % sur le nouvel APK QA ; veille et texte rétablis. La mémoire est enregistrée. La recette exhaustive des 16 écrans, de tous les rôles/états et TalkBack reste distincte des surfaces testées en CAD ; onboarding reste à revoir physiquement. Aucun succès global n’est déduit du total de tests.
