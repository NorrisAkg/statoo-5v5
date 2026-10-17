# TDD — nouveau joueur et clavier — 17 octobre 2026

Avant code : références design-system, thème/PrimaryButton, édition joueur et ajout effectif relues.

- KBD01 : à 390×844, clavier 350 px, texte 100 %, nom/surnom et actions Créer/+ visibles sans devoir fermer le clavier après saisie.
- KBD02 : Masquer le clavier retire le focus sans perdre nom/surnom ; réouverture reprend les valeurs.
- KBD03 : + crée une seule fois, efface les champs et refocalise Nom ; Créer conserve la fermeture actuelle. Doublon affiche une erreur sans perdre les valeurs.
- KBD04 : 320/393 px, clair/sombre, texte 100/130/200 %, clavier 350 px : aucune exception de layout et actions atteignables par défilement. Cela ne prouve pas la qualité visuelle.
- KBD05 : sans clavier, photo 96 px et aide conservées ; avec clavier photo compacte mais accessible, pas de réduction de la police ou des cibles tactiles.
- KBD06 : permissions et garde de soumission conservées ; fermeture du clavier ne crée aucun joueur.

Recette physique restante : iPhone Safari/Chrome, clavier prédictif, rotation, zones sûres, saisie photo et fluidité réelle. Aucun contrôle natif iOS simulé par un widget test.

## Résultats

- RED comportemental : bouton Créer à y=522 alors que le clavier commence à y=494. Les 14 autres tests passaient ; `player-keyboard-red-run.txt`.
- GREEN : 15 tests ciblés, dont les 12 variantes largeur/texte/thème ; `player-keyboard-green.txt`.
- Régression joueurs : 23/23 tests, y compris permissions, doublons et ajout en série ; `player-keyboard-regression.txt`.
- Réalisation : avatar 48 px au lieu de 96 pendant l'ouverture du clavier, espacements secondaires réduits, aide sur l'avatar retirée uniquement pendant la saisie, commande Masquer le clavier préservant les contrôleurs. Les actions et étapes métier restent identiques sur Flutter mobile/web.
- Pas de nouvelle capture ni recette visuelle sur iPhone physique. Les tests simulent un inset de 350 px ; ils ne mesurent pas la fluidité native iOS. Aucun build ou déploiement pour ce lot.
