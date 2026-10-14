import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/features/sessions/data/sessions_repository.dart';
import 'package:statoo/features/sessions/domain/goal_score_sync.dart';
import 'package:statoo/features/sessions/domain/participation.dart';

void main() {
  group('scoreIncreaseForAttributedGoals', () {
    int inc(int score, int assigned, int unassigned, int added) => scoreIncreaseForAttributedGoals(
          score: score,
          assignedGoals: assigned,
          unassignedGoals: unassigned,
          added: added,
        );

    test('a goal already in the score is not counted twice', () => expect(inc(1, 0, 0, 1), 0));
    test('a scorer entered alone raises the score', () => expect(inc(0, 0, 0, 1), 1));
    test('only the surplus beyond free goals is added', () => expect(inc(2, 1, 0, 3), 2));
    test('unassigned goals are not free goals', () => expect(inc(2, 0, 2, 1), 1));
    test('removing or moving a goal never lowers the score', () {
      expect(inc(3, 3, 0, -1), 0);
      expect(inc(3, 3, 0, 0), 0);
    });
    test('free goals never go below zero when data is inconsistent', () {
      expect(freeGoals(score: 1, assignedGoals: 3, unassignedGoals: 0), 0);
    });
  });

  group('score stays in sync with scorers (SQLite)', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    late Database db;
    late SqliteSessionsRepository repo;
    const t = 'team_1';
    const now = '2026-09-01T10:00:00.000Z';

    Future<void> seedSession(String type) async {
      final classic = type == 'CLASSIC_2';
      await db.insert('sessions', {
        'id': 's1',
        'team_id': t,
        'played_at': '2026-09-10 20:00:00',
        'status': 'DRAFT',
        'session_type': type,
        'score_a': classic ? 0 : null,
        'score_b': classic ? 0 : null,
        'result': classic ? 'DRAW' : null,
      });
      for (final p in ['p1', 'p2']) {
        await db.insert('participations', {'id': 'pt_$p', 'session_id': 's1', 'player_id': p, 'team': 'A'});
      }
      await db.insert('participations', {'id': 'pt_p3', 'session_id': 's1', 'player_id': 'p3', 'team': 'B'});
    }

    Future<void> goals(String player, int n) => repo.updateParticipationStats(
          participationId: 'pt_$player',
          sessionId: 's1',
          teamId: t,
          goals: n,
          assists: 0,
          yellowCards: 0,
          redCards: 0,
        );

    Future<Map<String, Object?>> session() async =>
        (await db.query('sessions', where: 'id = ?', whereArgs: ['s1'])).single;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON;');
          },
        ),
      );
      final appDb = AppDatabase.forTesting(db);
      await appDb.initSchemaForTest(db);
      repo = SqliteSessionsRepository(appDb);
      await db.insert('teams', {'id': t, 'name': t, 'format': '5v5', 'created_at': now});
      for (final p in ['p1', 'p2', 'p3']) {
        await db.insert('players', {
          'id': p,
          'team_id': t,
          'name': p,
          'created_at': now,
          'updated_at': now,
        });
      }
    });

    tearDown(() async {
      await db.close();
    });

    test('team goal first, scorer second: the score stays at 1', () async {
      await seedSession('CLASSIC_2');
      await repo.incrementScore(sessionId: 's1', teamId: t, team: Team.a, delta: 1);
      await goals('p1', 1);
      expect((await session())['score_a'], 1);
    });

    test('scorer entered alone raises the score and the result', () async {
      await seedSession('CLASSIC_2');
      await goals('p1', 1);
      final s = await session();
      expect(s['score_a'], 1);
      expect(s['result'], 'A');
    });

    test('changing the scorer or removing a goal keeps the score', () async {
      await seedSession('CLASSIC_2');
      await goals('p1', 1);
      await goals('p1', 0);
      expect((await session())['score_a'], 1);
      await goals('p2', 1);
      expect((await session())['score_a'], 1);
    });

    test('a second scorer consumes the remaining free goal only', () async {
      await seedSession('CLASSIC_2');
      await repo.incrementScore(sessionId: 's1', teamId: t, team: Team.a, delta: 2);
      await goals('p1', 1);
      await goals('p2', 1);
      expect((await session())['score_a'], 2);
      await goals('p2', 2);
      expect((await session())['score_a'], 3);
    });

    test('an own goal consumes a free goal, otherwise it raises the score', () async {
      await seedSession('CLASSIC_2');
      await repo.incrementScore(sessionId: 's1', teamId: t, team: Team.b, delta: 1);
      await repo.updateUnassignedGoals(sessionId: 's1', teamId: t, unassignedGoalsB: 1);
      expect((await session())['score_b'], 1);
      await repo.updateUnassignedGoals(sessionId: 's1', teamId: t, unassignedGoalsB: 2);
      expect((await session())['score_b'], 2);
      await repo.updateUnassignedGoals(sessionId: 's1', teamId: t, unassignedGoalsB: 0);
      expect((await session())['score_b'], 2);
    });

    test('a three-team session never gets a match score', () async {
      await seedSession('TOURNAMENT_3');
      await goals('p1', 2);
      await repo.updateUnassignedGoals(sessionId: 's1', teamId: t, unassignedGoalsA: 1);
      final s = await session();
      expect(s['score_a'], isNull);
      expect(s['score_b'], isNull);
    });

    test('another group cannot move the score', () async {
      await seedSession('CLASSIC_2');
      await repo.updateParticipationStats(
        participationId: 'pt_p1',
        sessionId: 's1',
        teamId: 'other_team',
        goals: 5,
        assists: 0,
        yellowCards: 0,
        redCards: 0,
      );
      expect((await session())['score_a'], 0);
      expect((await db.query('participations', where: 'id = ?', whereArgs: ['pt_p1'])).single['goals'], 0);
    });
  });
}
