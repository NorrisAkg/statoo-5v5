# F13 — Export SQLite cohérent pendant une écriture concurrente

## Scénarios définis avant code applicatif

L'export doit lire teams, players, sessions, participations et meta dans un même
état SQLite. Le format v2, les champs et les parcours de sauvegarde restent les
mêmes. Les transactions métier soumises pendant la lecture doivent se terminer
ensuite sans perte ; ne pas attendre une écriture extérieure depuis la transaction.

- SNAP01 : après lecture de teams, players, sessions ou participations, soumettre
  une transaction modifiant atomiquement nom du groupe, joueur, score, buts et
  marqueur meta → l'export conserve l'état initial entier, puis l'écriture aboutit.
- SNAP02 : remplacement atomique du groupe et de tous ses enfants après lecture
  de teams → aucune référence à un nouveau groupe absent des teams exportées.
- SNAP03 : écriture terminée avant l'export → tous les champs sont récents.
- SNAP04 : base vide et préférences absentes → listes vides, team null, version
  courante ; les métadonnées présentes sont conservées.
- SNAP05 : lecture qui échoue au milieu de l'export → exception propagée, aucun
  payload partiel ; base inchangée et verrou libéré pour une écriture et un export.
- SNAP06 : export pendant écriture, sérialisation JSON puis restauration sur une
  autre base → données initiales et FK cohérentes, métadonnées conservées.
- SNAP07 : deux exports autour d'une écriture concurrente → premier état cohérent
  initial, second état cohérent récent, aucune attente infinie.
- SNAP08 : paramètre historique min_players_per_session des préférences conservé
  à sa valeur lue ; pas de prétention à une transaction entre SQLite et préférences.

Les tests instrumentent uniquement la pause après SELECT ; les lectures, verrous,
écritures et restaurations emploient SQLite réel. L'écriture est mise en file avant
la reprise du SELECT. Les tests restent bornés et ne touchent pas la base utilisateur.
La transaction ordinaire sqflite est utilisée sur le code partagé web/mobile,
readTransaction étant expérimental et non pris en charge par tous les pilotes.

## Résultats et limites

- RED : **7 échecs comportementaux, 3 réussites** : données anciennes et récentes
  mélangées dans le même payload. [Journal](backup-snapshot-red-2026-10-27.txt).
  L'erreur initiale de compilation de la sonde et l'expiration du contrôle
  d'approbation ne sont pas utilisées comme preuve du défaut.
- GREEN ciblé : **75 tests réussis**, dont 10 nouveaux, en 4 secondes ; versions,
  formats, fusion/remplacement et tournois inclus.
  [Journal](backup-snapshot-green-2026-10-27.txt).
- Analyse finale : **aucun problème détecté**, après correction des trois
  remarques. [Journal](backup-snapshot-analyze-2026-10-27.txt).
- Suite Flutter complète : **981 tests réussis**, en 2 min 54 s, sur la version
  finale. [Journal](backup-snapshot-regression-2026-10-27.txt).
- Contrôle final git diff --check réussi.
- [Revue distincte](review-backup-snapshot-2026-10-27.md) : aucun défaut bloquant.

Ne couvre pas l'atomicité SQLite/préférences pendant une restauration, ni la
portabilité des fichiers photo, ni deux processus ou onglets concurrents. Aucun
changement d'écran ou recette physique. Modifications non commitées.
