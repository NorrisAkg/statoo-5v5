# F05 — Refus isolés dans la file de synchronisation

## Scénarios et résultats attendus définis avant code applicatif

- QUE01 : un POST reçoit 400/403/404/409 générique/410/422. Conserver son
  contenu et son identifiant avec statut `rejected`, code et message persistés ;
  continuer les documents indépendants. Le refus ne fait pas échouer toute la passe.
- QUE02 : 401 (connexion), 408/429, 5xx, réseau ou réponse illisible : conserver
  `pending`, mémoriser l'erreur, arrêter la passe et remonter l'erreur. Une reprise
  retransmet exactement le même wire/operation_id ; les métadonnées d'erreur ne
  doivent jamais entrer dans le fingerprint serveur. Pas de boucle de retry immédiate.
- QUE03 : deux opérations visent le même document (domain + occurrence_id) ;
  après le refus de la première, différer les suivantes jusqu'à la prochaine
  passe. Un document indépendant, même dans l'autre domaine, continue.
- QUE04 : ne pas réessayer automatiquement un refus permanent. Une nouvelle
  correction explicite crée une nouvelle opération ; son acquittement remplace
  l'avertissement précédent, sans supprimer la preuve de refus.
- QUE05 : un snapshot distant avant/après le refus ne remplace pas les données
  sportives/financières non publiées ni l'état actif local associé. Après
  acquittement d'une correction, l'import distant normal reprend. Considérer la
  dernière opération de chaque auteur/document : un ancien refus ne bloque pas
  indéfiniment l'import après sa correction, mais reste isolé d'un autre auteur.
- QUE06 : restaurer le service sur la même base ; le refus et l'avertissement
  persistent. Une correction encore en attente ne masque pas l'erreur initiale.
- QUE07 : une opération d'un autre groupe/auteur est ignorée et inchangée.
- QUE08 : `active_session_conflict` conserve son statut `blocked` et son
  comportement actuel ; les tests de cycle de vie existants restent verts.
- QUE09 : une erreur globale de GET ou de POST déclenche une notification avec
  `syncWarning`, même si le timer absorbe l'exception ; aucune réussite inventée.
- QUE10 : une réponse après déconnexion ne modifie ni les états locaux ni les
  secrets ; conserver la protection F04 et les autres contrôles existants.

## Périmètre

Modifier le service commun Flutter mobile/web ; conserver le contrat API et
l'interface existante qui affiche `syncWarning`. Les refus permanents sont des
événements conservés, pas une suppression d'outbox. La correction s'effectue par
l'édition/publication habituelle, pas par un bouton de retry ajouté dans ce lot.
Un refus générique 409 est isolé ; le conflit métier 200/candidate reste inchangé.
Un changement de droits après 403 ne relance pas l'ancien événement : une nouvelle
édition explicite est nécessaire. Les dépendances entre documents distincts ne
sont pas déduites par le client ; le serveur continue de les contrôler.

## Résultats

- RED initial : 14 échecs comportementaux et 2 succès. L'opération indépendante
  n'était pas envoyée après le refus ; les erreurs temporaires n'étaient pas
  persistées/notifiées. Preuve : `outbox-rejections-red-2026-10-25.txt`.
- GREEN ciblé final : **40 tests réussis**, en 1 s (17 nouveaux cas et 23 tests
  existants de service/cycle de vie/déconnexion). La revue a renforcé le test
  financier et ajouté le contrôle d'isolation entre auteurs, sans nouveau code
  applicatif après ces vérifications. `outbox-rejections-green-2026-10-25.txt`.
- Analyse ciblée : uniquement les 3 informations préexistantes sur l'ordre des
  imports ; aucun nouveau diagnostic. `outbox-rejections-analyze-2026-10-25.txt`.
- Régression Flutter complète : **881 tests réussis en 2 min 03**, code figé ;
  `outbox-rejections-regression-2026-10-25.txt`.
- Revue distincte : `review-outbox-rejections-2026-10-25.md` ; aucun défaut
  bloquant identifié dans le périmètre. `git diff --check` passe.

Les tests ciblés utilisent SQLite et le stockage sécurisé simulé, avec réponses
de transport contrôlées. Ils ne constituent pas une recette manuelle sur téléphone,
navigateur ou serveur PostgreSQL réel.
