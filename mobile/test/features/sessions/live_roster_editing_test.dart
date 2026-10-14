import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/features/sessions/application/sessions_provider.dart';
import 'package:statoo/features/sessions/data/sessions_repository.dart';
import 'package:statoo/features/sessions/domain/participation.dart';
import 'package:statoo/features/sessions/domain/session.dart';
import 'package:statoo/features/team/application/team_provider.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Live Roster Editing Integration Tests (Chantier 3)', () {
    late Database db;
    late AppDatabase appDb;
    late SqliteSessionsRepository repo;
    const teamId = 'team_test_roster';
    const sessionId = 'session_test_roster';
    const playerA1 = 'player_a1';
    const playerA2 = 'player_a2';
    const playerB1 = 'player_b1';
    const playerB2 = 'player_b2';
    const partA1 = 'part_a1';
    const partA2 = 'part_a2';
    const partB1 = 'part_b1';
    const partB2 = 'part_b2';

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 5,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE teams (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              created_at TEXT NOT NULL
            );
          ''');
          await db.execute('''
            CREATE TABLE players (
              id TEXT PRIMARY KEY,
              team_id TEXT NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
              name TEXT NOT NULL,
              nickname TEXT,
              avatar_url TEXT,
              is_active INTEGER NOT NULL DEFAULT 1,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );
          ''');
          await db.execute('''
            CREATE TABLE sessions (
              id TEXT PRIMARY KEY,
              team_id TEXT NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
              played_at TEXT NOT NULL,
              status TEXT NOT NULL CHECK(status IN ('DRAFT', 'CLOSED')),
              split_mode TEXT NOT NULL,
              allow_uneven_teams INTEGER NOT NULL DEFAULT 0,
              is_ranked INTEGER NOT NULL DEFAULT 0,
              score_a INTEGER,
              score_b INTEGER,
              result TEXT CHECK(result IN ('A', 'B', 'DRAW')),
              unassigned_goals_a INTEGER NOT NULL DEFAULT 0,
              unassigned_goals_b INTEGER NOT NULL DEFAULT 0,
              notes TEXT
            );
          ''');
          await db.execute('''
            CREATE TABLE participations (
              id TEXT PRIMARY KEY,
              session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
              player_id TEXT NOT NULL REFERENCES players(id) ON DELETE RESTRICT,
              team TEXT NOT NULL CHECK(team IN ('A', 'B')),
              goals INTEGER NOT NULL DEFAULT 0,
              assists INTEGER NOT NULL DEFAULT 0,
              yellow_cards INTEGER NOT NULL DEFAULT 0,
              red_cards INTEGER NOT NULL DEFAULT 0
            );
          ''');
          await db.execute('''
            CREATE TABLE meta (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            );
          ''');
        },
      );

      appDb = AppDatabase.forTesting(db);
      repo = SqliteSessionsRepository(appDb);

      await db.insert('teams', {
        'id': teamId,
        'name': 'FC Roster',
        'created_at': DateTime.now().toIso8601String(),
      });

      for (final p in [playerA1, playerA2, playerB1, playerB2]) {
        await db.insert('players', {
          'id': p,
          'team_id': teamId,
          'name': 'Joueur $p',
          'is_active': 1,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      await db.insert('sessions', {
        'id': sessionId,
        'team_id': teamId,
        'played_at': DateTime.now().toIso8601String(),
        'status': 'DRAFT',
        'split_mode': 'RANDOM',
        'allow_uneven_teams': 0,
        'is_ranked': 1,
        'score_a': 0,
        'score_b': 0,
        'result': 'DRAW',
      });

      // 2 players in Team A, 2 players in Team B
      await db.insert('participations', {'id': partA1, 'session_id': sessionId, 'player_id': playerA1, 'team': 'A'});
      await db.insert('participations', {'id': partA2, 'session_id': sessionId, 'player_id': playerA2, 'team': 'A'});
      await db.insert('participations', {'id': partB1, 'session_id': sessionId, 'player_id': playerB1, 'team': 'B'});
      await db.insert('participations', {'id': partB2, 'session_id': sessionId, 'player_id': playerB2, 'team': 'B'});
    });

    tearDown(() async {
      await db.close();
    });

    test('switchPlayerTeam throws StateError if uneven teams diff exceeds 1 and allowUnevenTeams is false', () async {
      final container = ProviderContainer(
        overrides: [
          sessionsRepositoryProvider.overrideWithValue(repo),
          activeTeamIdProvider.overrideWith(() => ActiveTeamIdNotifier(initialValue: teamId)),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(sessionsControllerProvider);

      // Switching player A1 to Team B would result in 1 vs 3 (diff = 2 > 1) -> throws StateError
      expect(
        () => controller.switchPlayerTeam(
          sessionId: sessionId,
          participationId: partA1,
          currentTeam: Team.a,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('switchPlayerTeam succeeds when allowUnevenTeams is enabled', () async {
      // Enable allow_uneven_teams
      await db.update('sessions', {'allow_uneven_teams': 1}, where: 'id = ?', whereArgs: [sessionId]);

      final container = ProviderContainer(
        overrides: [
          sessionsRepositoryProvider.overrideWithValue(repo),
          activeTeamIdProvider.overrideWith(() => ActiveTeamIdNotifier(initialValue: teamId)),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(sessionsControllerProvider);

      await controller.switchPlayerTeam(
        sessionId: sessionId,
        participationId: partA1,
        currentTeam: Team.a,
      );

      final participants = await repo.getSessionParticipants(sessionId, teamId: teamId);
      final pA1 = participants.firstWhere((p) => p.participation.id == partA1);
      expect(pA1.participation.team, Team.b);
    });

    test('removeParticipation removes a player from the sheet and checks uneven teams rule', () async {
      final container = ProviderContainer(
        overrides: [
          sessionsRepositoryProvider.overrideWithValue(repo),
          activeTeamIdProvider.overrideWith(() => ActiveTeamIdNotifier(initialValue: teamId)),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(sessionsControllerProvider);

      // Removing A1 leaves 1 in A and 2 in B (diff = 1 <= 1) -> allowed!
      await controller.removeParticipation(
        sessionId: sessionId,
        participationId: partA1,
        playerTeam: Team.a,
      );

      final participants = await repo.getSessionParticipants(sessionId, teamId: teamId);
      expect(participants.length, 3);
      expect(participants.any((p) => p.participation.id == partA1), isFalse);

      // Removing A2 leaves 0 in A and 2 in B (diff = 2 > 1) -> blocked!
      expect(
        () => controller.removeParticipation(
          sessionId: sessionId,
          participationId: partA2,
          playerTeam: Team.a,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('reopenSession switches closed session back to DRAFT scoped to teamId', () async {
      await db.update('sessions', {'status': 'CLOSED'}, where: 'id = ?', whereArgs: [sessionId]);

      final container = ProviderContainer(
        overrides: [
          sessionsRepositoryProvider.overrideWithValue(repo),
          activeTeamIdProvider.overrideWith(() => ActiveTeamIdNotifier(initialValue: teamId)),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(sessionsControllerProvider);

      await controller.reopenSession(sessionId);

      final session = await repo.getSession(sessionId, teamId: teamId);
      expect(session?.status, SessionStatus.draft);
    });
  });
}
