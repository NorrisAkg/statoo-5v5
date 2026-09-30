import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/features/ranking/data/ranking_repository.dart';
import 'package:statoo/features/stats/data/stats_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Multi-tenant isolation and archived players in standings (Chantier 4)', () {
    late Database db;
    late AppDatabase appDb;
    late SqliteRankingRepository rankingRepo;
    late SqliteStatsRepository statsRepo;

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 5,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          final tempAppDb = AppDatabase.forTesting(db);
          await tempAppDb.initSchemaForTest(db);
        },
      );

      appDb = AppDatabase.forTesting(db);
      rankingRepo = SqliteRankingRepository(appDb);
      statsRepo = SqliteStatsRepository(appDb);

      // Create 2 teams
      await db.insert('teams', {'id': 'team_A', 'name': 'Team Alpha', 'created_at': DateTime.now().toIso8601String()});
      await db.insert('teams', {'id': 'team_B', 'name': 'Team Beta', 'created_at': DateTime.now().toIso8601String()});

      // Insert players in team_A (one active, one archived)
      await db.insert('players', {
        'id': 'player_a_active',
        'team_id': 'team_A',
        'name': 'Active Alpha',
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      await db.insert('players', {
        'id': 'player_a_archived',
        'team_id': 'team_A',
        'name': 'Archived Legend',
        'is_active': 0, // Archived player
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Insert a player in team_B
      await db.insert('players', {
        'id': 'player_b_active',
        'team_id': 'team_B',
        'name': 'Active Beta',
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Closed session for team_A where Archived Legend scored and won
      await db.insert('sessions', {
        'id': 'sess_a_closed',
        'team_id': 'team_A',
        'played_at': DateTime.now().toIso8601String(),
        'status': 'CLOSED',
        'split_mode': 'RANDOM',
        'allow_uneven_teams': 0,
        'is_ranked': 1,
        'score_a': 3,
        'score_b': 1,
        'result': 'A',
      });

      // A draft session in team_A (should not inflate avg_goals or matches played)
      await db.insert('sessions', {
        'id': 'sess_a_draft',
        'team_id': 'team_A',
        'played_at': DateTime.now().toIso8601String(),
        'status': 'DRAFT',
        'split_mode': 'RANDOM',
        'allow_uneven_teams': 0,
        'is_ranked': 1,
        'score_a': 0,
        'score_b': 0,
        'result': 'DRAW',
      });

      await db.insert('participations', {
        'id': 'part_archived',
        'session_id': 'sess_a_closed',
        'player_id': 'player_a_archived',
        'team': 'A',
        'goals': 2,
        'assists': 1,
      });
      await db.insert('participations', {
        'id': 'part_active',
        'session_id': 'sess_a_closed',
        'player_id': 'player_a_active',
        'team': 'A',
        'goals': 1,
        'assists': 0,
      });
    });

    tearDown(() async {
      await db.close();
    });

    test('v_standings preserves archived players with their historical points and stats', () async {
      final standingsA = await rankingRepo.getStandings(teamId: 'team_A');
      expect(standingsA.length, 2);

      final archivedEntry = standingsA.firstWhere((s) => s.playerId == 'player_a_archived');
      expect(archivedEntry.matchesPlayed, 1);
      expect(archivedEntry.points, 3); // 1 win = 3 pts
      expect(archivedEntry.goals, 2);
      expect(archivedEntry.isActive, isFalse);

      final scorersA = await rankingRepo.getTopScorers(teamId: 'team_A');
      expect(scorersA.first.playerId, 'player_a_archived');
      expect(scorersA.first.goals, 2);
    });

    test('rankingRepo strictly isolates teams and returns empty when teamId is null', () async {
      final standingsNull = await rankingRepo.getStandings();
      expect(standingsNull, isEmpty);

      final standingsB = await rankingRepo.getStandings(teamId: 'team_B');
      expect(standingsB.length, 1);
      expect(standingsB.first.name, 'Active Beta');
      expect(standingsB.any((s) => s.name.contains('Alpha')), isFalse);
    });

    test('statsRepo computes average goals strictly based on closed sessions and not drafts', () async {
      final totals = await statsRepo.getGroupTotals(teamId: 'team_A');
      expect(totals.totalSessions, 1); // 1 closed session, draft excluded
      expect(totals.totalGoals, 4); // score_a (3) + score_b (1)
      expect(totals.avgGoalsPerSession, 4.0); // 4 / 1 = 4.0 (and not 4 / 2 = 2.0)
    });
  });
}
