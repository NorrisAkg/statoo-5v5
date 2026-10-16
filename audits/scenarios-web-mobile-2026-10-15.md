# Scénarios de vérification de l’audit comparatif

Écrits avant la sonde navigateur de cette passe ; aucun code applicatif modifié.
API locale en mémoire, réponses métier synthétiques, aucune production.

| ID | Scénario | Résultat attendu pour une expérience fluide |
| --- | --- | --- |
| CMP-01 | Consulter accueil, membres et formulaire sportif à 390 et 1440 px, avec 24 membres | Pas de débordement horizontal ; fonctions lisibles et accessibles |
| CMP-02 | Rechercher une séance puis déclencher le callback périodique de 45 s | Recherche et focus conservés après actualisation |
| CMP-03 | Ouvrir nouvelle séance, cocher un présent au clavier | Focus conservé sur le contrôle activé |
| CMP-04 | Ouvrir un formulaire modal | Le dialogue possède un nom accessible relié au titre |
| CMP-05 | Ouvrir Séances puis recharger | Parcours courant conservé ou restauration explicite |
| CMP-06 | Saisir 450 de caisse initiale, fermer et rouvrir | Saisie conservée ou confirmation préalable de l’abandon |
| CMP-07 | Sur un groupe nombreux, sélectionner tous les présents | Recherche et sélection collective disponibles comme sur mobile |

Les résultats observés sont enregistrés dans `comparaison-web-mobile-2026-10-15/results.json`.
Les captures concernent uniquement le web : elles ne prouvent pas une comparaison visuelle sur appareil Flutter.
