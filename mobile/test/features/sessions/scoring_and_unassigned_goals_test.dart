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

  group('Scoring and Unassigned Goals (CSC) Integration Tests', () {
    late Database db;
    late AppDatabase appDb;
    late SqliteSessionsRepository repo;
    const teamId = 'team_test_1';
    const sessionId = 'session_test_1';
    const playerIdA = 'player_a_1';
    const partIdA = 'part_a_1';

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
        'name': 'FC Test',
        'created_at': DateTime.now().toIso8601String(),
      });

      await db.insert('players', {
        'id': playerIdA,
        'team_id': teamId,
        'name': 'Joueur A',
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

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
        'unassigned_goals_a': 0,
        'unassigned_goals_b': 0,
      });

      await db.insert('participations', {
        'id': partIdA,
        'session_id': sessionId,
        'player_id': playerIdA,
        'team': 'A',
        'goals': 0,
        'assists': 0,
        'yellow_cards': 0,
        'red_cards': 0,
      });
    });

    tearDown(() async {
      await db.close();
    });

    test('incrementScore updates team scores atomically and recalculates match result', () async {
      // Team A scores -> 1-0 (A)
      await repo.incrementScore(sessionId: sessionId, teamId: teamId, team: Team.a, delta: 1);
      var session = await repo.getSession(sessionId, teamId: teamId);
      expect(session?.scoreA, 1);
      expect(session?.scoreB, 0);
      expect(session?.result, MatchResult.teamA);

      // Team B scores twice -> 1-2 (B)
      await repo.incrementScore(sessionId: sessionId, teamId: teamId, team: Team.b, delta: 2);
      session = await repo.getSession(sessionId, teamId: teamId);
      expect(session?.scoreA, 1);
      expect(session?.scoreB, 2);
      expect(session?.result, MatchResult.teamB);

      // Team B goal cancelled -> 1-1 (DRAW)
      await repo.incrementScore(sessionId: sessionId, teamId: teamId, team: Team.b, delta: -1);
      session = await repo.getSession(sessionId, teamId: teamId);
      expect(session?.scoreA, 1);
      expect(session?.scoreB, 1);
      expect(session?.result, MatchResult.draw);

      // Negative clamping check: decrementing Team A by 5 keeps score clamped to 0
      await repo.incrementScore(sessionId: sessionId, teamId: teamId, team: Team.a, delta: -5);
      session = await repo.getSession(sessionId, teamId: teamId);
      expect(session?.scoreA, 0);
      expect(session?.scoreB, 1);
      expect(session?.result, MatchResult.teamB);
    });

    test('updateUnassignedGoals records own goals / unassigned goals correctly', () async {
      await repo.updateUnassignedGoals(
        sessionId: sessionId,
        teamId: teamId,
        unassignedGoalsA: 2,
        unassignedGoalsB: 1,
      );

      final session = await repo.getSession(sessionId, teamId: teamId);
      expect(session?.unassignedGoalsA, 2);
      expect(session?.unassignedGoalsB, 1);
    });

    test('SessionsController updates player stats and synchronizes team score', () async {
      final container = ProviderContainer(
        overrides: [
          sessionsRepositoryProvider.overrideWithValue(repo),
          activeTeamIdProvider.overrideWith(() => ActiveTeamIdNotifier(initialValue: teamId)),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(sessionsControllerProvider);

      // Player A scores 2 goals with adjustScore = true
      await controller.updateParticipationStats(
        sessionId: sessionId,
        participationId: partIdA,
        goals: 2,
        assists: 1,
        yellowCards: 0,
        redCards: 0,
      );

      final session = await repo.getSession(sessionId, teamId: teamId);
      expect(session?.scoreA, 2);
      expect(session?.scoreB, 0);
      expect(session?.result, MatchResult.teamA);

      final participants = await repo.getSessionParticipants(sessionId, teamId: teamId);
      final pA = participants.firstWhere((p) => p.participation.id == partIdA);
      expect(pA.participation.goals, 2);
      expect(pA.participation.assists, 1);
    });

    test('SessionsController updates unassigned goals and synchronizes team score', () async {
      final container = ProviderContainer(
        overrides: [
          sessionsRepositoryProvider.overrideWithValue(repo),
          activeTeamIdProvider.overrideWith(() => ActiveTeamIdNotifier(initialValue: teamId)),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(sessionsControllerProvider);

      // An own goal occurred benefiting Team B (+1)
      await controller.updateUnassignedGoals(
        sessionId: sessionId,
        unassignedGoalsB: 1,
      );

      final session = await repo.getSession(sessionId, teamId: teamId);
      expect(session?.unassignedGoalsB, 1);
      expect(session?.scoreB, 1);
      expect(session?.scoreA, 0);
      expect(session?.result, MatchResult.teamB);
    });
  });
}
