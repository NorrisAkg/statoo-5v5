# Revue après implémentation — F02

## Périmètre relu

`SharedService.importSnapshot`, le dépôt SQLite des membres, le chemin de
publication manuelle Flutter, le contrat `PUT /groups/{group_id}/members`, les
formats d'activité du client web et les nouveaux tests MEM01–MEM11.

## Contrôles

- La référence distante est lue avant son remplacement, dans la transaction
  d'import. Elle contient les données du serveur, jamais la fusion locale.
- Chaque champ divergent localement est conservé indépendamment des autres.
  Les autres champs et membres continuent de recevoir les modifications distantes.
- Une valeur distante qui rejoint la valeur locale libère naturellement le champ
  lors des imports suivants. Aucun indicateur mémoire ou migration n'est requis.
- Le garde-fou des identifiants appartenant à un autre groupe et le rollback
  transactionnel sont conservés. Les nouveaux membres locaux ne sont pas supprimés.
- Le contrat de publication, les contrôles de droits et le mécanisme d'outbox
  sport/finance ne sont pas modifiés.

## Point découvert et corrigé pendant la revue

Le contrat web accepte `is_active` booléen, tandis que SQLite exige un entier.
MEM11 a été écrit avant la correction : l'import réel échouait sur `true` avec
`Invalid sql argument type 'bool'`. La normalisation 0/1 s'applique désormais à
l'import et à la référence utilisée pour la comparaison. MEM09 et MEM10
complètent aussi la couverture des avatars et des valeurs optionnelles.

## Conclusion et limites

Aucun défaut bloquant identifié dans le diff final. Ce correctif protège les
modifications de fiches avant publication ; il ne garantit pas une publication
sans conflit entre plusieurs appareils. Le serveur remplace toujours l'effectif
sans révision conditionnelle. La suppression locale d'un membre déjà publié
reste hors périmètre ; le serveur demande de l'archiver. Aucune validation
visuelle, navigateur ou téléphone n'est revendiquée pour ce changement de données.

Les résultats exécutés sont consignés dans le document TDD associé et ses logs.
La validation finale figée compte 847 tests Flutter réussis ; les 16 tests ciblés
du service passent aussi. L'analyse ciblée ne remonte que trois informations
préexistantes sur l'ordre des imports. `git diff --check` passe.
