# Responsive petits écrans — 17 octobre 2026

## Périmètre et scénarios avant code

Objectif transversal Flutter mobile/web : mise en page selon les contraintes disponibles, sans réduction globale de police, plafonnement du texte ni mise à l'échelle du canvas. Les dp Flutter sont déjà logiques ; les proportions seules ne garantissent pas une interface lisible. Préférer Flexible/Expanded, Wrap et hauteurs naturelles ; conserver les cibles 48 dp.

Références : design-system, thème Poppins clair/sombre, AppCard, PrimaryButton ; accueil/joueurs, création groupe/effectif, onboarding et réglages.

- RSP01 : boutons partagés avec libellé long à 320/393 et texte 100/130/200 : texte intégral, hauteur naturelle, cible >=48, action accessible.
- RSP02 : création groupe, passage vers effectif : formats et validation sans débordement, texte intégral à 320/393 × 100/130/200 × clair/sombre ; validation du nom et conservation des champs avec clavier.
- RSP03 : accueil vide et séance active, noms longs : en-têtes/indicateurs s'adaptent, dates et actions consultables sans débordement.
- RSP04 : joueurs avec nom/surnom/groupe longs : sous-titre d'en-tête non coupé, commandes essentielles dans l'écran, recherche et ajout inchangés.
- RSP05 : écrans principaux (bienvenue, effectif, séances, classement, statistiques, réglages, connexion partagée, nouvelle séance) : matrice 320/393, deux thèmes et texte 100/130/200 ; pas d'exception de layout ; vérifier les actions accessibles après défilement. Les états/data réellement testés seront détaillés.
- RSP06 : navigation principale : 5 destinations accessibles à grand texte sans libellés tronqués, cibles >=48, destination sélectionnée et retour conservés.
- RSP07 : formulaires avec clavier 300/350 px et zones sûres : saisie conservée, champ actif et actions accessibles ; aucune double soustraction du clavier.
- RSP08 : régressions : parcours, autorisations, sauvegarde/restauration et données métier inchangés ; réexécuter tests Flutter existants.
- RSP09 : navigateur : 320/390/393, clair/sombre, texte agrandi, clavier simulé ; captures du vrai build. Le clavier natif et Safari/Chrome sur iPhone restent une recette physique distincte.

## Baseline

84/84 tests existants de cadrage passent (`responsive-baseline.txt`) : finance, tarifs, onboarding, édition joueur et détail séance. Leur succès ne prouve ni une couverture de tous les écrans ni l'absence de troncature.

## Cas supplémentaires avant correction

RSP10 : les indicateurs et descriptions de tableaux de bord restent à la taille de texte demandée. Pas de FittedBox pour réduire les chiffres, ni de maxLines=1 masquant une explication ; les cartes passent en une colonne si leur largeur utile ne suffit plus. Vérification comportementale sur descriptions complètes et transformation des chiffres.

RSP11 : dans le navigateur, réserver une zone pour le menu PWA afin qu'il ne recouvre pas les titres/commandes Flutter, à 320/390/393 et texte 100/130/200. Conserver les métriques de clavier de Flutter et la sémantique. Vérifier sur le vrai build par mesure des rectangles du menu et du badge de création, sans remplacer l'application par une maquette.

## Choix d'implémentation

- Les unités Flutter sont déjà des pixels logiques (dp). Adaptation par contraintes et taille du texte plutôt qu'un pourcentage appliqué à tous les widgets.
- Bouton principal : texte complet sans ellipsis, hauteur naturelle et cible minimale 48 dp.
- Grilles accueil/statistiques : nombre de colonnes calculé selon largeur utile et texte ; pas de réduction graphique des valeurs. Textes d'explication sur plusieurs lignes.
- Accueil : titre du groupe flexible avec tooltip existant, date/statut et en-têtes repliables, nom/surnom du MVP et du classement sur plusieurs lignes, pied de page avec retour à la ligne.
- Sous-titres Joueurs/Séances : mesure avec la police du thème pour réserver la hauteur réelle du texte ; états vides des séances défilants.
- Création : validation sans hauteur fixe ; nom du groupe flexible dans l'effectif ; bouton de fin défilant avec clavier/grand texte pour préserver l'espace des champs.
- Navigation : largeur de chaque destination calculée sur son libellé et l'échelle du texte ; défilement horizontal au besoin, sélection ramenée dans la zone visible, pas de plafonnement du texte.
- Web : zone supérieure réservée au menu PWA dans Flutter, moteur plein écran conservé afin de préserver les métriques de clavier ; natif inchangé.

## Preuves avant correction

- `responsive-red.txt` : 64 échecs comportementaux sur 156 variantes (bouton, création, accueil actif, effectif, joueurs, séances, classement, statistiques).
- `responsive-rich-red.txt` : défauts supplémentaires sous la ligne de flottaison, MVP/classement avec noms longs, pied de page.
- `responsive-navigation-red.txt` : troncature à 320 dp et navigation ramenant le texte à 100 % malgré un texte demandé à 130/200 %.
- `responsive-kpi-red.txt` / `responsive-home-kpi-red.txt` : descriptions tronquées et chiffres réduits par transformation graphique.
- `responsive-browser-red.txt` : menu PWA recouvrant le badge de création sur le vrai build Flutter.
- Première régression complète : 785 passent, 2 échecs pertinents dans l'effectif à 320/568, texte 200 %, clavier 300. Bouton fixe déplacé dans le défilement pour cette situation.

Les compilations échouées pendant les ajustements ne sont pas des preuves RED et ne sont pas comptabilisées comme validations.

RSP12 (après examen visuel, avant correction) : badges d'étape de création/effectif entièrement lisibles à grand texte ; le bandeau PWA adopte le fond clair/sombre du thème. La capture à 320/130 % a montré un badge tronqué malgré l'absence de RenderFlex. Vérifier didExceedMaxLines puis revoir les captures. La recette navigateur doit utiliser le défilement Flutter pour atteindre les actions, pas seulement scrollIntoView du DOM sémantique.

RSP13 avant correction : à 320 px et texte 200 %, le résumé Application ne doit pas être coupé en deux lignes quand sa largeur naturelle tient dans l'écran. Le positionnement fixed à left:50% limitait sa largeur implicite à une demi-fenêtre ; fixer une largeur intrinsèque, toujours bornée par le viewport, et vérifier sa hauteur en navigateur.

## Résultats finaux et périmètre vérifié

- 787/787 tests Flutter passent : `responsive-flutter-all-green.txt`. Les 238 tests ciblés ajoutés couvrent 228 variantes d'écrans + 6 variantes de navigation + 4 vérifications de l'enveloppe navigateur.
- Analyse ciblée : 17 fichiers, aucune anomalie (`responsive-analysis-final.txt`). Build release réussi en 51,8 s (`responsive-build.txt`).
- Web : 68/68 tests unitaires/shell/focus (`responsive-web-regression.txt`) ; après ajustement de largeur du menu, les 7 tests shell/focus repassent (`responsive-shell-final.txt`).
- Packaging : 80 ressources, version `1c689943c8c99633`. Le dernier changement CSS a été copié du source `mobile/web/pwa-shell.css` vers le build compilé avant packaging ; aucun fichier Dart compilé n'a été modifié après le build.
- Badges d'étape : hauteur mesurée avec le thème et les commandes latérales, texte non tronqué. Bandeau web peint avec le fond du thème. Résumé Application à largeur intrinsèque bornée par le viewport.

### Couverture de la matrice Flutter

| Écran/état | Couvert ici |
| --- | --- |
| Accueil | Vide, séance active, MVP et classement avec noms/surnoms longs, indicateurs à six chiffres, pied de page après défilement. |
| Joueurs | Liste avec un joueur actif au nom/surnom longs, groupe long, recherche/commandes affichées. Les autorisations et mutations sont vérifiées par les régressions existantes. |
| Création groupe | Validation atteignable, badge lisible, champs conservés après fermeture/réouverture du clavier. |
| Effectif | Joueur long, nom du groupe, bouton de fin, clavier et grand texte. |
| Séances | État vide, filtres et titre de groupe long ; scénarios métier existants dans la régression complète. |
| Classement | Sélecteur Championnat/MVP et onglets, état vide ; tableaux remplis testés séparément dans la suite existante, pas toutes leurs combinaisons responsive ici. |
| Statistiques | Totaux nuls et six chiffres, descriptions complètes, carte d'incohérence, visite du contenu sous la ligne de flottaison. |
| Réglages / connexion partagée / nouvelle séance | État local initial ; clavier pour connexion/nouvelle séance. |
| Finance / tarifs / onboarding / édition joueur / détail séance | Matrices antérieures conservées et réexécutées dans les 787 tests. |

La matrice nouvelle emploie 320×568 et 393×852 dp, texte 100/130/200 %, deux thèmes ; variantes clavier 300 px et zones sûres sur création/effectif/connexion/nouvelle séance. La zone PWA est incluse dans les contraintes des écrans testés.

### Limites

Pas de recette sur iPhone physique, ni clavier natif, VoiceOver, sélecteur photo ou toutes les combinaisons de données/rôles/dialogues. Les tests sans exception ne valent pas validation visuelle. Les captures navigateur concernent le vrai build avec Poppins sur Chrome Windows ; les rectangles et le défilement Flutter sont contrôlés. Aucun commit, push ou déploiement réalisé ; modifications préexistantes conservées.

RSP14 avant correction : le libellé Nom court (facultatif) doit rester complet à 200 %, même lorsque le champ est vide ; les placeholders peuvent se résumer, pas le libellé permanent. La capture navigateur a montré une ellipsis sur ce libellé.

## Livraison finale après les derniers contrôles visuels

Cette section remplace les chiffres de build/package intermédiaires ci-dessus.

- **787/787 tests Flutter** passent sur le code final (`responsive-flutter-all-green.txt`). Contrôle ciblé supplémentaire création/parcours/libellés : **256/256** (`responsive-label-final.txt`).
- **Analyse de 17 fichiers : aucune anomalie**, 8,6 s (`responsive-analysis-final.txt`).
- **Build release final : succès**, compilation 54,1 s (`responsive-build.txt`). Tous les fichiers de l'enveloppe, dont la largeur intrinsèque du menu, proviennent de ce build neuf.
- **18 configurations navigateur réussies** : 320/390/393 px × texte 100/130/200 % × clair/sombre, Chrome Windows, police Poppins du vrai build. Aucun pageerror JS ; menu/badge sans intersection, navigation initiale et action de création atteintes par défilement Flutter, saisie conservée. Résultats : `responsive-browser-green-final.txt`.
- **Package final** : `243e52bdd4af5faa`, 80 ressources, `web/universal-dist` (`responsive-package.txt`). Aucun déploiement distant.
- Les captures sous `responsive-captures/` représentent trois positions par configuration : bienvenue, formulaire et action après défilement. Captures examinées séparément : création à 320/130 % clair, 320/200 % clair et 393/200 % sombre, ainsi que leurs actions de validation. L'examen d'une capture à une position défilée ne valide pas toutes les positions de tous les écrans.
- Le libellé Nom court et son aide sont désormais hors du label flottant mono-ligne : texte complet avec retour à la ligne, nom sémantique conservé sur le champ, limite de 30 caractères inchangée. RED constaté dans `responsive-field-label-red.txt` avant la correction.

La recette sur iPhone physique reste nécessaire pour confirmer clavier natif, fluidité, VoiceOver et installation système. Les tests navigateur ne remplacent pas cette recette.

### Revue avant commit

Revue dédiée `statoo-reviewer` effectuée le 17 octobre : aucun défaut actionnable confirmé dans le périmètre responsive/iOS/PWA ; contrôle supplémentaire du manifeste/bootstrap 2/2 réussi. Les limites physiques restent celles indiquées ci-dessus. Les espaces de fin de ligne des journaux ont été retirés sans modifier les résultats.
