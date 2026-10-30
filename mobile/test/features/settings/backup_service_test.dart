import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/features/settings/data/backup_service.dart';
import 'package:statoo/features/settings/data/group_settings_repository.dart';
import 'package:statoo/features/settings/domain/backup_payload.dart';
import 'package:statoo/features/team/data/team_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('BackupService SQLite integration tests', () {
    late Database db;
    late AppDatabase appDb;
    late BackupService backupService;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 5,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON;');
          },
        ),
      );
      appDb = AppDatabase.forTesting(db);
      await appDb.initSchemaForTest(db);
      backupService = BackupService(appDb);
    });

    tearDown(() async {
      await db.close();
    });

    test('replace mode restores all tables without foreign key violations', () async {
      // 1. Seed initial data
      await db.insert('teams', {
        'id': 'initial_team',
        'name': 'Initial Team',
        'format': '5v5',
        'created_at': DateTime.now().toIso8601String(),
      });
      await db.insert('players', {
        'id': 'initial_player',
        'name': 'Initial Player',
        'team_id': 'initial_team',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // 2. Prepare payload with 2 teams, sessions, participations
      final payload = BackupPayload(
        version: 2,
        exportedAt: DateTime.now(),
        team: {'id': 'team_a', 'name': 'Team Alpha'},
        teams: [
          {
            'id': 'team_a',
            'name': 'Team Alpha',
            'format': '5v5',
            'created_at': '2026-09-01T10:00:00.000Z',
          },
          {
            'id': 'team_b',
            'name': 'Team Beta',
            'format': '5v5',
            'created_at': '2026-09-02T10:00:00.000Z',
          },
        ],
        players: [
          {
            'id': 'p1',
            'name': 'Player 1',
            'team_id': 'team_a',
            'created_at': '2026-09-01T10:00:00.000Z',
            'updated_at': '2026-09-01T10:00:00.000Z',
          },
          {
            'id': 'p2',
            'name': 'Player 2',
            'team_id': 'team_b',
            'created_at': '2026-09-02T10:00:00.000Z',
            'updated_at': '2026-09-02T10:00:00.000Z',
          },
        ],
        sessions: [
          {
            'id': 's1',
            'team_id': 'team_a',
            'played_at': '2026-09-10T19:00:00.000Z',
            'is_ranked': 1,
            'status': 'CLOSED',
            'score_a': 3,
            'score_b': 2,
            'result': 'A',
            'allow_uneven_teams': 0,
          },
        ],
        participations: [
          {
            'id': 'pt1',
            'session_id': 's1',
            'player_id': 'p1',
            'team': 'a',
            'goals': 2,
            'assists': 1,
            'yellow_cards': 0,
            'red_cards': 0,
          },
        ],
        minPlayersPerSession: 8,
      );

      // 3. Execute replace restore
      final result = await backupService.restoreBackup(payload, merge: false);

      expect(result.isMerge, isFalse);
      expect(result.importedPlayersCount, 2);
      expect(result.importedSessionsCount, 1);
      expect(result.importedParticipationsCount, 1);

      // Verify database contents
      final teams = await db.query('teams');
      expect(teams.length, 2);
      expect(teams.any((t) => t['id'] == 'initial_team'), isFalse);
      expect(teams.any((t) => t['id'] == 'team_a'), isTrue);
      expect(teams.any((t) => t['id'] == 'team_b'), isTrue);

      final players = await db.query('players');
      expect(players.length, 2);

      final sessions = await db.query('sessions');
      expect(sessions.length, 1);
      expect(sessions.first['id'], 's1');

      final participations = await db.query('participations');
      expect(participations.length, 1);

      expect(await SqliteGroupSettingsRepository(AppDatabase.forTesting(db)).getInt('team_a', 'min_players_per_session'), 8);
      expect(await SqliteTeamRepository(AppDatabase.forTesting(db)).getActiveTeamId(), 'team_a');
    });

    test('merge mode from another device remaps sessions and players without foreign key errors (B-02 & Maj. 4)', () async {
      // 1. Initial local team and player
      await db.insert('teams', {
        'id': 'local_team',
        'name': 'Local Squad',
        'format': '5v5',
        'created_at': DateTime.now().toIso8601String(),
      });
      await db.insert('players', {
        'id': 'p_local_1',
        'name': 'Kylian',
        'team_id': 'local_team',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // 2. Foreign backup from another phone with team_foreign_xyz ID
      final foreignPayload = BackupPayload(
        version: 1,
        exportedAt: DateTime.now(),
        team: {'id': 'team_foreign_xyz', 'name': 'Foreign Squad'},
        teams: [
          {
            'id': 'team_foreign_xyz',
            'name': 'Foreign Squad',
            'format': '5v5',
            'created_at': '2026-09-01T10:00:00.000Z',
          },
        ],
        players: [
          // Same name -> should reconcile with local Kylian
          {
            'id': 'p_foreign_1',
            'name': 'Kylian',
            'team_id': 'team_foreign_xyz',
            'created_at': '2026-09-01T10:00:00.000Z',
            'updated_at': '2026-09-01T10:00:00.000Z',
          },
          // New player -> should be imported into local_team
          {
            'id': 'p_foreign_2',
            'name': 'Antoine',
            'team_id': 'team_foreign_xyz',
            'created_at': '2026-09-01T10:00:00.000Z',
            'updated_at': '2026-09-01T10:00:00.000Z',
          },
        ],
        sessions: [
          {
            'id': 's_foreign_1',
            'team_id': 'team_foreign_xyz', // Foreign ID that does not exist in local db!
            'played_at': '2026-09-12T19:00:00.000Z',
            'is_ranked': 1,
            'status': 'CLOSED',
            'score_a': 1,
            'score_b': 0,
            'result': 'A',
            'allow_uneven_teams': 0,
          },
        ],
        participations: [
          {
            'id': 'pt_foreign_1',
            'session_id': 's_foreign_1',
            'player_id': 'p_foreign_1', // Kylian
            'team': 'a',
            'goals': 1,
            'assists': 0,
            'yellow_cards': 0,
            'red_cards': 0,
          },
        ],
      );

      // 3. Execute merge restore targeting local_team
      final result = await backupService.restoreBackup(
        foreignPayload,
        merge: true,
        targetTeamId: 'local_team',
      );

      expect(result.isMerge, isTrue);
      expect(result.reusedPlayersCount, 1); // Kylian reused
      expect(result.importedPlayersCount, 1); // Antoine imported
      expect(result.importedSessionsCount, 1); // Session imported and remapped!

      // 4. Verify that session has been remapped to local_team
      final sessions = await db.query('sessions');
      expect(sessions.length, 1);
      expect(sessions.first['team_id'], 'local_team');

      // 5. Verify that Antoine belongs to local_team
      final antoine = await db.query('players', where: 'name = ?', whereArgs: ['Antoine']);
      expect(antoine.length, 1);
      expect(antoine.first['team_id'], 'local_team');

      // 6. Verify participation maps to local Kylian
      final parts = await db.query('participations');
      expect(parts.length, 1);
      expect(parts.first['player_id'], 'p_local_1');
    });

    test('createBackupPayload exports all teams and full data', () async {
      await db.insert('teams', {
        'id': 't1',
        'name': 'Team 1',
        'format': '5v5',
        'created_at': DateTime.now().toIso8601String(),
      });
      await db.insert('teams', {
        'id': 't2',
        'name': 'Team 2',
        'format': '5v5',
        'created_at': DateTime.now().toIso8601String(),
      });

      final payload = await backupService.createBackupPayload();
      expect(payload.version, 2);
      expect(payload.teams.length, 2);
      expect(payload.team?['id'], 't1');
    });
  });
}
