# Accueil — dernière séance (15 octobre 2026)

Scénarios écrits avant modification du code applicatif.

La dernière séance désigne la séance terminée ayant la date de jeu la plus récente dans le groupe actif. Une séance en cours garde la priorité. L'accueil ne dépend pas des filtres de l'onglet Séances.

| ID | Scénario | Résultat attendu |
| --- | --- | --- |
| ACC-01 | Filtre classées, dernière séance amicale à trois équipes | Le tournoi amical apparaît sur l'accueil. |
| ACC-02 | Filtre amicales, dernière séance classée | La dernière séance classée apparaît. |
| ACC-03 | Filtre brouillons | La dernière séance terminée reste visible. |
| ACC-04 | Liste non ordonnée, brouillon plus récent | Sélection de la séance terminée avec la date de jeu maximale. |
| ACC-05 | Tournoi terminé avec noms personnalisés et couleurs, compteurs de victoires différents | Trois noms, couleurs et nombres de victoires ; aucun faux score de match A/B. |
| ACC-06 | Match classique terminé | Deux noms et couleurs de séance, score A/B conservé. |
| ACC-07 | Séance active et séance terminée | La séance active garde la priorité. |
| ACC-08 | Aucune séance terminée, aucune séance active | État vide existant conservé. |
| ACC-09 | Données actualisées après clôture | La nouvelle dernière séance remplace l'ancienne sans rouvrir l'accueil. |
| ACC-10 | Appui sur le résumé du tournoi | Navigation vers le détail de ce tournoi. |

Vérification automatisée : `mobile/test/features/home/latest_session_test.dart`, puis régression des tests accueil et clôture. Vérification sur appareil à effectuer séparément.

## Résultats observés

- RED : 10 tests exécutés avant modification applicative, 7 échecs comportementaux (noms attendus absents), 3 réussites (priorité active, état vide, navigation).
- GREEN : les 10 tests passent après correction. La régression avec `home_tiles_test.dart`, `player_of_the_month_card_test.dart` et `session_close_test.dart` totalise 35 tests réussis.
- Aucun contrôle sur téléphone effectué pour ce correctif.
