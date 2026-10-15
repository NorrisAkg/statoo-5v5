# Audit complémentaire PWA — 15 octobre 2026

Scénarios écrits avant les tests d'audit. Audit uniquement : aucune correction applicative incluse.

| ID | Situation à provoquer | Résultat attendu |
| --- | --- | --- |
| AUD-01 | Brouillon financier local de la révision 1, nouvelle révision 5 publiée ailleurs, réouverture du brouillon | Détection du brouillon périmé ; aucune publication silencieuse de l'ancien contenu sur la révision 5. |
| AUD-02 | Proposition de soldes modifiée, fermeture puis réouverture | Brouillon retrouvé ou confirmation explicite d'abandon avant perte. |
| AUD-03 | Mutation administrative acceptée, lecture de rafraîchissement en échec | Succès de l'écriture distingué de l'échec de lecture ; ne pas inviter à refaire l'action. |
| AUD-04 | Deux actualisations, la plus ancienne répond en dernier | La réponse ancienne ne remplace pas les nouvelles données. |
| AUD-05 | Égalité de points : un gagnant contre un membre avec trois nuls | Ordre identique au classement mobile : points, victoires, séances, nom. |
| AUD-06 | Une seule personne dans un match | Écart explicite avec le minimum mobile par défaut (6) ; règle partagée à définir plutôt qu'un seuil différent implicite. |
| AUD-07 | Catalogue d'équipes bloqué par un réseau lent | Connexion et consultation restent disponibles sans attendre ce fichier optionnel. |
| AUD-08 | Catalogue indisponible, modification d'une séance déjà nommée | L'édition de la séance existante reste disponible. |
| AUD-09 | Stockage local refusé par le navigateur | Message de limitation exploitable ; pas d'écran figé « Ouverture de Statoo… ». |
| AUD-10 | Noms d'équipes dans toutes les couleurs, thème clair | Contraste de texte normal au moins 4,5:1 sur la carte. |
| AUD-11 | Réponse API 503 HTML d'un proxy | Message compréhensible sur l'indisponibilité du serveur, pas une erreur technique de parsing JSON. |

Les suites existantes sont rejouées séparément des tests d'audit. Les nouveaux tests vérifient le comportement souhaité et restent rouges tant que les corrections correspondantes ne sont pas implémentées. Les captures sont locales et ignorées par Git.
