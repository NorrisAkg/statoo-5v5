# F13 — Revue distincte après implémentation

## Périmètre relu

createBackupPayload, les sondes de lecture et scénarios concurrentiels, et la
documentation. Revue après les 75 tests ciblés GREEN. Le diff de backup_service
contient aussi les gardes de version F07, antérieures à ce lot.

## Constats

- Les cinq lectures utilisent exclusivement txn, dans une transaction unique.
  Aucun appel db extérieur ni écriture concurrente n'est attendu depuis ce bloc,
  ce qui évite un blocage sur le verrou sqflite.
- Les préférences sont lues avant la transaction, dans leur propre stockage.
  La garantie porte sur SQLite et ne prétend pas englober SharedPreferences.
- La transaction ordinaire est déjà utilisée par les chemins de restauration et
  synchronisation du code commun. Pas d'API readTransaction expérimentale ni de
  branche divergente web/mobile ajoutée.
- Le format v2, les champs, les identifiants et l'alias team sont conservés. Le
  timestamp reste celui de construction du payload. Aucun nouveau secret exporté.
- L'encodage, l'écriture du fichier et son partage se produisent après la fin de
  createBackupPayload. Le verrou ne reste pas détenu pendant un sélecteur ou une
  feuille de partage. Les écritures concurrentes de l'application sont retardées
  pendant la lecture ; leur aboutissement est vérifié.
- Une exception de lecture annule la transaction et se propage. Le test confirme
  l'absence de modification des données et la possibilité d'écrire/exporter ensuite.
- Les tests emploient les vrais verrous, requêtes et transactions SQLite. La sonde
  ne fabrique pas les données ; elle pause un SELECT déjà exécuté pour mettre une
  écriture atomique en file, puis laisse reprendre la lecture. La restauration
  finale est testée dans une autre base avec contrôle des clés étrangères.

Aucun défaut bloquant relevé dans le périmètre.

## Vérifications et limites

- RED : 7 échecs comportementaux de cohérence, 3 réussites ; aucun changement
  applicatif avant cette preuve. Le premier échec de compilation de la sonde et
  le timeout initial du contrôle d'approbation ne sont pas des preuves RED.
- GREEN ciblé : 75 tests réussis, dont 10 nouveaux, en 4 secondes.
- Analyse : trois remarques corrigées (await de retour, annotation de surcharge,
  callback de nettoyage) ; vérification finale sans diagnostic.
- Suite complète Flutter : 981 tests réussis en 2 min 54 s sur la version finale.
  Premier lancement interrompu pour intégrer les remarques d'analyse, non retenu
  comme preuve. Contrôle final git diff --check réussi.
- Pas de contrôle navigateur concurrent, de second processus ou d'appareil
  physique. Code commun vérifié par SQLite FFI et régressions Flutter.
- La transaction capture l'état SQLite ; elle ne rend pas atomiques les mutations
  métier qui seraient elles-mêmes écrites en plusieurs opérations indépendantes.
- L'atomicité SQLite/préférences de restauration et la portabilité des photos
  restent des sujets distincts. Aucun commit ou déploiement créé.
