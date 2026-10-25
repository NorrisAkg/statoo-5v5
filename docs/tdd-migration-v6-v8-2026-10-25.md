# Migration SQLite v6 → v8 — scénarios avant code

Périmètre autorisé : corriger F01 de l’audit du 25 octobre, sans changer les règles métier ni réparer silencieusement des données incohérentes. Aucun fichier de base utilisateur n’est ouvert par les tests.

## Scénarios et résultats attendus

| ID | Cas | Résultat attendu |
|---|---|---|
| MIG01 | Base v6 vide, vues historiques présentes | Ouverture réelle en v8, tables/vues utilisables, colonnes de personnalisation ajoutées, FK actives. |
| MIG02 | V6 avec plusieurs groupes, joueurs actifs/archivés, séances classiques/tournois closes et brouillons, participations/statistiques, notes et métadonnées | Toutes les lignes et valeurs conservées exactement ; seules les deux nouvelles colonnes nullables sont ajoutées aux séances. Aucun mélange entre groupes. |
| MIG03 | V6 avec données et vues absentes | Même conservation, notamment des participations : retirer les vues seul ne doit pas masquer une suppression par cascade. |
| MIG04 | Après migration valide | foreign_key_check vide ; refus d’orphelins et de participations intergroupes ; suppression joueur référencé refusée ; cascade séance/participations toujours fonctionnelle. |
| MIG05 | V6 avec séance sans groupe, valide sous l’ancienne contrainte nullable, vues absentes | Échec explicite, sans ligne ignorée ; transaction annulée, version 6 et toutes les données originales intactes. Aucun groupe inventé. |
| MIG06 | V6 contenant une participation orpheline, vues absentes | Migration refusée avant validation définitive ; rollback complet des tables et données, version 6 conservée, aucune perte silencieuse. |
| MIG07 | Base historique v7 valide | Migration additive en v8, données inchangées et champs de personnalisation nuls. |
| MIG08 | Seconde ouverture d’une base migrée en v8 | Réouverture réussie, données identiques, aucune colonne/ligne dupliquée ; vues et gardes fonctionnelles. |
| MIG09 | Nouvelle installation | Schéma v8 frais toujours utilisable et FK actives ; aucune dépendance à une ancienne table. |
| MIG10 | V6, 50 joueurs, 500 séances, 5 000 participations | Tous les enregistrements conservés ; intégrité et version correctes. Ce contrôle n’est pas un benchmark téléphone. |
| MIG11 | Complément de revue : v6 orpheline avec ses vues historiques présentes | Refus de migration, version et données v6 intactes ; toutes les définitions de vues historiques restaurées exactement par le rollback. |

Fixtures : instructions de création exactes de `1a3af10` (v6) et `2b67c06` (v7), extraites de l’historique Git, pas d’un schéma actuel rétro-étiqueté. Les ouvertures passent par le vrai `AppDatabase` et le driver sqflite FFI ; chaque ouverture applicative est isolée pour ne pas réutiliser le singleton fermé.

Cycle prévu : tests avant code, RED comportemental sur les vues et/ou la conservation, correction minimale, GREEN puis régression complète. Les incidents de compilation/fixture/environnement ne comptent pas comme RED.

## Résultats

- **RED avant code applicatif : 8 échecs comportementaux / 2 succès** (`migration-v6-v8-red.txt`). Vues référençant une table supprimée ; sans vues, disparition des participations par cascade ; données incohérentes acceptées ou ignorées au lieu d’un rollback. V7 et installation neuve passaient déjà.
- **GREEN ciblé : 10/10** (`migration-v6-v8-green-final.txt`), dont comparaison exhaustive des lignes avant/après, 5 000 participations, deux refus avec rollback, contraintes rétablies et seconde ouverture.
- **Complément de revue MIG11 : 11/11 tests ciblés réussis** (`migration-v6-v8-review-tests.txt`). Le rollback restaure également toutes les définitions de vues historiques. Le code applicatif n’a pas changé ; la suite complète ci-dessous précède ce seul ajout de couverture.
- **Analyse ciblée des deux fichiers Dart : aucune anomalie** (`migration-v6-v8-analysis.txt`).
- **Régression Flutter complète : 835 tests réussis, zéro échec, 2 min 22 s** (`migration-v6-v8-regression.txt`), dont les 825 tests existants et les 10 nouveaux scénarios de migration.

Le premier passage après correction comptait neuf succès : le contrôle d’intégrité levait bien `StateError`, mais le matcher du test n’acceptait que `Exception` (types Dart distincts). Le matcher accepte désormais les deux erreurs attendues pour les refus ; ce problème de test n’est pas une preuve RED additionnelle. Le formatage a réussi puis la télémétrie Dart a échoué sur un cache non inscriptible ; aucune incidence sur les résultats fonctionnels.

## Correction et revue

- Retirer les vues/triggers dépendants avant la reconstruction, dans la transaction.
- Positionner `foreign_keys=OFF` dans `onConfigure`, avant la transaction sqflite, uniquement pour les bases existantes nécessitant la reconstruction de `sessions` (<7).
- Copier les séances avec `INSERT` strict : aucun `OR IGNORE` susceptible de faire disparaître une ligne incompatible avec la nouvelle contrainte.
- Vérifier `foreign_key_check` avant le commit de migration ; lever une erreur pour annuler également le changement de `user_version` en cas d’orphelin.
- Réactiver `foreign_keys=ON` dès `onOpen`, avant de livrer la connexion à l’application. Pas de migration destructive exécutée sur une base utilisateur.

Le contrôle FFI confirme les gardes de groupe et les règles RESTRICT/CASCADE après ouverture. Le diff n’ajoute pas de nouveau chemin d’ouverture réservé aux tests : les isolats exécutent le vrai singleton et ses callbacks. Aucun changement aux écrans, aux règles sportives, aux permissions ou au format de sauvegarde.

Revue du diff et vérification finale : aucune anomalie supplémentaire identifiée ; `git diff --check` réussi. Provenance des deux fixtures revérifiée byte pour byte pour les instructions SQL extraites de Git. Aucun fichier préexistant de l’audit ni des dossiers natifs racine n’a été modifié. La [revue avant commit](review-migration-v6-v8-2026-10-25.md) détaille le complément de couverture et les limites.

Références de vérification : procédure SQLite de [reconstruction de table](https://www.sqlite.org/lang_altertable.html#making_other_kinds_of_table_schema_changes) et [clés étrangères](https://www.sqlite.org/foreignkeys.html), ainsi que `sqflite_common` 2.5.13 local : `onConfigure` avant la transaction, `onUpgrade`/`user_version` dans la même transaction, `onOpen` après validation.

## Portée et limites

Android/iOS physiques et moteur SQLite navigateur restent des validations distinctes ; les tests FFI ne les remplacent pas. Ce lot valide v6→v8, v7→v8, réouverture v8 et création neuve. Les versions antérieures à v6 et les extensions de schéma non gérées par l’application ne sont pas annoncées comme validées. La version de base reste 8 : aucun besoin de transformer une base déjà migrée correctement. Des données déjà perdues par une ancienne migration ne sont pas reconstituées ni inventées.

Les autres constats de l’audit restent ouverts. Le 25 octobre, l’utilisateur a autorisé le commit local après revue favorable. Aucun push ni déploiement autorisé dans ce lot.
