import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/features/ranking/data/ranking_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late SqliteRankingRepository ranking;
  const now = '2026-09-01T10:00:00.000Z';

  Future<void> addPlayer(String id, {int active = 1}) => db.insert('players', {
        'id': id,
        'team_id': 't',
        'name': id,
        'is_active': active,
        'created_at': now,
        'updated_at': now,
      });

  Future<void> addSession(String id, String result, {int? drawPoints}) async {
    await db.insert('sessions', {
      'id': id,
      'team_id': 't',
      'played_at': '2026-09-10 20:00:00',
      'status': 'CLOSED',
      'is_ranked': 1,
      'score_a': 1,
      'score_b': 1,
      'result': result,
      'draw_points': ?drawPoints,
    });
  }

  Future<void> play(String session, String player, String team) => db.insert('participations', {
        'id': 'pt_${session}_$player',
        'session_id': session,
        'player_id': player,
        'team': team,
      });

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
    ranking = SqliteRankingRepository(appDb);
    await db.insert('teams', {'id': 't', 'name': 't', 'format': '5v5', 'created_at': now});
  });

  tearDown(() async {
    await db.close();
  });

  test('archived players are excluded from the points per match standings', () async {
    await addPlayer('active');
    await addPlayer('archived', active: 0);
    await addSession('s1', 'A');
    await play('s1', 'active', 'A');
    await play('s1', 'archived', 'A');

    final entries = await ranking.getStandingsPerMatch(teamId: 't');
    expect(entries.map((e) => e.playerId), ['active']);
    // The session total used for the eligibility threshold is unaffected.
    expect(entries.single.totalSessions, 1);
  });

  test('a two-team draw is worth 1 point whatever the tournament draw setting', () async {
    await addPlayer('p');
    await addSession('s1', 'DRAW', drawPoints: 2);
    await play('s1', 'p', 'A');

    final entries = await ranking.getStandingsPerMatch(teamId: 't');
    expect(entries.single.points, 1);
    expect(entries.single.pointsPerMatch, 1.0);
  });

  test('a three-team draw uses the session draw points', () async {
    await addPlayer('p');
    await addSession('s1', 'DRAW_AB', drawPoints: 2);
    await play('s1', 'p', 'A');

    final entries = await ranking.getStandingsPerMatch(teamId: 't');
    expect(entries.single.points, 2);
  });
}
