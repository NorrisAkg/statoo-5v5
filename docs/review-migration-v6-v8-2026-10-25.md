# Revue de code — migration v6 → v8

Date : 25 octobre 2026. Revue distincte de l’implémentation, avant commit.

## Périmètre

`mobile/lib/core/data/app_database.dart`, tests de migration, fixtures historiques,
scénarios et preuves d’exécution. Les autres constats de l’audit général et les
dossiers natifs racine sont hors périmètre. La consigne de revue systématique est
consignée séparément dans `AGENTS.md` et `docs/conventions.md`.

## Conclusion

**Aucun défaut bloquant identifié dans le périmètre relu.** Le changement applicatif
reste limité à l’ouverture et à la migration SQLite. Pas de nouvelle API, de
modification d’écran, de permission métier ni de version de schéma ajoutée.

## Points contrôlés

- `onConfigure` positionne les clés étrangères avant la transaction de migration ;
  leur désactivation concerne uniquement les bases existantes antérieures à v7,
  dont la table parent doit être reconstruite.
- Vues et triggers dépendants retirés dans la transaction avant reconstruction ;
  aucune référence à la table momentanément absente pendant le renommage.
- Copie stricte des séances : une ligne incompatible provoque une erreur plutôt
  qu’une disparition silencieuse. Aucun groupe ou timestamp de remplacement inventé.
- Contrôle des références avant le commit et le changement de `user_version` ;
  retour intégral à la base d’origine en cas d’échec.
- Réactivation des clés étrangères avant que l’application obtienne la connexion ;
  règles RESTRICT/CASCADE et garde intergroupes vérifiées après migration.
- Conservation exacte des lignes, identifiants, statistiques, métadonnées et
  périmètres de groupe. Compatibilité v7, création neuve et réouverture v8 testées.
- Fixtures relues et comparées aux instructions SQL exactes des commits
  `1a3af10` et `2b67c06`. Les tests ouvrent le vrai singleton dans des isolats ;
  ils ne remplacent pas les callbacks de production par une simulation.

## Complément de couverture pendant la revue

Les refus avec rollback étaient testés sans vues. Le scénario **MIG11** a été écrit
dans le catalogue avant son test : échec sur une base orpheline possédant ses vues
historiques, puis vérification de leur SQL exact, des données et de la version 6.
Ce test passe sans correction applicative supplémentaire. Il renforce la preuve
de rollback ; ce n’est pas une nouvelle preuve RED.

## Vérifications et portée

- Suite Flutter complète de l’implémentation : **835/835 réussis** en 2 min 22 s,
  [journal](migration-v6-v8-regression.txt). Le code applicatif n’a pas changé depuis.
- Après ajout de MIG11 : **11/11 tests ciblés réussis**,
  [journal de revue](migration-v6-v8-review-tests.txt). La suite complète n’a pas
  été répétée pour ce seul ajout de couverture ; ne pas annoncer 836 tests exécutés.
- Analyse ciblée après le complément : résultat dans
  [migration-v6-v8-review-analysis.txt](migration-v6-v8-review-analysis.txt).
- Formatage du test et `git diff --check` réussis.

Validation effectuée avec sqflite FFI sur des bases temporaires uniquement.
Pas de recette sur Android/iOS physiques ni sur le moteur navigateur dans ce lot.
Les schémas antérieurs à v6 ne sont pas annoncés comme validés. Cette correction
ne restaure pas des données déjà perdues par une ancienne migration.

## Décision de livraison

Commit local autorisé par l’utilisateur sous réserve des contrôles verts, sans
push ni déploiement. Staging limité au correctif, à ses tests et à ses preuves ;
consigne de revue dans un commit documentaire distinct.
