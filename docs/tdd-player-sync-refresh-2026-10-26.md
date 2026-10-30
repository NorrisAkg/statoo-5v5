# F12 — Fraîcheur des fiches joueur après synchronisation

## Scénarios définis avant code applicatif

Réserve de la section 5 de l'audit du 25 octobre, pas encore reproduite lors de
cet audit. Périmètre : données joueur déjà observées lors de l'import d'un snapshot
partagé, dans le callback de l'application commune web/mobile.

- REF01 : fiche ouverte avec zéro séance, import d'une séance close → statistiques
  individuelles actualisées sans fermer la fiche (match, buts, passe, points).
- REF02 : historique observé, import puis correction de score/buts → historique
  actualisé pour la même séance, sans doublon.
- REF03 : joueur initialement supprimable puis première participation importée →
  canDeletePlayer et ensemble des joueurs supprimables actualisés ; le joueur
  sans participation reste supprimable. Les contrôles métier de suppression
  restent en place, aucune suppression effectuée par la notification.
- REF04 : séance close devenue annulée → l'import existant retire la séance
  locale et ses participations ; stats et historique ne la comptent plus et le
  joueur redevient supprimable s'il n'a aucune autre participation. Cette règle
  d'import n'est pas changée par le lot.
- REF05 : import identique répété → mêmes chiffres, pas de doublons ni mutation
  supplémentaire des joueurs/séances/participations par les rafraîchissements.
- REF06 : import invalide et transaction annulée → données précédentes conservées,
  aucune valeur partielle exposée.
- REF07 : synchronisation d'un autre groupe → statistiques du groupe actif
  inchangées ; une fiche d'un joueur étranger reste vide et non supprimable.
- REF08 : changement de groupe après notification → les observations utilisent
  le nouveau groupe ; pas de fuite entre les groupes.

Les tests montent MyApp pour installer le vrai callback, utilisent SharedService
et importSnapshot réels avec SQLite temporaire, gardent les providers de fiche
écoutés (sinon autoDispose masquerait le défaut), puis vérifient leurs résultats.
Aucun écran ou calcul SQL modifié. Revue distincte après vérifications.

## Résultats

- RED : **6 échecs comportementaux, 3 réussites** ; anciennes statistiques,
  ancien historique et gardes de suppression périmées malgré l'import.
  [Preuve RED](player-sync-refresh-red-2026-10-26.txt).
- GREEN : **9 tests réussis**, après les quatre invalidations ajoutées au callback.
  [Preuve GREEN](player-sync-refresh-green-2026-10-26.txt).
- Analyse : aucun diagnostic dans les nouveaux tests ; deux infos
  cascade_invocations déjà présentes dans MyApp, hors des lignes ajoutées.
  [Sortie](player-sync-refresh-analyze-2026-10-26.txt).
- Régression complète Flutter : **971 tests réussis**, en 2 min 47 s.
  [Preuve complète](player-sync-refresh-regression-2026-10-26.txt).
- Contrôle final git diff --check réussi.
- [Revue distincte](review-player-sync-refresh-2026-10-26.md) : aucun défaut bloquant.

La mise au point des fixtures a nécessité d'attendre les frames et SQLite hors
de l'horloge simulée et d'éliminer un timer résiduel ; ces erreurs d'environnement
de test ne sont pas comptées comme preuve RED. Aucun code applicatif n'a été
ajouté pour les contourner.

Pas de simulation de deux appareils physiques, de transport HTTP, ni de recette
visuelle pour ce périmètre. Modifications non commitées.
