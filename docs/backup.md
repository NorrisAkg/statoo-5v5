# Sauvegarde et restauration

Contrat observé au 12 octobre 2026 dans `lib/features/settings/domain/backup_payload.dart` et `lib/features/settings/data/backup_service.dart`.

## Export et format

Export manuel de tous les groupes, joueurs, séances, participations et meta en JSON temporaire, puis partage natif. Aucun backup automatique après clôture ni client Supabase branché. Le retour du partage ne prouve pas que l'utilisateur a conservé le fichier.

| Champ | Contenu |
|---|---|
| app | statoo_5v5 |
| version | 2 à l'export |
| exported_at | Date ISO |
| team | Premier groupe, ancienne forme |
| teams | Tous les groupes |
| players / sessions / participations | Lignes SQLite |
| meta | Clés/valeurs, dont réglages par groupe |
| settings | Ancien min_players_per_session global si présent |

Les images ne sont pas embarquées, seulement avatar_url. Toutes les SharedPreferences ne sont pas exportées. Les lectures ne forment pas un snapshot transactionnel unique.

## Validation et remplacement

Le parseur refuse JSON vide, application différente si app est présent et absence de groupe valide. Il accepte team historique et teams. Il ne valide pas intégralement les lignes ni une version maximale ; une version future n'est pas explicitement refusée.

Le remplacement supprime enfants puis parents et réinsère parents puis enfants dans une transaction SQLite. Les team_id absents/inconnus sont remappés vers le premier groupe importé. Les écritures SharedPreferences ne participent pas à l'atomicité SQL.

La normalisation remet une séance CLOSED en DRAFT si score_a, score_b ou result manque. **Limite confirmée par lecture : cela touche aussi les tournois, dont les scores classiques sont normalement absents.**

## Fusion

targetTeamId est utilisé si valide ; sinon le premier groupe local. L'écran réglages ne transmet pas ce paramètre. Les joueurs sont rapprochés par nom trimé/minuscule ; les collisions d'identifiant joueur sont remappées. Une séance d'identifiant déjà connu ou date exacte déjà présente dans le groupe cible est ignorée.

Les joueurs/séances de tous les groupes importés sont remappés vers le groupe cible : la fusion ne préserve pas nécessairement leur séparation. Elle ne restaure pas meta/réglages comme le remplacement.

Sources : `lib/features/settings/data/backup_service.dart`, `lib/features/settings/presentation/settings_screen.dart`, `lib/features/team/presentation/create_team_screen.dart`.

## Vérification

Avant remplacement réel, conserver une copie externe des données locales et du fichier importé. Après restauration, comparer groupes, joueurs, séances, statuts de tournoi, classements et participations. Les tests couvrent remplacement multi-groupes, remappage depuis un autre appareil et export complet ; ils ne prouvent pas toute compatibilité historique ni le partage sur appareil.

Sources : `test/features/settings/backup_payload_test.dart`, `test/features/settings/backup_service_test.dart`. Aucun import de données utilisateur exécuté pendant l'onboarding.
