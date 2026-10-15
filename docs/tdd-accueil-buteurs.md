# Buteurs sur l'accueil — 15 octobre 2026

Scénarios et résultats attendus écrits avant le code applicatif.

| ID | Scénario | Résultat attendu |
| --- | --- | --- |
| BUT-01 | Match terminé avec buteurs A/B | Buteurs et nombres de buts sous leur équipe ; scores conservés. |
| BUT-02 | Tournoi terminé | Trois blocs verticaux A/B/C ; chaque entête associe nom, couleur et victoires, puis buteurs en dessous. |
| BUT-03 | Séance active classique ou tournoi | Même affichage des buteurs ; priorité et lien de reprise conservés. |
| BUT-04 | Participants d'une autre séance, joueurs sans but | Aucun de ces joueurs n'apparaît parmi les buteurs. |
| BUT-05 | Plusieurs buteurs | Tri par buts décroissants puis nom, comme le détail. |
| BUT-06 | Équipe sans but | « Aucun but enregistré » dans le bloc concerné. |
| BUT-07 | Buts non attribués | Ligne « Non attribués » avec leur nombre, sans état vide trompeur. |
| BUT-08 | Noms longs, nombreux buteurs, écran 320 px, thèmes clair/sombre | Retour à la ligne, tous les noms accessibles, aucun débordement. |
| BUT-09 | Chargement des participants | Indication de chargement ; pas de faux état « Aucun but enregistré ». |
| BUT-10 | Erreur de lecture des participants | Indication d'indisponibilité ; score et identité restent visibles. |
| BUT-11 | Actualisation des participants | Les nombres de buts sont mis à jour. |
| BUT-12 | Changement de séance affichée | Les buteurs de la précédente séance disparaissent. |
| BUT-13 | Navigation, filtres, sélection de dernière séance, état vide | Régressions existantes conservées. |

Les données proviennent de `sessionParticipantsProvider`, déjà limité à la séance et au groupe actif. Aucun cumul de carrière utilisé.

## Résultats observés

- RED : les 10 tests de `home_scorers_test.dart` échouent avant modification applicative sur les éléments de buteurs absents.
- GREEN : les 10 tests passent après implémentation. La commande `flutter test test/features/home test/features/sessions/session_header_test.dart` totalise 28 tests réussis.
- Les contrôles automatisés incluent une largeur de 320 px dans les deux thèmes. Aucune vérification visuelle sur téléphone effectuée.
