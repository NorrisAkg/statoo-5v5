# Rendu web et identité visuelle — scénarios avant code

| ID | Situation | Résultat attendu |
| --- | --- | --- |
| DESK-01 | En-tête à 320, 390, 768, 1280, 1440 et 1920 px | Logo existant visible, nom sans retour à la ligne, en-tête compact, actions accessibles et aucun débordement horizontal. |
| DESK-02 | Création sur grand écran | Introduction alignée en haut du formulaire, largeur du contenu exploitée ; accès Admin et collectif en colonnes, informations du groupe regroupées. |
| DESK-03 | Connexion, préparation hors ligne et petits écrans | Formulaires lisibles sur une colonne, cibles de 44 px, ordre logique et reprise locale inchangée. |
| DESK-04 | Thèmes clair et sombre | Logo non déformé et lisible, contrastes des champs conservés ; contrôle visuel avec captures. |
| DESK-05 | Favicon, build et hors ligne sous /portal/ | Logo et favicon issus des assets existants, servis et intégrés au shell ; aucun chargement externe. |
| DESK-06 | Tableau de bord et tournoi sur écran large | Largeur adaptée, trois équipes côte à côte sur grand écran ; disposition mobile conservée. |
| DESK-07 | Parcours et accessibilité | Tous les libellés et actions existants restent disponibles ; groupes de champs décrits par leurs légendes, logo avec nom accessible. |

Réutiliser le logo JPEG natif et les déclinaisons d'icônes existantes sans modifier leur dessin. Les captures restent locales dans mobile/build/pwa-desktop/.

## Exécution

- RED avant implémentation : le test détecte le faux logo « S » et l'absence d'image dans la marque.
- Le test de colonnes compare les accès Admin et collectif, conformément au scénario ; leurs mots de passe restent à l'intérieur de chaque section.
- GREEN ciblé : rendu à 320, 390, 768, 1280, 1440 et 1920 px, clair et sombre ; en-tête inférieur à 96 px, absence de débordement, introduction alignée et accès en colonnes sur grand écran. Trois équipes en colonnes sur desktop et empilées sur mobile.
- Vérification visuelle des captures 1440 px clair/sombre et 390 px sombre. Logo réutilisé à l'identique (SHA-256 identique à l'asset natif) ; favicon repris de l'icône iOS existante, sans génération ni retouche.
- `npm run build:web` : 35 tests unitaires réussis et portail statique généré. Nouveau shell versionné avec logo et favicon inclus pour le hors connexion.
- Aucun nouveau test sur appareil physique. Le périmètre visuel a révélé le correctif serveur décrit ci-dessous pendant la régression.

## Cas découvert pendant la régression — avant correction

DESK-08 : FastAPI peut ouvrir et fermer la dépendance de session dans des threads distincts. Le verrou doit être libéré sans erreur, puis permettre une autre requête. La suite navigateur concurrente a provoqué `RuntimeError: cannot release un-acquired lock`, puis des timeouts sur les créations. Écrire un test déterministe ouvrant la dépendance dans un thread et la fermant dans un autre avant de remplacer le verrou lié au thread. Conserver le même périmètre de sérialisation des transactions locales.

Preuve RED : `backend/tests/test_session_lock.py` reproduit exactement l'exception lors de la fermeture dans l'autre thread. GREEN ciblé : remplacer `RLock` par `Lock` permet cette fermeture et une nouvelle ouverture de session. Les suites complètes sont relancées avec les fichiers navigateur concurrents pour vérifier le défaut initial.

Le premier rejeu après correction passe les créations réelles et la reprise hors connexion, mais une navigation initiale dépasse 30 secondes avec cinq instances Chrome démarrées simultanément sur le poste. La commande de régression limite désormais les fichiers concurrents à deux pour maîtriser la charge ; les assertions et délais des parcours ne sont pas assouplis.

Résultat final : `npm run build` réussi, avec 44 tests backend et 35 tests unitaires web ; `npm run test:web:browser` réussi, 33 tests navigateur. Total : 112 tests réussis. Le seul avertissement backend concerne la dépréciation Starlette/httpx déjà présente.
