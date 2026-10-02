import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/features/players/data/players_repository.dart';
import 'package:statoo/features/ranking/data/ranking_repository.dart';
import 'package:statoo/features/ranking/domain/mvp_weights.dart';
import 'package:statoo/features/sessions/data/sessions_repository.dart';
import 'package:statoo/features/sessions/domain/participation.dart';
import 'package:statoo/features/sessions/domain/session.dart';
import 'package:statoo/features/stats/data/stats_repository.dart';

/// Two groups, each with one player and one closed ranked session.
/// Nothing owned by group 1 may be readable or writable through group 2.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late AppDatabase appDb;
  late SqlitePlayersRepository players;
  late SqliteSessionsRepository sessions;
  late SqliteRankingRepository ranking;
  late SqliteStatsRepository stats;

  const t1 = 'team_1';
  const t2 = 'team_2';
  const now = '2026-09-01T10:00:00.000Z';

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
    appDb = AppDatabase.forTesting(db);
    await appDb.initSchemaForTest(db);
    players = SqlitePlayersRepository(appDb);
    sessions = SqliteSessionsRepository(appDb);
    ranking = SqliteRankingRepository(appDb);
    stats = SqliteStatsRepository(appDb);

    for (final t in [t1, t2]) {
      await db.insert('teams', {'id': t, 'name': t, 'format': '5v5', 'created_at': now});
      await db.insert('players', {
        'id': 'p_$t',
        'team_id': t,
        'name': 'Player $t',
        'created_at': now,
        'updated_at': now,
      });
      await db.insert('sessions', {
        'id': 's_$t',
        'team_id': t,
        'played_at': '2026-09-10 20:00:00',
        'status': 'CLOSED',
        'is_ranked': 1,
        'score_a': 3,
        'score_b': 1,
        'result': 'A',
      });
      await db.insert('participations', {
        'id': 'pt_$t',
        'session_id': 's_$t',
        'player_id': 'p_$t',
        'team': 'A',
        'goals': 3,
      });
    }
  });

  tearDown(() async {
    await db.close();
  });

  group('reads by id are scoped to the group', () {
    test('session and participants of another group are invisible', () async {
      expect(await sessions.getSession('s_$t1', teamId: t1), isNotNull);
      expect(await sessions.getSession('s_$t1', teamId: t2), isNull);
      expect(await sessions.getSessionParticipants('s_$t1', teamId: t1), hasLength(1));
      expect(await sessions.getSessionParticipants('s_$t1', teamId: t2), isEmpty);
    });

    test('player, stats and history of another group are invisible', () async {
      expect(await players.getPlayer('p_$t1', teamId: t1), isNotNull);
      expect(await players.getPlayer('p_$t1', teamId: t2), isNull);
      expect((await players.getPlayerStats('p_$t1', teamId: t1)).goals, 3);
      expect((await players.getPlayerStats('p_$t1', teamId: t2)).goals, 0);
      expect(await players.getPlayerMatchHistory('p_$t1', teamId: t1), hasLength(1));
      expect(await players.getPlayerMatchHistory('p_$t1', teamId: t2), isEmpty);
    });

    test('rankings and totals only contain the requested group', () async {
      final s1 = await ranking.getStandings(teamId: t1);
      expect(s1.map((e) => e.playerId), ['p_$t1']);
      final scorers = await ranking.getTopScorers(teamId: t2);
      expect(scorers.map((e) => e.playerId), ['p_$t2']);
      final mvp = await ranking.getMvpRanking(month: '2026-09', teamId: t1);
      expect(mvp.map((e) => e.playerId), ['p_$t1']);
      expect((await stats.getGroupTotals(teamId: t1)).totalPlayerGoals, 3);
    });

    test('deletable players list only holds the group players', () async {
      await db.delete('participations');
      expect(await players.getDeletablePlayerIds(teamId: t1), {'p_$t1'});
    });
  });

  group('writes by id are scoped to the group', () {
    test('other group cannot edit, archive or delete a player', () async {
      await players.updatePlayer(id: 'p_$t1', teamId: t2, name: 'Hacked');
      await players.togglePlayerActive(id: 'p_$t1', teamId: t2, isActive: false);
      await players.deletePlayer('p_$t1', teamId: t2);
      final row = (await db.query('players', where: 'id = ?', whereArgs: ['p_$t1'])).single;
      expect(row['name'], 'Player $t1');
      expect(row['is_active'], 1);
      expect(await players.canDeletePlayer('p_$t1', teamId: t2), isFalse);
    });

    test('other group cannot change a session or its participations', () async {
      await sessions.updateSessionScore(sessionId: 's_$t1', teamId: t2, scoreA: 0, scoreB: 9);
      await sessions.updateTournamentWins(
        sessionId: 's_$t1',
        teamId: t2,
        winsA: 9,
        winsB: 0,
        winsC: 0,
      );
      await sessions.updateParticipationStats(
        participationId: 'pt_$t1',
        sessionId: 's_$t1',
        teamId: t2,
        goals: 99,
        assists: 0,
        yellowCards: 0,
        redCards: 0,
      );
      final session = (await db.query('sessions', where: 'id = ?', whereArgs: ['s_$t1'])).single;
      expect(session['score_a'], 3);
      expect(session['score_b'], 1);
      expect(session['wins_a'], isNot(9));
      final part = (await db.query('participations', where: 'id = ?', whereArgs: ['pt_$t1'])).single;
      expect(part['goals'], 3);
    });

    test('saveSession refuses an id owned by another group', () async {
      final session = Session(id: 's_$t1', playedAt: DateTime(2026, 9, 20));
      await expectLater(
        sessions.saveSession(session, const [], teamId: t2),
        throwsA(isA<StateError>()),
      );
      final row = (await db.query('sessions', where: 'id = ?', whereArgs: ['s_$t1'])).single;
      expect(row['team_id'], t1);
    });

    test('a session cannot enrol a player of another group', () async {
      final session = Session(id: 's_new', playedAt: DateTime(2026, 9, 20));
      const foreign = Participation(id: 'pt_x', sessionId: 's_new', playerId: 'p_$t1', team: Team.a);
      await expectLater(
        sessions.saveSession(session, const [foreign], teamId: t2),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        sessions.addParticipations(
          sessionId: 's_$t2',
          teamId: t2,
          participations: const [
            Participation(id: 'pt_y', sessionId: 's_$t2', playerId: 'p_$t1', team: Team.b),
          ],
        ),
        throwsA(isA<StateError>()),
      );
      expect(await db.query('participations', where: 'player_id = ?', whereArgs: ['p_$t1']), hasLength(1));
    });

    test('addParticipations refuses a session of another group', () async {
      await expectLater(
        sessions.addParticipations(
          sessionId: 's_$t1',
          teamId: t2,
          participations: const [
            Participation(id: 'pt_z', sessionId: 's_$t1', playerId: 'p_$t2', team: Team.b),
          ],
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('database-level guard', () {
    test('trigger rejects a participation across groups even via raw SQL', () async {
      await expectLater(
        db.insert('participations', {
          'id': 'pt_raw',
          'session_id': 's_$t2',
          'player_id': 'p_$t1',
          'team': 'A',
        }),
        throwsA(anything),
      );
      await expectLater(
        db.update('participations', {'player_id': 'p_$t2'}, where: 'id = ?', whereArgs: ['pt_$t1']),
        throwsA(anything),
      );
    });
  });

  group('per-group settings', () {
    test('MVP weights are stored per group', () async {
      await ranking.saveMvpWeights(teamId: t1, weights: const MvpWeights(win: 20));
      expect((await ranking.getMvpWeights(teamId: t1)).win, 20);
      expect((await ranking.getMvpWeights(teamId: t2)).win, 10);
    });
  });
}
