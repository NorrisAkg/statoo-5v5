# Mémoire du design Statoo

Référence persistante du projet, établie le 15 octobre 2026 à la demande de l’utilisateur. À lire avant chaque écran ou refonte, puis à confronter au code actuel. Elle décrit le design Flutter de Statoo ; elle ne transforme pas les variantes de la PWA en référence mobile.

## Sources et méthode

1. Choix explicites de l’utilisateur et évolutions acceptées dans le projet.
2. Écrans de référence de `statoo-captures/`, à confronter au thème actuel : certaines captures anciennes précèdent Poppins et le thème clair.
3. `mobile/lib/core/theme/app_theme.dart`, `app_colors.dart` et `core/widgets/` pour l’implémentation effective.
4. Écrans voisins du même parcours. Examiner au moins deux références avant de coder.

Le CDC conserve la priorité sur les règles métier. Documenter les divergences visuelles ; ne pas reproduire un défaut connu d’une ancienne capture pour respecter son apparence.

Références principales : détail de séance (`08-seance-detail-s9.jpg`), accueil (`01-accueil.jpg`), joueurs et formulaires (`01-liste-joueurs.png`, `10-formulaire-nouveau-joueur.png`). Pour la finance, comparer `finances_screen.dart` et `financial_point_screen.dart` ; pour les écrans de gestion, comparer Réglages et Groupe partagé.

## Couleurs et surfaces

Utiliser `context.colors` et les couleurs sémantiques du thème, sans nouvelle palette locale. Les valeurs ci-dessous permettent de reconnaître le système ; les lire dans le thème plutôt que les recopier dans un écran.

| Rôle | Sombre | Clair | Usage |
|---|---|---|---|
| Fond de page `background950` | `#0B0F14` | `#E9EEF3` | Scaffold |
| Carte `background900` | `#141A22` | `#FFFFFF` | Blocs de contenu |
| Surface de champ `background800` | `#1A222C` | `#F1F5F9` | Champs/contrôles |
| Bordure `background700` | `#1F2733` | `#E2E8F0` | Cartes, séparateurs |
| Texte principal `foreground50` | `#F8FAFC` | `#0F172A` | Titres, données |
| Texte secondaire `foreground400` | `#94A3B8` | `#475569` | Aides, dates |
| Action principale `primary500` | `#22C55E` | `#15803D` | Validation, sélection |
| En-tête `header` | Fond de page sombre | Vert de marque | AppBar standard |

Respecter `onHeader` et `colorScheme.onPrimary` pour le texte sur une surface colorée. Danger, avertissement, classement et équipes ont leurs couleurs sémantiques. Les palettes existantes d’avatar et les couleurs d’équipe personnalisées sont des exceptions métier explicites ; ne pas les remplacer par le vert de marque. Une valeur numérique, un état ou une erreur doit également être exprimé en texte.

## Typographie et contenu

- **Poppins embarquée**, héritée du thème. Inter est une ancienne consigne obsolète.
- AppBar standard : 20, graisse 600 ; titres de section : 16–22 selon niveau ; corps : 14–16 ; aides : 12–13. Utiliser les styles du thème quand ils correspondent au rôle. Les scores et indicateurs majeurs peuvent être plus grands.
- Éviter de multiplier les tailles locales et les micro-libellés à 10/11 pour une commande indispensable. Une variation typographique doit exprimer une hiérarchie réelle.
- Interface française, dates via `intl`/`fr_FR` (par exemple `jeu. 15 oct. 2026 · 08h23`), montants groupés en français avec l’unité `F`. Préciser reçu/dû/payé pour ne pas confondre comptabilité et trésorerie.
- Icônes **Remix**, avec tooltip/libellé pour les commandes isolées. Ne pas introduire de Material Icons comme autre vocabulaire visuel dans un nouveau contrôle personnalisé. Les contrôles natifs existants ne sont pas à réécrire pour leur seule icône intégrée.

## Composition et composants

| Élément | Convention de référence |
|---|---|
| Page de gestion | AppBar standard, titre aligné à gauche, retour attendu ; fond du thème. |
| Carte | Réutiliser `AppCard` : rayon 20, bordure 1, padding 20 par défaut. Variantes compactes explicites, par exemple padding 14/16. |
| Espacements | Marges de page souvent 16 ; 24 pour les parcours d’accueil/création ; pas courants 4/8/12/16/20/24. Les utiliser selon le niveau, sans imposer une grille rigide aux données. |
| Action principale | `PrimaryButton` : pilule, padding vertical 16, libellé 16 gras, icône optionnelle, largeur complète quand l’action concerne la page. |
| Action secondaire | TextButton/OutlinedButton du thème, texte explicite, couleur cohérente. |
| Destruction | Action distincte, libellé explicite et confirmation proportionnée ; contrôler sa couleur par rapport aux suppressions existantes, ne pas la présenter comme un succès ordinaire. |
| Champ de page | Surface remplie `background800`, bordure `background700`, rayon 16, focus primaire ; label permanent pour les données métier. Un placeholder n’est pas une valeur enregistrée. |
| Liste de membres | Avatar existant, nom lisible, données et actions regroupées. Distinguer les cartes de saisie des tableaux de consultation denses. |
| Dialogues | AlertDialog du thème ; `showAppFormDialog` pour les contrôleurs de formulaire ; contenu défilant si nécessaire, actions atteignables au clavier et à grand texte. |
| Feuille modale | Surface et coins cohérents avec les feuilles existantes, SafeArea, hauteur adaptée et inset de clavier ; poignée/fermeture selon le parcours. |

Les assistants d’accueil/création ont une variante intentionnelle : en-tête transparent, titre ou badge d’étape centré, `AppTheme.pageOverlayStyle`. Ne pas imposer cette variante aux pages de gestion, ni les déclarer incohérentes uniquement parce qu’elles ne possèdent pas l’AppBar standard.

Les dialogues métier existants ont encore des champs OutlineInputBorder natifs ; leur présence ne valide pas automatiquement leur cohérence avec les formulaires de page. Unifier dans un lot TDD explicite lorsque leur refonte est décidée, pas par remplacement aveugle de tous les composants Material.

## Cadrage et adaptation

- Produit mobile en portrait. Tester 320 et 393 dp, texte 100/130/200 %, clair/sombre. Ne pas conclure à une adaptation tablette/paysage sans vérification correspondante.
- Pas de nouveau plafonnement du texte pour masquer un débordement. Adapter la composition avec `Wrap`, `Expanded`/`Flexible`, champs empilés ou listes défilantes.
- Un nom long ne doit pas chasser une action essentielle. Le texte complet doit rester consultable si un résumé est tronqué.
- Les onglets à grand texte doivent garder leur libellé lisible et rester accessibles (barre défilante si nécessaire).
- Un pied fixe ne doit pas absorber le formulaire. À grand texte, placer les informations secondaires dans le contenu défilant. Le Point financier conserve seulement sa validation fixe et remonte les totaux dans la carte de contexte.
- Le clavier doit laisser le champ actif et les actions nécessaires atteignables. Respecter SafeArea, inset et retour système. La fermeture du clavier ne doit pas abandonner la saisie.
- Prévoir cibles d’au moins 48 dp pour les commandes tactiles Android usuelles, labels sémantiques, focus et texte d’erreur visible. Les mesures réelles et TalkBack restent à vérifier ; ce document n’est pas une certification WCAG.

## États, permissions et recette obligatoire

Avant le code, écrire les scénarios et résultats attendus : chargement, vide, recherche sans résultat, erreur récupérable, succès, attente, désactivation, lecture seule, données longues, fermeture et reprise de saisie. Les rôles changent les commandes sans supprimer l’information utile. Un message d’erreur doit préciser l’action possible et ne pas dépendre du rouge.

Pour chaque livraison UI, conserver : références comparées ; preuve RED pertinente ; résultats GREEN ; captures du rendu quand disponibles ; liste des rôles/appareils/états réellement vus ; zones non couvertes. Distinguer systématiquement **écran observé**, **test automatisé**, **déduction du code** et **à vérifier**. Un test sans exception RenderFlex ne prouve ni l’absence de troncature, ni la bonne hiérarchie, ni la compatibilité lecteur d’écran.

Les captures hors de l’application, les données privées, les arbres UI périmés et les aperçus avec polices de test ne sont pas des preuves visuelles livrables. Utiliser les données fictives de Statoo QA sans modifier l’application réelle.

## Évolutions enregistrées

- 17 octobre 2026, entrée et rôles : sans groupe, proposer Créer un groupe et Rejoindre un groupe dès le démarrage ; créer mène à la présentation, au groupe/effectif, à l’accès Admin, puis à Désigner les responsables. Attribution facultative à cette étape, réservée à l’Admin et retrouvable dans Comptes et rôles. Rejoindre mène directement à la connexion. Conserver les préparations locales en cas de réseau absent. Bouton vers l’accès Admin extensible et indicateurs d’effectif avec retour à la ligne à grand texte. Preuves et limites : `tdd-group-entry-2026-10-17.md`.

- 17 octobre 2026, intégration du prototype validé : saisie Flutter du détail actif par événement (but puis passe facultative, cartons), journal local durable, correction de but et annulation atomiques. Tournoi par compteurs de victoires indépendants. Onglet actif : icône Remix check_line + « Actif », contour/couleur d'équipe. Boutons de saisie et choix en dialogue à 48 dp minimum. Résumé existant conservé avec écussons/dégradé, buteurs sans titre ni texte vide et ballon xN. Contrôles de rôle et clôture conservés. Preuves et limites : `tdd-live-integration.md`.

- 17 octobre 2026, précision prototype : aucun texte de remplacement pour les équipes sans but ; cadre des buteurs masqué si toute la séance est sans but. Résumé du match avec dégradé des couleurs A/B à 18 % autour de la surface centrale, suivant SessionHeader, en clair et sombre.

- 17 octobre 2026, retours prototype : identités du match avec écussons aux couleurs d'équipe ; suppression du titre visible des buteurs et des noms d'équipe répétés dans les deux colonnes. Ballon puis xN seulement si N > 1. Onglet actif repéré par « ✓ Actif », fond teinté et contour renforcé. Les trois camps empilés du tournoi gardent leurs noms pour être identifiables. Aucun changement des écrans de production.

- 17 octobre 2026, prototype de saisie : résumé du match avec score central et bloc séparé de buteurs, tournoi avec victoires et buteurs par équipe. Passe rattachée au but, titre « But de … », retour au buteur et annulation explicites. Correction depuis le journal sans doubler le but. Prototype uniquement ; preuves dans `prototype-saisie-live.md`.

- 16 octobre 2026, exploration de saisie en direct : prototype isolé à données fictives, sans API. Tournoi suivi par victoires cumulées et statistiques par équipe, sans rencontres individuelles. Conservation locale et annulation d'une action complète ; confirmation seulement à la clôture. Sur mobile, compteurs de victoires en lignes et annulation proche des commandes. Proposition à valider avec l'utilisateur, sans modification des écrans de production. Scénarios, références et limites : `prototype-saisie-live.md`.

- 16 octobre 2026, demande de parité complète : l'aperçu web Flutter réutilise les écrans mobiles pour le mode local et le mode partagé, y compris Date & Options → Composition → Débuter la séance → match actif. Les différences de plateforme concernent le stockage et les fichiers, sans sauter de transition métier. Le portail historique et ses améliorations restent disponibles pendant la transition ; le build commun ne prétend pas migrer ses préparations automatiquement. Recette et captures : `parite-web-mobile.md`.

- 16 octobre 2026, accueil web : splash bref au logo, puis trois étapes reprenant l'ordre et les textes du mobile (matchs, tirage, classement), avec SVG décoratifs intégrés. Onboarding terminé mémorisé sur l'appareil ; sessions et préparations existantes accèdent directement à leur parcours. Pas de nouvelle palette ni police. Navigation supérieure sticky ; champs avec label et exemple ; mots de passe avec œil accessible. Nom court facultatif (30 caractères), prioritaire dans le titre du groupe ; nom complet conservé en complément. À grand texte, boutons d'onboarding empilés pour éviter de couper leurs mots. Vérifications et limites : `tdd-web-accueil-2026-10-16.md`.

- 15 octobre 2026, contrôle réel CAD07 : Finances conserve la table à texte normal ; à grand texte, nom/statut et soldes Payé/Attendu/Écart sont empilés, montants complets en F. Un tableau sans RenderFlex overflow pouvait pourtant casser les mots : vérifier aussi le rendu.

- 15 octobre 2026, reprise CAD : montant de réglage sous son libellé plutôt qu’un trailing trop large ; titres flexibles ; explications d’onboarding défilantes et illustration décorative simplifiée à grand texte, sans réduire la taille du texte. Preuves dans `tdd-cadrage-transversal.md`.

- 15 octobre 2026 : Point financier aligné sur AppCard/PrimaryButton, champs nommés et cartes de membres ; totaux défilants et onglets défilants à grand texte après défaut constaté sur téléphone.
- 15 octobre 2026 : composition de séance avec retour à la ligne de l’ajout et en-têtes d’équipes flexibles ; arbitrage avec différences prioritaires, détails inchangés repliables et erreur de motif visible.
- Pour leurs preuves et limites : `tdd-point-financier-design.md`, `tdd-reserves-ui-ux.md`. Pour le contrôle transversal : `verification-coherence-design-2026-10-15.md`.

## Arbitrages du 17 octobre — réflexions restantes

- Point financier : préparer les cotisations au tarif uniquement avant la première validation et avec permission de saisie. Consigne visible pour effacer les impayés. Le préremplissage ne vaut pas encaissement ; le formulaire demande confirmation avant abandon.
- Accueil : visibilité du joueur du mois personnelle sur cet appareil, activée par défaut. Retirer le bloc avec son espacement supérieur, conserver les calculs et classements.
- Clôture : dialogue défilant de félicitations seulement après succès. Nom réel du vainqueur, égalités adaptées ; confettis finis en 1,8 seconde, absents si réduction des animations. Bouton Continuer explicite.
- Vérification : voir tdd-reflexions-2026-10-17.md ; tests de cadrage ne valent pas recette visuelle sur appareil physique.

- 17 octobre 2026 : aucun réglage technique de serveur dans le parcours Groupe partagé (connexion et partage). Adresse fournie par configuration de build. Preuves : tdd-hidden-server-2026-10-17.md.
