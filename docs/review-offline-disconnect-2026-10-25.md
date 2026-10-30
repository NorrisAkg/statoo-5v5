# Revue distincte après implémentation — F04

## Périmètre

Relecture du cycle `load`/`connect`/`disconnect`/`synchronize`, de l'ordre des
opérations du stockage sécurisé, de la clé de contexte des accès collectif et
gestionnaires, du transport natif et navigateur et du point d'appel de l'écran.
Le correctif F02 déjà local est conservé ; sa fusion des membres n'est pas refaite.

## Vérifications et constat corrigé

- L'appel de révocation est initié avec le contexte précédent avant neutralisation
  de l'identité. Il n'est pas attendu et ses erreurs sont absorbées. Aucune
  nouvelle copie durable du jeton n'est créée pour une révocation ultérieure.
- Identité, jeton, URL, instantané en mémoire et avertissement sont neutralisés
  avant les attentes de stockage ; le timer est annulé. Les données SQLite et
  les marqueurs de groupe partagé restent conservés.
- Le numéro de génération invalide les réponses de connexion/chargement/sync
  antérieures. Une ancienne réponse ne remplace pas une connexion plus récente.
- Les écritures et la suppression de connexion sont sérialisées. Une écriture
  commencée avant la déconnexion finit avant la suppression ; les écritures
  anciennes encore en attente sont ignorées. Les erreurs restent propagées à
  l'appelant, sans rendre la chaîne de stockage inutilisable pour la suite.
- Les accès collectif/gestionnaires sont supprimés seulement dans le contexte
  déconnecté. Pendant le chargement initial, ce contexte peut être retrouvé dans
  l'enregistrement persistant ; le jeton est supprimé même si son décodage échoue.
- Une transaction d'import déjà engagée peut terminer son travail de cache ; elle
  capture son groupe à l'entrée pour ne pas utiliser le contexte nul ou remplacé.
  La synchronisation ne persiste ensuite aucune ancienne connexion.

La revue a découvert qu'un callback `onChanged` défaillant pouvait interrompre
l'effacement. OUT11 a été décrit et testé avant correction : le test retrouvait
le jeton synthétique en stockage. La notification intervient désormais après la
suppression ; le test passe. OUT12 couvre également une reconnexion avant la
réponse d'une ancienne synchronisation.

## Conclusion et limites

Aucun défaut bloquant identifié dans le périmètre après les contrôles ciblés.
La suite globale finale et les résultats sont consignés dans le suivi TDD.
Une panne réelle du stockage sécurisé reste une erreur visible, et peut laisser
les données dont la suppression a échoué ; le correctif ne prétend pas le contraire.
La révocation distante n'est pas garantie hors ligne. Une requête déjà envoyée
peut encore être traitée par le serveur ; le correctif empêche la restauration
locale de l'identité, sans prétendre annuler une transaction distante engagée.

Aucune recette de trousseau Android/iOS, de stockage sécurisé navigateur réel ou
d'interface n'est revendiquée. Aucun commit ni push effectué.

## Clôture après vérifications

Relecture du diff final après 30 tests ciblés et 864 tests Flutter complets réussis
(2 min 04). Aucun changement applicatif pendant la régression globale. L'analyse
ciblée ne signale que les trois informations d'ordre des imports déjà présentes
avant ce lot. `git diff --check` passe. Aucun défaut bloquant restant dans le
périmètre ; les limites ci-dessus restent explicites.
