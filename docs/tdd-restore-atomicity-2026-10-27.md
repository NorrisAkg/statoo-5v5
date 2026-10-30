# F14 — Restauration et réglages atomiques

## Scénarios écrits avant le code

La restauration complète ne doit plus écrire dans SharedPreferences. Groupe actif,
minimum global de secours et marqueur de remplacement sont validés avec les données
SQLite. Le marqueur empêche une migration rétrocompatible de ressusciter un groupe
après une restauration vide. Aucune modification d'écran ni du format JSON.

1. Exception après le callback SQL mais avant commit : anciennes données ET anciens réglages effectifs ; préférences inchangées.
2. Succès : groupe et minimum restaurés lus par les repositories réels, préférences anciennes inchangées.
3. Nouvelle instance de repository après succès : mêmes réglages ; export reflète le minimum SQL.
4. Restauration vide : aucun groupe actif, aucune résurrection du nom historique, même après relecture.
5. Groupe actif valide du fichier conservé ; ID absent/invalide remplacé par le premier groupe importé.
6. Minimum absent du fichier : conserver le minimum effectif antérieur (SQL après restauration, sinon préférences) ; défaut inchangé si tous absents.
7. Réglage propre au groupe prioritaire sur le minimum global restauré.
8. Fusion : ne change ni le minimum global ni le marqueur de remplacement.
9. Sans restauration : migration historique et lecture des préférences toujours possibles.
10. Marqueur interne exclu de l'export et non dicté par le fichier importé.
11. Échec d'insertion SQL : aucune mutation des préférences ou de l'état SQL.

Les tests historiques qui inspectaient directement SharedPreferences après succès
seront adaptés pour vérifier les repositories réellement consommés par l'application.
L'atomicité repose sur la transaction SQLite existante, sans protocole à deux magasins.
Les coupures physiques et la durabilité du moteur SQLite web ne sont pas simulées par
une fermeture réelle du navigateur ; les exceptions de fin de transaction sont injectées.

Compléments avant vérification finale : scénario 3 utilise une fermeture/réouverture
réelle d'un fichier SQLite temporaire. Sans minimum nulle part, le repository renvoie
null et conserve le repli par défaut du provider. Après restauration vide, une création
explicite de groupe reste possible et devient active (le marqueur bloque seulement la
migration implicite des anciennes préférences).

## Résultats observés

- RED : 7 échecs comportementaux et 5 succès (`restore-atomicity-red-2026-10-27.txt`). Une première erreur de compilation de fixture (argument `team`) a été corrigée avant ce RED.
- GREEN ciblé : 157 tests sauvegardes/réglages/groupes/démarrage, 36 s (`restore-atomicity-green-2026-10-27.txt`). Une assertion de fixture supposait `meta` vide alors que le schéma y écrit `schema_version` : elle compare désormais le contenu avant/après, sans affaiblir le contrôle de rollback.
- Compléments de persistance : 14 tests, 2 s, dont fermeture/réouverture du fichier SQLite (`restore-atomicity-persistence-2026-10-27.txt`).
- Les assertions historiques post-restauration passent par les repositories utilisés par les providers ; les vérifications d'absence de mutation sur rejet restent conservées.

## Choix de stockage

`meta.active_team_id` et `meta.min_players_per_session` portent les réglages
restaurés. Les réglages par groupe gardent leur priorité. Le marqueur local
`_restore_completed` interdit seulement le repli vers la migration des anciens noms
et identifiants ; il n'empêche pas une création explicite. Il n'est pas exporté et la
restauration ne fait pas confiance à sa valeur dans le fichier. Le minimum global est
également projeté dans le champ JSON existant `minPlayersPerSession`.

Aucune écriture SharedPreferences ne participe à la restauration complète. Une
exception SQL annule données et réglages ensemble. Les installations sans restauration
conservent leur compatibilité avec les anciennes préférences. La fusion ne change pas
ces réglages globaux. Ce choix évite un journal de compensation entre deux magasins.

Validation finale : **995 tests Flutter réussis en 3 min 08 s**, analyse ciblée sans
diagnostic, `git diff --check` réussi. Revue distincte sans défaut bloquant :
[review-restore-atomicity-2026-10-27.md](review-restore-atomicity-2026-10-27.md).
Le contrôle automatique d'approbation avait temporairement bloqué les deux dernières
commandes pour limite d'usage ; elles ont ensuite été exécutées avec succès après
la demande de reprise de l'utilisateur. Aucun contournement ni commit.
