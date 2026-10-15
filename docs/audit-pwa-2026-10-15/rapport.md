# Audit PWA — 15 octobre 2026

Les 93 tests de régression passent. L'audit complémentaire reproduit dix anomalies et un écart de règle métier à harmoniser. La priorité est de protéger les brouillons contre les modifications publiées depuis un autre appareil.

Audit uniquement : aucune correction du code applicatif réalisée dans cette passe. Les scénarios ont été écrits dans `scenarios.md` avant les nouveaux tests. Les onze tests d'audit vérifient le comportement souhaité et échouent actuellement ; ils constituent une base pour la correction en TDD.

## Vérifications exécutées

| Vérification | Résultat |
| --- | --- |
| `npm run build` | Succès : compilation Python, 38 tests backend, 27 tests unitaires web et génération du portail statique |
| `npm run test:web:browser` | 27 tests navigateur réussis |
| `flutter test test/features/shared/pwa_wire_import_test.dart` depuis `mobile/` | 1 test réussi : import du format PWA dans le schéma mobile |
| `node --test web/tests/audit/client.audit.mjs web/tests/audit/browser.audit.mjs` | 11 échecs comportementaux attendus, détaillés ci-dessous |

La régression couvre notamment les rôles, l'accès collectif en consultation, les formulaires sportifs et financiers, les tournois à trois équipes, les conflits, le mode hors connexion et les largeurs 320, 360, 390, 768 et 1440 pixels. Un parcours complet utilise une véritable API locale avec une base en mémoire isolée. Les cas complémentaires utilisent des réponses contrôlées pour provoquer les délais, erreurs et changements concurrents ; ils ne modifient aucune donnée de production.

## Corrections prioritaires

P1 désigne un risque de perte ou d'écrasement de saisie. P2 désigne un défaut de fiabilité, de cohérence ou d'accessibilité à traiter avant une diffusion large.

| ID | Priorité | Constat reproduit | Axe de correction et critère de validation |
| --- | --- | --- | --- |
| AUD-01 | P1 | Un brouillon financier créé à la révision 1 conserve une cotisation de 150. Après actualisation, le serveur présente la révision 5 avec une cotisation de 900. Réouvrir puis publier le brouillon envoie **150 avec `base_revision: 5`**. L'ancien contenu est ainsi présenté comme une modification de la version récente, ce qui neutralise la protection attendue contre ce conflit. | Conserver la révision d'origine et le contexte du brouillon. Signaler sa péremption avant publication ; proposer comparaison et reprise explicite. Vérifier que le contenu ancien ne part jamais silencieusement avec une nouvelle révision. |
| AUD-02 | P1 | Dans la proposition de soldes initiaux, saisir 450, fermer puis rouvrir remet le montant à 0, sans confirmation d'abandon. | Persister ce brouillon ou demander une confirmation lorsque la saisie modifiée va être abandonnée. Valider fermeture et réouverture avec conservation, ou abandon explicite. |
| AUD-03 | P2 | Une mutation administrative acceptée est présentée comme un échec lorsque l'actualisation qui suit échoue : une écriture a eu lieu mais le client remonte « Lecture indisponible ». | Séparer l'acquittement d'écriture et la relecture. Afficher « enregistré, actualisation indisponible » et permettre de relancer uniquement la lecture. Éviter d'inciter à répéter une action déjà acceptée. |
| AUD-04 | P2 | Deux actualisations du même compte répondent dans l'ordre inverse. La réponse ancienne remet le solde affiché à 100 après que la réponse récente a affiché 500. | Séquencer, annuler ou regrouper les lectures concurrentes ; une réponse dépassée ne doit remplacer ni l'affichage ni son cache. |
| AUD-05 | P2 | À égalité de trois points, le web place Amine avec trois nuls avant Zaki avec une victoire. Le mobile donne priorité aux victoires et produit l'ordre inverse. | Aligner le départage : points, victoires, séances, nom. Ajouter un contrat de classement partagé et des exemples communs aux deux clients. |
| AUD-07 | P2 | Si le téléchargement du catalogue des noms reste en attente, le portail reste sur « Ouverture de Statoo… » ; même la connexion attend cette ressource. | Afficher immédiatement la connexion ou le contenu local ; charger le catalogue indépendamment avec délai et erreur explicites. La consultation doit fonctionner sans lui. |
| AUD-08 | P2 | Un catalogue indisponible bloque également la modification d'une séance dont les noms sont déjà enregistrés. Le formulaire est remplacé par « Le catalogue d’équipes est indisponible ». | Réserver la dépendance au catalogue au tirage de nouveaux noms ; permettre l'édition des séances existantes. |
| AUD-09 | P2 | Lorsque le navigateur refuse l'accès à `localStorage`, une exception « Storage denied » interrompt le démarrage et laisse l'écran d'ouverture affiché. | Initialiser le stockage par un adaptateur protégé ; rendre une limitation compréhensible et désactiver proprement les fonctions qui nécessitent une persistance. Aucun écran d'attente permanent. |
| AUD-10 | P2 | En thème clair, les noms d'équipe jaunes, turquoise et roses sur fond blanc ont des contrastes respectifs de 1,53:1, 2,43:1 et 3,53:1. | Conserver la couleur dans un repère visuel et utiliser un texte lisible, ou choisir des variantes adaptées au thème. Vérifier toutes les couleurs dans les deux thèmes. |
| AUD-11 | P2 | Une réponse HTTP 503 HTML renvoie à l'utilisateur `Unexpected token '<'… is not valid JSON`. | Traiter le statut et le type de contenu avant le décodage ; afficher une indisponibilité du serveur et une possibilité de réessayer. |

Pour AUD-01, le test reproduit le contenu et la révision réellement envoyés par l'interface face à une API simulée. Il ne prétend pas avoir exécuté cet écrasement dans une base réelle. Le défaut est l'association du brouillon ancien avec la révision récente avant l'envoi.

Le seuil de contraste retenu pour le texte normal est 4,5:1, selon [WCAG 2.2, critère 1.4.3](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum).

## Règle métier à harmoniser

**AUD-06 — P2 : minimum de participants.** La validation web autorise la clôture d'un match avec un seul joueur. Le mobile applique un minimum configurable, fixé à six par défaut. Ce paramètre n'est pas transmis dans le contrat API actuel : il s'agit d'un écart entre plateformes, à résoudre en définissant puis partageant la règle du groupe. Éviter de coder arbitrairement six uniquement côté web ; synchroniser le paramètre et vérifier sa validation sur les clients et le serveur.

## Preuves et reprise

- Scénarios et résultats attendus : `scenarios.md`.
- Mesures des tests client : `client-results.json`.
- Mesures des tests navigateur : `browser-results.json`.
- Tests reproductibles : `web/tests/audit/client.audit.mjs` et `web/tests/audit/browser.audit.mjs` depuis la racine du projet.
- Captures locales : `mobile/build/pwa-audit/` ; exclues du suivi Git.

Pour relancer les tests navigateur, démarrer l'API de test isolée avec `backend/.venv/Scripts/python.exe web/tests/serve.py`, puis exécuter les commandes ci-dessus. Les tests d'audit restent séparés des suites de régression habituelles pour rendre visibles les défauts connus sans masquer leur résultat.

Ordre recommandé : protection des brouillons et des saisies ; fiabilité des écritures et actualisations ; cohérence des règles sportives ; démarrage dégradé et indépendance du catalogue ; contraste et messages d'erreur.

## Limites

Tests navigateur réalisés avec Chrome automatisé. L'installation réelle Android/iOS, Safari et les lecteurs d'écran TalkBack/VoiceOver restent à vérifier sur appareil. Les tests verts ne constituent pas une validation exhaustive de ces environnements. Le backend émet aussi un avertissement de dépréciation Starlette/httpx, sans échec de test.
