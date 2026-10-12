# Données et migrations

État observé au 12 octobre 2026. Source principale : `lib/core/data/app_database.dart`.

## Connexion et tables

SQLite via sqflite, fichier statoo.db, connexion singleton ouverte à la demande. onConfigure active les clés étrangères. Version d'ouverture : **7**. Migrations Dart dans onUpgrade, sans fichiers SQL numérotés. meta.schema_version vaut encore 1 à la création et ne reflète pas la version d'ouverture.

| Table | Données |
|---|---|
| teams | Identifiant, nom, format par défaut, lieu, création |
| players | Groupe, nom, surnom, avatar_url, activité, dates |
| sessions | Groupe, date, DRAFT/CLOSED, composition, CLASSIC_2/TOURNAMENT_3, options, scores/victoires A/B/C, draw_points, résultat, buts non attribués, notes |
| participations | Séance, joueur, camp A/B/C, buts/passes/cartons ; UNIQUE(session_id, player_id) |
| meta | Références actives, réglages par groupe, marqueurs |

Player, Session et Participation utilisent Freezed/JSON. Session ne porte pas directement teamId ; le repository reçoit ce contexte séparément.

Sources : `lib/features/players/domain/player.dart`, `lib/features/sessions/domain/session.dart`, `lib/features/sessions/domain/participation.dart`, `lib/features/sessions/data/sessions_repository.dart`.

## Intégrité

Suppression de séance : CASCADE sur participations. Suppression de joueur référencé : RESTRICT. Liens de groupe : CASCADE. Deux triggers refusent une participation entre joueur et séance de groupes différents. Les accès par identifiant exigent aussi teamId dans les repositories joueurs/séances.

Le schéma ne garantit pas toutes les règles de clôture ni la positivité des compteurs. sessions.team_id est nullable à la création mais NOT NULL dans la reconstruction v7 : les deux chemins diffèrent.

Sources : `lib/core/data/app_database.dart`, `lib/features/players/data/players_repository.dart`, `lib/features/sessions/data/sessions_repository.dart`.

## Vues SQL

| Vue | Rôle |
|---|---|
| v_player_match_results | Points et résultats par participation |
| v_standings | Classement principal |
| v_standings_per_match | Ratio, éligibilité, matchs manquants |
| v_top_scorers | Buts |
| v_top_assists | Passes |
| v_top_cards | Discipline |
| v_group_totals | Totaux et cohérence |

Vues et triggers sont recréés à chaque ouverture. ROW_NUMBER donne des rangs distincts aux ex aequo. Les classements mensuels et le MVP ajoutent leurs requêtes dans ranking_repository.dart.

## Migrations présentes

| Seuil | Transformation |
|---|---|
| < 4 | Ajout éventuel de sessions.team_id et affectation au premier groupe |
| < 5 | Retour en brouillon des séances closes sans score/résultat |
| < 6 | Champs tournoi et participations acceptant C |
| < 7 | Reconstruction des séances pour les résultats tournoi |

Ces branches ne prouvent pas la compatibilité de toutes les versions historiques. Le schéma c359dd3 ne contenait pas teams, consultée par le chemin courant. En v7, reconstruire la table parent sessions et modifier les PRAGMA dans onUpgrade exige une vérification de conservation des participations.

Les tests initSchemaForTest valident une base fraîche, pas onUpgrade. Avant livraison : migrer des copies des schémas distribués, comparer les données, vérifier les clés étrangères et les agrégats. Aucune base utilisateur n'a été migrée pendant l'onboarding.

Sources : `test/features/team/tenant_isolation_test.dart`, `test/features/settings/backup_service_test.dart`, historique Git de `lib/core/data/app_database.dart`.
