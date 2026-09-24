# Mission : initialiser l'application mobile Flutter « Statoo »

Tu es un développeur Flutter senior. Tu vas initialiser et construire une première version de **Statoo**, une application mobile de suivi de matchs de foot à 5 (et variantes 4v4, 6v6) entre amis : séances, scores, compositions d'équipes, statistiques individuelles et classement.

## 1. Documents fournis

Deux sources t'accompagnent :

1. **Le cahier des charges (CDC)** : source de vérité pour le **fonctionnel** (règles métier, calcul des points, entités, parcours, contraintes techniques éventuelles).
2. **Les captures d'écran** (`statoo-captures/*.jpg`, prises au format mobile 375 px de large, en @2x) : source de vérité pour le **design** (mise en page, couleurs, typographie, espacements, composants, libellés visibles).

| Fichier | Route | Statut dans la maquette |
|---|---|---|
| `01-accueil.jpg` | `/` | Écran complet |
| `04-seances-nouvelle.jpg` | `/seances/nouvelle` | Complet (étape 1 sur 3 seulement) |
| `08-seance-detail-s9.jpg` | `/seances/:id` | Écran complet |
| `09-joueur-detail-p1.jpg` | `/joueurs/:id` | Écran complet |
| `02-joueurs.jpg` | `/joueurs` | Placeholder « Bientôt disponible » |
| `03-seances.jpg` | `/seances` | Placeholder |
| `05-classement.jpg` | `/classement` | Placeholder |
| `06-stats.jpg` | `/stats` | Placeholder |
| `07-reglages.jpg` | `/reglages` | Placeholder |

## 2. Règles de priorité (à respecter strictement)

1. **Design : les captures priment sur le CDC.** Si le CDC décrit une couleur, une police, une disposition, un libellé ou un composant différent de ce que montrent les captures, **suis les captures**. Signale chaque divergence dans ton rapport (section 9), sans la trancher autrement.
2. **Fonctionnel : le CDC prime.** Règles métier, données, validations, calculs et parcours viennent du CDC. Les captures ne font qu'illustrer.
3. **Écrans en placeholder** : ce sont des écrans pas encore maquettés, pas une fonctionnalité à reproduire. Si le CDC les décrit, **implémente-les** en extrapolant le langage visuel des écrans complets (mêmes tokens, mêmes cartes, mêmes listes, mêmes badges). Si le CDC ne dit rien d'un écran, garde un placeholder identique à la capture.
4. **Étapes 2 et 3 de « Nouvelle séance »** : non capturées. Déduis leur contenu du CDC (probablement composition des équipes, puis score et stats) et garde le même stepper et le même style que l'étape 1.
5. En cas d'ambiguïté bloquante entre les deux sources, **ne devine pas** : liste la question dans ton rapport et choisis l'option la plus simple, réversible et marquée d'un `// TODO(cdc):`.

## 3. Stack et architecture

Sauf contrainte contraire explicite dans le CDC :

- **Flutter stable (dernière version), Dart 3**, null-safety, `very_good_analysis` ou `flutter_lints` strict.
- **State management** : `flutter_riverpod` (avec `riverpod_annotation` + `riverpod_generator`).
- **Routing** : `go_router` avec `StatefulShellRoute.indexedStack` pour la barre d'onglets (chaque onglet garde sa pile et son scroll).
- **Modèles** : `freezed` + `json_serializable`.
- **Police** : Inter (via `google_fonts` ou embarquée dans `assets/fonts`, préfère l'embarquée pour le hors-ligne).
- **Icônes** : la maquette utilise **Remix Icon** (style « line », version pleine pour l'onglet actif). Utilise le package `remixicon` (ou `flutter_remix`) pour rester fidèle. Ne remplace pas par Material Icons.
- **Dates** : `intl`, locale `fr_FR` (`9 sept.`, `mer. 9 sept. 2026 · 20h30`, `jeu. 24 sept. 2026 · 17h38`).
- **Persistance** : ce que le CDC impose. S'il ne dit rien, définis des interfaces de repository dans le domaine avec une implémentation **in-memory** alimentée par des données de démo (section 7), de façon à brancher plus tard Drift/SQLite ou une API sans toucher à la présentation.

Architecture **feature-first, inspirée Clean Architecture** :

```
lib/
  main.dart
  app/                 # MaterialApp.router, bootstrap, ProviderScope
  core/
    theme/             # AppColors, AppTypography, AppRadii, AppSpacing, AppTheme (ThemeData + ThemeExtension)
    router/            # go_router, routes typées
    widgets/           # composants partagés (AppCard, StatusBadge, TeamDot, Avatar, Pill, PrimaryButton, SectionHeader, ComingSoon, AppBottomNav...)
    utils/             # formatage dates, extensions
  features/
    home/
    sessions/          # séances : liste, création (wizard), détail
    players/           # joueurs : liste, fiche
    ranking/
    stats/
    settings/
      <feature>/domain/        # entités, value objects, interfaces de repository, règles métier pures
      <feature>/data/          # implémentations (in-memory d'abord), DTO, mappers
      <feature>/application/   # providers / use cases
      <feature>/presentation/  # pages et widgets
test/
```

Règles : le domaine ne dépend ni de Flutter ni de Riverpod ; aucune couleur ou taille « en dur » dans les widgets (tout passe par le thème) ; les calculs (points, % victoires, pts/match, classement, départage) sont des fonctions pures du domaine, testées unitairement.

## 4. Design system (extrait de la maquette, valeurs exactes)

Application **en thème sombre uniquement** (pas de thème clair dans cette version).

### Couleurs

| Token | Hex | Usage observé |
|---|---|---|
| `background950` | `#0B0F14` | Fond de l'app, texte sur bouton vert |
| `background900` | `#141A22` | Cartes, barre d'onglets (à 95 % d'opacité) |
| `background800` | `#1A222C` | Surfaces secondaires, champs de saisie |
| `background700` | `#1F2733` | Bordures, séparateurs |
| `foreground50` | `#F8FAFC` | Texte principal, titres, scores |
| `foreground100` | `#EEF2F7` | |
| `foreground200` | `#E2E8F0` | |
| `foreground300` | `#CBD5E1` | Icônes d'en-tête |
| `foreground400` | `#94A3B8` | Texte secondaire (date, « 10 joueurs ») |
| `foreground500` | `#64748B` | Texte tertiaire (« J 14 », surnoms, onglets inactifs) |
| `foreground600` | `#475569` | Très discret |
| `primary500` | `#22C55E` | Vert principal : CTA, badge « Clôturée », onglet actif, « Victoire » |
| `primary400` | `#4ADE80` | Liens (« Voir tout »), valeurs mises en avant |
| `primary300` | `#86EFAC` | |
| `secondary500` | `#F97316` | **Équipe B** (pastille orange) |
| `secondary400` | `#FB923C` | Texte lié à l'équipe B |
| `accent500` | `#3B82F6` | **Équipe A** (pastille bleue) |
| `accent400` | `#60A5FA` | Texte lié à l'équipe A, passes décisives |
| `accent300` | `#93C5FD` | |
| `card` | `#FACC15` | **Carton jaune** (et médaille n° 1 du classement) |
| `danger` | `#EF4444` | Carton rouge, « Défaite », « Supprimer » |
| `warning` | `#F59E0B` | Avertissements |

Les fonds « teintés » (avatars, badges, icônes de tuiles) sont la couleur à **15 % d'opacité** avec le texte dans la même couleur pleine (ex. avatar « L » : fond `danger` 15 %, lettre `danger`). Le fond d'élément actif en navigation latérale est `primary500` à 10 %.

### Typographie (Inter)

- Titre d'écran (app bar) : 22 px, gras.
- Titre de section (« Classement », « Synthèse ») : 16 px, semi-gras.
- Score d'une séance : ~36 px (text-4xl), extra-gras.
- Grandes valeurs de tuiles (14, 7) : 22 à 24 px, gras.
- Corps : 14 px. Secondaire : 12 px. Micro-libellés (badges, sous-titres de tuiles) : 11 px.

### Formes et espacements

- Rayons : 12 (`md`), 16 (`lg`), 20 (`xl`, cartes principales), pilule (9999) pour badges et bouton principal.
- Bordure des cartes : 1 px `background700`.
- Marges latérales d'écran : 16 px (écran de 375 px). Padding des cartes : 20 px (carte séance), 12 à 14 px (tuiles, lignes).
- Espacements de base : grille de 4 px (8, 10, 12, 16, 20, 32).

### Composants récurrents à factoriser

`AppCard`, `StatusBadge` (Clôturée, Victoire, Nul, Défaite, Amical), `TeamDot` (bleu A / orange B), `FormatPill` (5v5...), `InitialAvatar` (initiale sur fond teinté, couleur stable par joueur), `RankMedal` (1 jaune, 2 gris, 3 orange), `StatTile` (icône teintée + libellé + valeur), `SectionHeader` (titre + lien « Voir tout »), `PrimaryButton` (vert, pilule, icône « + »), `Stepper3` (cercles numérotés reliés par une ligne, étape active cerclée de vert), `ComingSoon`, `AppBottomNav`.

## 5. Navigation

Barre d'onglets fixe en bas, 5 entrées (icône + libellé 11 px) :
**Accueil** (`/`), **Joueurs** (`/joueurs`), **Séances** (`/seances`), **Classement** (`/classement`), **Stats** (`/stats`).
Onglet actif : icône pleine + libellé en `primary500` ; inactifs en `foreground500`.

Écrans hors onglets (poussés par-dessus, avec flèche retour dans l'app bar, sans barre d'onglets si c'est ce que montre la capture) : `/seances/nouvelle`, `/seances/:id`, `/joueurs/:id`, `/reglages` (roue dentée en haut à droite de l'Accueil).

Note : la maquette web contient aussi une variante desktop avec barre latérale. **Hors périmètre** : cible mobile (Android + iOS) uniquement, portrait.

## 6. Écrans à reproduire fidèlement

Compare ton rendu à la capture correspondante à chaque écran terminé.

**Accueil (`01-accueil.jpg`)**
- App bar : « Accueil » + icône réglages.
- Carte « dernière séance » : date (`9 sept.`) + badge « Clôturée » ; Équipe A (pastille bleue) score 5, tiret, Équipe B (pastille orange) score 3 ; séparateur ; pilule « 5v5 », « 10 joueurs », chevron. Toute la carte ouvre le détail de la séance.
- Bouton pleine largeur « + Nouvelle séance ».
- Section « Classement » + « Voir tout » : top 3 (médaille de rang, avatar initiale, prénom, surnom entre guillemets français « Lulu », points « 30 pts », matchs joués « J 14 »). Chaque ligne ouvre la fiche joueur.
- Trois tuiles : Joueurs (14), Séances (7), Stats.
- Pied : icône nuage + « Sauvegardé il y a 2 h » et action « Sauvegarder » (comportement selon le CDC).

**Nouvelle séance, étape 1 (`04-seances-nouvelle.jpg`)**
- App bar avec retour : « Nouvelle séance ». Stepper 1-2-3.
- « Quand joue-t-on ? » / « On pré-remplit à maintenant. Ajuste si besoin. »
- Carte : champ Date (jj/mm/aaaa, icône calendrier), champ Heure (hh:mm, icône horloge), bouton secondaire « Maintenant ».
- Bandeau de récapitulatif vert teinté : « jeu. 24 sept. 2026 · 17h38 », mis à jour en direct.
- Étapes 2 et 3 : voir règle 2.4.

**Détail séance (`08-seance-detail-s9.jpg`)**
- App bar « Détail séance » ; en-tête : date, badge statut, format, date et heure complètes, grand score A contre B.
- « Composition » : deux listes (Équipe A / Équipe B, « 5 joueurs ») avec avatars.
- « Score » (Équipe A 5, Équipe B 3).
- « Statistiques joueurs » (sous-titre « buts · passes · cartons ») : une ligne par joueur avec son équipe et ses compteurs.
- « Buts non attribués » par équipe.
- Actions en bas : « Rouvrir » et « Supprimer » (danger, avec confirmation).

**Fiche joueur (`09-joueur-detail-p1.jpg`)**
- App bar avec retour + prénom. Grand avatar, prénom, surnom, pilules « J 14 », « 30 pts », « 9 buts ».
- « Synthèse » (grille 2 colonnes) : Matchs joués (J), V / N / D, Points (en vert), Pts / match, % victoires, Format préféré.
- « Statistiques brutes » (tuiles) : Buts, Passes déc., Cartons jaunes, Cartons rouges, Apparitions.
- « Historique des séances » : lignes avec liseré coloré à gauche selon le résultat, date, badge (Victoire / Nul / Défaite / Amical), adversaire et format, score coloré, mini-stats du joueur.

## 7. Données de démo

Reprends **exactement** les données visibles dans les captures pour que la comparaison visuelle soit immédiate : 14 joueurs, 7 séances ; séance `s9` du mer. 9 sept. 2026 à 20h30, 5v5, clôturée, 5 à 3 ; Équipe A : Lucas, Karim, Sofiane, Mehdi, Hugo ; Équipe B : Yassine, Théo, Benjamin, Nicolas, Enzo ; classement : Lucas « Lulu » 30 pts J14, Yassine « Yass » 30 pts J14, Mehdi « Didi » 29 pts J12 ; fiche Lucas : 9 V / 3 N / 2 D, 9 buts, 11 passes, 1 jaune, 0 rouge, historique (9 sept. 5-3, 5 sept. 4-4, 2 sept. 0-0, 29 août 6-4, 22 août 2-3, 15 août 7-6 amical, 8 août 5-5). Complète le reste de façon cohérente avec les règles du CDC (les points affichés doivent découler du calcul du domaine, pas être codés en dur).

## 8. Démarche attendue

1. **Analyse d'abord, sans coder** : lis le CDC et toutes les captures, puis produis un court document `docs/analysis.md` : entités et règles métier, liste des écrans et de leur source (capture ou CDC), divergences design CDC contre captures, questions ouvertes. Arrête-toi et présente-le avant de continuer.
2. **Socle** : `flutter create` (org `com.kysolutions`, nom `statoo`, plateformes android et ios), dépendances, lints, thème et tokens, router et barre d'onglets, composants partagés.
3. **Domaine + données de démo**, avec tests unitaires des calculs.
4. **Écrans complets** dans l'ordre : Accueil, Détail séance, Fiche joueur, Nouvelle séance (3 étapes).
5. **Écrans décrits par le CDC mais en placeholder** dans la maquette, puis placeholders restants.
6. **Vérification** : `flutter analyze` sans avertissement, `flutter test` vert, tests de widget pour la navigation par onglets et le wizard, et idéalement des golden tests (375 x 812) de Accueil, Détail séance et Fiche joueur à comparer aux captures.

Commits petits et atomiques (Conventional Commits).

## 9. Livrables et rapport final

- Projet qui compile et tourne sur Android et iOS.
- `README.md` : lancement, architecture, choix techniques.
- Rapport final : ce qui est fait, écarts restants avec les captures, **divergences CDC contre captures et comment tu les as tranchées** (toujours en faveur des captures pour le design), hypothèses marquées `TODO(cdc)`, questions ouvertes.
