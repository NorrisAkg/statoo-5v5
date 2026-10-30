# Revue distincte après implémentation — F07

## Périmètre relu

Diff de BackupPayload (lecture/validation/sérialisation) et BackupService
(export/restauration), nouveau module de tests et régressions existantes de
restauration complète, fusion, confirmation et tournois. Aucun écran modifié.

## Constats

- La version présente doit être un entier. L'absence reste v1 ; les versions
  explicites nulles, flottantes, booléennes et chaînes ne deviennent plus v1.
- Les versions prises en charge sont 1 et 2, avec une constante unique pour la
  version actuelle utilisée par l'export et le contrôle supérieur.
- La garde de restauration est le premier traitement du payload : avant les
  restrictions de fusion, les confirmations, l'accès DB, les transactions et les
  préférences. Les objets construits directement ne peuvent pas contourner le parseur.
- Les tests comptent les accès au getter de base (zéro lors d'un refus) et
  comparent le contenu des cinq tables et de toutes les préférences. Le refus ne
  repose pas sur un rollback SQL qui laisserait les préférences déjà modifiées.
- La sérialisation refuse aussi les objets inconnus pour éviter de transformer
  silencieusement une version future en export v2. Les objets connus conservent
  leur export v2 existant ; les restaurations v1/v2 sont réellement exécutées.
- Le même code s'applique aux entrées Flutter mobile/web, sans nouvelle logique
  propre à une plateforme ni nouvelle action dans le parcours utilisateur.

## Point découvert pendant la revue et corrigé en TDD

Le champ app était converti avant la garde de version. VER09, ajouté avant
correction, reproduisait une TypeError si ce marqueur avait une forme inconnue
pour une version future. Le contrôle de version précède désormais ce cast et ceux
des autres champs. Le refus FormatException attendu est vérifié en GREEN.

## Conclusion et limites

Aucun défaut bloquant identifié dans le périmètre après 65 tests ciblés réussis
et une analyse ciblée sans diagnostic. Résultats globaux définitifs dans le suivi
TDD associé. La validation complète de structure/contenu d'un format connu reste
hors de ce lot ; aucune migration ni récupération automatique d'un format futur.

Le sélecteur de fichiers, le rendu des messages et les stockages réels Android,
iOS et navigateur ne sont pas validés par ces tests SQLite en mémoire. Aucun
commit ni push effectué. Les autres lots locaux ne sont pas inclus dans cette revue.

## Clôture après régression complète

916 tests Flutter réussis en 2 min 11, dont les 35 nouveaux cas ; 65 tests ciblés
réussis et analyse ciblée sans diagnostic. Relecture du diff final après ces
résultats, sans modification applicative pendant la régression. Aucun défaut
bloquant restant identifié dans le périmètre. `git diff --check` passe.
