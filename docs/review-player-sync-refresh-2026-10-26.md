# F12 — Revue distincte après implémentation

## Périmètre

Relecture après les 9 tests ciblés GREEN : quatre invalidations dans le callback
SharedService.onChanged de MyApp et tests correspondants. Le diff de main.dart
contient aussi l'initialisation de F11, déjà présente avant ce lot.

## Constats

- Les quatre données effectivement observées par PlayerDetailScreen et
  PlayersScreen sont désormais invalidées : statistiques, historique, garde
  individuelle de suppression et ensemble des joueurs supprimables.
- L'invalidation porte sur les familles complètes : plusieurs fiches observées
  peuvent être actualisées. Les requêtes gardent leur filtre activeTeamId et les
  contraintes de propriété, vérifiés par les scénarios intergroupes.
- importSnapshot appelle onChanged après la réussite de la transaction. Un import
  en erreur reste annulé et ne publie pas d'état partiel aux observateurs.
- Aucun changement SQL, permission ou suppression. Le contrôle métier relit déjà
  la base avant une suppression ; le lot corrige la fraîcheur des commandes et
  données affichées, pas un contournement de cette garde.
- La règle existante d'import d'une annulation retire la séance et ses
  participations locales ; les observateurs reflètent maintenant cette règle.
- Le test monte MyApp pour installer le callback réel, puis importe par le vrai
  SharedService dans SQLite avec clés étrangères activées. Les listeners restent
  ouverts, afin qu'autoDispose ne masque pas un cache périmé. Les seules
  invalidations manuelles de la fixture précèdent l'observation d'une annulation
  et ne participent pas à la correction vérifiée après réception.
- Les attentes asynchrones des fixtures sont bornées ; les blocages/timers de
  mise au point ne constituent pas une preuve RED métier.

Aucun défaut bloquant relevé dans le périmètre.

## Vérifications et limites

- RED : 6 échecs comportementaux, 3 scénarios déjà corrects réussis.
- GREEN ciblé final : 9 tests réussis en 5 secondes.
- Analyse finale : aucun diagnostic nouveau ; deux infos cascade_invocations
  préexistantes dans MyApp (59/61). Trois infos de style des nouveaux tests ont
  été corrigées puis les 9 tests ciblés revérifiés avec succès.
- Suite complète : 971 tests réussis en 2 min 47 s.
- Contrôle final git diff --check réussi.
- Pas de changement de widget ou design. Pas de contrôle visuel, appareil
  physique ou nouveau build navigateur pour ce lot de coordination des providers.
- Le test couvre la réception/import et son callback, pas le transport HTTP ni
  une synchronisation réelle entre deux appareils.
- Aucun commit ou déploiement créé.
