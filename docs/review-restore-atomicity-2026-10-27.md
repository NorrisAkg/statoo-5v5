# Revue F14 — Restauration atomique — 27 octobre 2026

Passage distinct effectué après les vérifications : 995 tests Flutter réussis
(3 min 08 s), analyse ciblée des huit fichiers sans diagnostic, diff sans erreur
d'espacement. Revue locale par l'agent principal, sans second relecteur indépendant.

## Périmètre examiné

- `backup_service.dart` : seuls les ajouts F14, en préservant les corrections F07
  de version et F13 de snapshot déjà présentes dans le diff non commité.
- `restored_settings.dart`, `group_settings_repository.dart`, `team_repository.dart`.
- Quatorze nouveaux tests de restauration, adaptations des trois tests historiques,
  lecteurs des providers et points de rechargement après restauration.

## Constats

- Les écritures des données et des réglages restaurés passent toutes par `txn`.
  Aucune écriture SharedPreferences n'est effectuée par la restauration complète.
  L'injection d'une exception après callback annule le remplacement SQL sans changer
  les préférences ; l'état `meta` initial, y compris le schéma, est préservé.
- Le groupe actif importé est conservé seulement s'il appartient aux groupes
  restaurés. Sinon le premier groupe est choisi. Une sauvegarde vide ne permet plus
  le retour implicite aux anciens nom/identifiant des préférences.
- Le minimum par groupe garde la priorité. Le minimum global restauré est utilisé
  avant les anciennes préférences ; l'absence d'un minimum dans le fichier conserve
  le repli global précédent. L'export reprend la valeur SQL dans le champ JSON existant.
- Le marqueur local est exclu de l'export, remplacé par la valeur interne lors de
  l'import, et n'est pas importé en fusion. Il ne bloque pas une création explicite.
- Les vérifications de version, de confirmation des groupes et les restrictions de
  fusion finances/partage restent en place. Aucune permission ou route n'est modifiée.
- Les tests historiques vérifient désormais les lecteurs réellement utilisés plutôt
  qu'une écriture dans un magasin qui ne porte plus les réglages restaurés.
- Aucun défaut bloquant identifié dans le périmètre. Pas de commit effectué.

## Preuves

- `restore-atomicity-red-2026-10-27.txt` : 7 RED comportementaux, 5 succès.
- `restore-atomicity-green-2026-10-27.txt` : 157 tests ciblés avant les deux compléments.
- `restore-atomicity-persistence-2026-10-27.txt` : 14 scénarios, dont réouverture réelle du fichier SQLite.
- `restore-atomicity-analyze-2026-10-27.txt` : aucun diagnostic.
- `restore-atomicity-regression-2026-10-27.txt` : 995 tests réussis.

## Limites

Aucune coupure physique ni fermeture forcée de navigateur/appareil effectuée. Les
pannes sont injectées avant commit sur SQLite FFI, puis la persistance est vérifiée
par fermeture/réouverture. Le stockage SQLite web et les garanties de durabilité du
système restent dépendants de leur plateforme. Aucune nouvelle validation visuelle,
aucun build web ou essai physique dans ce lot. La compatibilité avec une exécution
ultérieure d'un ancien binaire (retour à une version précédente) n'est pas garantie.
Les autres opérations de groupe qui écrivent encore dans les préférences ne sont
pas transformées en transactions multi-magasins par ce correctif.
