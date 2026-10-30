# Revue distincte après implémentation — F05

## Périmètre et points relus

`SharedService.synchronize`, reconstruction de `syncWarning`, protection des
imports sport/finance et de l'état actif, interaction avec l'enqueue existant,
clé d'idempotence API et sauvegarde des métadonnées. Les lots F02/F03/F04 locaux
ne sont pas regroupés ni committés avec ce lot.

- Le refus permanent d'une opération produit un état `rejected` avec code/message
  conservés. Son payload, identifiant, génération et révision de base ne sont pas
  réécrits. Les autres documents continuent ; une opération du même document
  attend la passe suivante. L'ancien événement n'est pas supprimé à la correction.
- Un timeout, 401/429/5xx, réseau ou réponse illisible garde l'état `pending`,
  arrête la passe et expose l'erreur. La reprise exclut `error/error_status` du
  wire et conserve les champs déjà tentés, ce que vérifie la comparaison exacte
  de deux requêtes successives. Le retry automatique reste au rythme existant.
- La reconstruction d'avertissement ne prend pas une correction encore en attente
  pour un acquittement. Une acceptation/candidature publiée plus récente retire
  l'erreur précédente de ce document ; le mécanisme d'arbitrage reste distinct.
- L'import considère la dernière opération par auteur/document, dans l'ordre de
  la file. Un refus ne provoque pas la perte du brouillon local ; après correction
  acquittée, il ne bloque pas indéfiniment l'import. L'acquittement d'un autre
  auteur ne supprime pas la protection d'un brouillon refusé.
- Les marqueurs d'état actif sont également protégés par les documents sportifs
  non publiés. Le cas `active_session_conflict` garde `blocked`, son comportement
  de cycle de vie et les tests existants.
- Le filtre groupe/auteur et les gardes de génération F04 restent actifs. Une
  déconnexion invalide les réponses anciennes sans réenregistrer de secrets.
- Le stockage des erreurs reste dans `meta`, inclus dans la restauration complète
  existante ; aucun changement de version SQL ni du contrat HTTP n'est requis.

## Conclusion et limites

Aucun défaut bloquant identifié dans le diff du périmètre après les vérifications
ciblées. Les 17 nouveaux tests couvrent refus, reprise, données sport/finance,
protection par auteur, redémarrage et notification ; 23 tests existants ciblés
couvrent également le service, le démarrage concurrent et la déconnexion.

La classification des refus est explicite ; un droit rétabli après un 403 ne
relance pas l'ancien événement sans nouvelle édition. Les dépendances entre des
documents distincts restent contrôlées par le serveur. Les avertissements sont
exposés dans l'écran existant du groupe, sans nouvelle notification système.
Aucun contrôle manuel d'interface, téléphone ou serveur PostgreSQL n'est revendiqué.
Les résultats globaux définitifs sont consignés dans le document TDD associé.

## Clôture après régressions

881 tests Flutter complets passent en 2 min 03 ; les 40 tests ciblés passent aussi.
Relecture du diff final après ces résultats, sans changement applicatif pendant
la régression. L'analyse ciblée ne remonte que les trois informations préexistantes
sur les imports. `git diff --check` passe. Aucun défaut bloquant restant identifié
dans le périmètre. Aucun commit ni push effectué.
