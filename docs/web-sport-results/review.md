# Revue dédiée du parcours sportif — 16 octobre 2026

Relecture en lecture seule du nouvel éditeur sportif à quatre étapes, de sa
persistance, des sélections et restaurations, compteurs, validations, styles et
adaptations de tests. Les changements backend/mobile/client/règles préexistants
étaient hors périmètre de cette revue.

Constats traités :

1. Les points du nul invalides dans une préparation restaurée/existante
   renvoyaient vers Match. SPORT-17 a reproduit le défaut avant correction ;
   le retour vers Options rend le champ fautif visible. Une saisie neuve invalide
   bloquait déjà la sortie d’Options par la validation native.
2. Une panne de stockage lors de la frappe laissait un statut « conservé ».
   SPORT-14 a été étendu et exécuté RED avant la mise à jour ciblée du nœud de
   statut par `save()`. Le rétablissement efface uniquement l’erreur de stockage
   correspondante, sans reconstruire le formulaire ni perdre le focus.
3. Le test de reprise cherchait une alerte visible après son effacement :
   attente adaptée au nœud d’erreur masqué. Le test d’envoi bloqué exerce
   effectivement la confirmation avant de vérifier l’absence de requête.

Le footer a également été relu après correction du mot coupé sur petit écran :
hiérarchie primaire/secondaire et retour à la ligne des boutons cohérents.

Dernier delta SPORT-19 relu et validé : le registre des participations retirées
maintient la ligne d’un joueur devenu archivé pendant une préparation non
publiée. La réintégration explicite conserve les statistiques ; la sélection
collective exclut toujours les archivés. Le test a été écrit et observé RED
avant le correctif, puis GREEN.

Conclusion finale : revue validée, aucun blocage restant identifié dans ce lot.
Les cas issus de la revue sont GREEN et la régression finale contient
89 tests sportifs/PWA réussis, sans échec. Les 62 tests API réussissent également.
Aucun fichier modifié par le relecteur.
