# F07 — Refuser les versions de sauvegarde inconnues avant mutation

## Scénarios définis avant code applicatif

Versions prises en charge : 1 (historique) et 2 (export actuel). Un champ version
absent reste interprété comme v1. Une version explicitement présente doit être
un entier dans cet intervalle : null, booléen, chaîne ou flottant ne doivent plus
être silencieusement assimilés à v1. Aucune modification d'écran ou de format.

- VER01 : le parseur refuse 3/999 avec FormatException et indication de version
  plus récente ; refuse aussi 0/-1 et les types explicites non entiers.
- VER02 : une version future est refusée avant l'interprétation des équipes,
  même si leur structure est inconnue ; pas de TypeError de conversion de format.
- VER03 : v1 et v2 restent lisibles ; un fichier historique sans version reste v1.
- VER04 : un objet BackupPayload construit directement avec une version inconnue
  est refusé par restoreBackup, en remplacement et en fusion, avant ouverture de
  la base et avant vérification des confirmations/traitement du contenu.
- VER05 : après refus, les cinq tables équipes/joueurs/séances/participations/meta
  et toutes les préférences restent identiques. Inclure plusieurs groupes, une
  séance et sa participation, une outbox et un marqueur partagé dans les données
  locales ; la sauvegarde entrante contient des données et préférences différentes.
- VER06 : les restaurations v1/v2 valides restent possibles en remplacement et en
  fusion ; leurs effets attendus sont exécutés, pas seulement le parsing.
- VER07 : toJson ne transforme pas silencieusement un objet de version inconnue
  en sauvegarde v2 ; refus explicite. Les objets valides v1/v2 s'exportent encore
  au format actuel v2 selon le comportement existant.
- VER08 : createBackupPayload + toJson + fromJson produit une sauvegarde v2
  lisible avec les groupes et données locales conservés.
- VER09 (complément de revue, avant test/correction) : une version future dont
  le champ app a aussi une forme inconnue est refusée pour sa version avant tout
  cast du reste du document ; aucune TypeError provenant de ce format inconnu.

## Périmètre et limites

La garde de version est commune au client Flutter mobile/web, dans le parseur,
la restauration et la sérialisation. Pas de migration, suppression ni réparation
historique. Ce lot ne prétend pas valider intégralement tous les champs internes
d'une sauvegarde connue. Le sélecteur de fichiers et les confirmations existantes
ne sont pas modifiés ; aucune recette visuelle ni appareil physique revendiquée.

## Résultats

- RED initial : **24 échecs comportementaux et 10 succès** ; parseur,
  sérialisation et restaurations acceptaient les versions inconnues.
  `backup-versions-red-2026-10-26.txt`.
- Complément de revue VER09 : TypeError au lieu du refus de version attendu,
  `backup-versions-review-red-2026-10-26.txt`. Cas de format futur, pas un échec
  de compilation ou d'environnement.
- GREEN ciblé final : **65 tests réussis en 2 s**, dont 35 nouveaux cas et 30
  régressions existantes de sauvegarde/restauration/tournoi.
  `backup-versions-green-2026-10-26.txt`.
- Analyse ciblée des deux sources et du nouveau test : **aucun diagnostic**,
  `backup-versions-analyze-2026-10-26.txt`.
- Régression Flutter complète : **916 tests réussis en 2 min 11**, code figé ;
  `backup-versions-regression-2026-10-26.txt`.
- Revue distincte : `review-backup-versions-2026-10-26.md`, point VER09 corrigé
  en TDD et vérifié ; aucun blocage restant identifié dans le périmètre.

Les tests utilisent des données synthétiques et SQLite en mémoire avec FK actives.
Aucune donnée utilisateur ni base de production n'est restaurée pendant ces tests.
