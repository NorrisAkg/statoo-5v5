import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/features/ranking/data/ranking_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Monthly Rankings & MVP Repository Tests', () {
    late Database db;
    late AppDatabase appDb;
    late SqliteRankingRepository rankingRepo;

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

      // Create 2 Teams
      await db.insert('teams', {
        'id': 'team_1',
        'name': 'Team Alpha',
        'created_at': '2026-08-01 10:00:00',
      });
      await db.insert('teams', {
        'id': 'team_2',
        'name': 'Team Beta',
        'created_at': '2026-08-01 10:00:00',
      });

      // Insert Players for Team 1
      await db.insert('players', {
        'id': 'p1',
        'team_id': 'team_1',
        'name': 'Lucas',
        'nickname': 'Lulu',
        'is_active': 1,
        'created_at': '2026-08-01 10:00:00',
        'updated_at': '2026-08-01 10:00:00',
      });
      await db.insert('players', {
        'id': 'p2',
        'team_id': 'team_1',
        'name': 'Karim',
        'nickname': 'Kaka',
        'is_active': 1,
        'created_at': '2026-08-01 10:00:00',
        'updated_at': '2026-08-01 10:00:00',
      });
      await db.insert('players', {
        'id': 'p3',
        'team_id': 'team_1',
        'name': 'Sofiane',
        'is_active': 1,
        'created_at': '2026-08-01 10:00:00',
        'updated_at': '2026-08-01 10:00:00',
      });

      // Insert Player for Team 2 (Isolation test)
      await db.insert('players', {
        'id': 'p_beta',
        'team_id': 'team_2',
        'name': 'Beta Star',
        'is_active': 1,
        'created_at': '2026-08-01 10:00:00',
        'updated_at': '2026-08-01 10:00:00',
      });

      // Team 1 Sessions in October 2026 (4 sessions)
      // Session 1: 2026-10-03 -> Team A wins (A=5, B=2)
      await db.insert('sessions', {
        'id': 's_oct_1',
        'team_id': 'team_1',
        'played_at': '2026-10-03 20:00:00',
        'status': 'CLOSED',
        'is_ranked': 1,
        'score_a': 5,
        'score_b': 2,
        'result': 'A',
      });
      // Session 2: 2026-10-10 -> Team A wins (A=4, B=1)
      await db.insert('sessions', {
        'id': 's_oct_2',
        'team_id': 'team_1',
        'played_at': '2026-10-10 20:00:00',
        'status': 'CLOSED',
        'is_ranked': 1,
        'score_a': 4,
        'score_b': 1,
        'result': 'A',
      });
      // Session 3: 2026-10-17 -> DRAW (A=3, B=3)
      await db.insert('sessions', {
        'id': 's_oct_3',
        'team_id': 'team_1',
        'played_at': '2026-10-17 20:00:00',
        'status': 'CLOSED',
        'is_ranked': 1,
        'score_a': 3,
        'score_b': 3,
        'result': 'DRAW',
      });
      // Session 4: 2026-10-24 -> Team B wins (A=2, B=4)
      await db.insert('sessions', {
        'id': 's_oct_4',
        'team_id': 'team_1',
        'played_at': '2026-10-24 20:00:00',
        'status': 'CLOSED',
        'is_ranked': 1,
        'score_a': 2,
        'score_b': 4,
        'result': 'B',
      });

      // Participations for October Sessions
      // Lucas (p1): played all 4
      // S1: Team A (win: 10) + 2 goals (4) + 1 assist (1) = 15.0
      await db.insert('participations', {
        'id': 'part_1',
        'session_id': 's_oct_1',
        'player_id': 'p1',
        'team': 'A',
        'goals': 2,
        'assists': 1,
        'yellow_cards': 0,
        'red_cards': 0,
      });
      // S2: Team A (win: 10) + 1 goal (2) + 2 assists (2) - 1 yellow (0.5) = 13.5
      await db.insert('participations', {
        'id': 'part_2',
        'session_id': 's_oct_2',
        'player_id': 'p1',
        'team': 'A',
        'goals': 1,
        'assists': 2,
        'yellow_cards': 1,
        'red_cards': 0,
      });
      // S3: Team A (draw: 3) + 0 goal + 1 assist (1) = 4.0
      await db.insert('participations', {
        'id': 'part_3',
        'session_id': 's_oct_3',
        'player_id': 'p1',
        'team': 'A',
        'goals': 0,
        'assists': 1,
        'yellow_cards': 0,
        'red_cards': 0,
      });
      // S4: Team A (loss: 0) + 3 goals (6) + 0 assist - 1 red (1.0) = 5.0
      await db.insert('participations', {
        'id': 'part_4',
        'session_id': 's_oct_4',
        'player_id': 'p1',
        'team': 'A',
        'goals': 3,
        'assists': 0,
        'yellow_cards': 0,
        'red_cards': 1,
      });
      // Lucas total: 15.0 + 13.5 + 4.0 + 5.0 = 37.5 / 4 = 9.38

      // Karim (p2): played 3 sessions (missed S4)
      // S1: Team A (win: 10) + 1 goal (2) = 12.0
      await db.insert('participations', {
        'id': 'part_5',
        'session_id': 's_oct_1',
        'player_id': 'p2',
        'team': 'A',
        'goals': 1,
        'assists': 0,
        'yellow_cards': 0,
        'red_cards': 0,
      });
      // S2: Team A (win: 10) + 3 goals (6) + 1 assist (1) = 17.0
      await db.insert('participations', {
        'id': 'part_6',
        'session_id': 's_oct_2',
        'player_id': 'p2',
        'team': 'A',
        'goals': 3,
        'assists': 1,
        'yellow_cards': 0,
        'red_cards': 0,
      });
      // S3: Team A (draw: 3) + 1 goal (2) = 5.0
      await db.insert('participations', {
        'id': 'part_7',
        'session_id': 's_oct_3',
        'player_id': 'p2',
        'team': 'A',
        'goals': 1,
        'assists': 0,
        'yellow_cards': 0,
        'red_cards': 0,
      });
      // Karim total: 12.0 + 17.0 + 5.0 = 34.0 / 3 = 11.33

      // Sofiane (p3): played only 1 session (missed 3 sessions -> ineligible)
      // S1: Team A (win: 10) + 2 goals (4) + 1 assist (1) = 15.0
      await db.insert('participations', {
        'id': 'part_8',
        'session_id': 's_oct_1',
        'player_id': 'p3',
        'team': 'A',
        'goals': 2,
        'assists': 1,
        'yellow_cards': 0,
        'red_cards': 0,
      });

      // Team 1 Session in September 2026 (Different month)
      await db.insert('sessions', {
        'id': 's_sep_1',
        'team_id': 'team_1',
        'played_at': '2026-09-15 20:00:00',
        'status': 'CLOSED',
        'is_ranked': 1,
        'score_a': 3,
        'score_b': 1,
        'result': 'A',
      });
      await db.insert('participations', {
        'id': 'part_sep_1',
        'session_id': 's_sep_1',
        'player_id': 'p1',
        'team': 'A',
        'goals': 3,
        'assists': 0,
      });

      // Team 2 Session (Should not leak into Team 1)
      await db.insert('sessions', {
        'id': 's_beta_1',
        'team_id': 'team_2',
        'played_at': '2026-10-05 20:00:00',
        'status': 'CLOSED',
        'is_ranked': 1,
        'score_a': 1,
        'score_b': 0,
        'result': 'A',
      });
      await db.insert('participations', {
        'id': 'part_beta_1',
        'session_id': 's_beta_1',
        'player_id': 'p_beta',
        'team': 'A',
        'goals': 1,
        'assists': 0,
      });
    });

    tearDown(() async {
      await db.close();
    });

    test('getAvailableMonths returns distinct YYYY-MM in descending order for team', () async {
      final monthsTeam1 = await rankingRepo.getAvailableMonths(teamId: 'team_1');
      expect(monthsTeam1, ['2026-10', '2026-09']);

      final monthsTeam2 = await rankingRepo.getAvailableMonths(teamId: 'team_2');
      expect(monthsTeam2, ['2026-10']);
    });

    test('getMvpRanking calculates correct scores, eligibility and ordering', () async {
      final ranking = await rankingRepo.getMvpRanking(teamId: 'team_1', month: '2026-10');

      expect(ranking.length, 3);

      // Karim (p2) is #1: played 3 matches (missed 1 <= 1), avg score = 11.33
      final karim = ranking[0];
      expect(karim.playerId, 'p2');
      expect(karim.name, 'Karim');
      expect(karim.matchesPlayed, 3);
      expect(karim.totalSessions, 4);
      expect(karim.isEligible, isTrue);
      expect(karim.missingMatches, 0);
      expect(karim.score, 11.33);

      // Lucas (p1) is #2: played 4 matches (missed 0), avg score = 9.38
      final lucas = ranking[1];
      expect(lucas.playerId, 'p1');
      expect(lucas.name, 'Lucas');
      expect(lucas.matchesPlayed, 4);
      expect(lucas.totalSessions, 4);
      expect(lucas.isEligible, isTrue);
      expect(lucas.missingMatches, 0);
      expect(lucas.score, 9.38);
      expect(lucas.yellowCards, 1);
      expect(lucas.redCards, 1);

      // Sofiane (p3) is #3: played 1 match (missed 3 > 1) -> NOT eligible
      final sofiane = ranking[2];
      expect(sofiane.playerId, 'p3');
      expect(sofiane.name, 'Sofiane');
      expect(sofiane.matchesPlayed, 1);
      expect(sofiane.totalSessions, 4);
      expect(sofiane.isEligible, isFalse);
      expect(sofiane.missingMatches, 2);
    });

    test('getPlayerOfTheMonth returns top eligible player for month or latest month', () async {
      // Specified month: Karim
      final mvpOct = await rankingRepo.getPlayerOfTheMonth(teamId: 'team_1', month: '2026-10');
      expect(mvpOct, isNotNull);
      expect(mvpOct!.playerId, 'p2');
      expect(mvpOct.name, 'Karim');
      expect(mvpOct.isEligible, isTrue);

      // Null month: defaults to latest month ('2026-10')
      final latestMvp = await rankingRepo.getPlayerOfTheMonth(teamId: 'team_1');
      expect(latestMvp, isNotNull);
      expect(latestMvp!.playerId, 'p2');

      // Month with 0 sessions
      final emptyMvp = await rankingRepo.getPlayerOfTheMonth(teamId: 'team_1', month: '2025-01');
      expect(emptyMvp, isNull);
    });

    test('getStandings with month filter aggregates stats only for that month', () async {
      // Without month filter (All-time): Lucas has 4 matches in Oct + 1 in Sep = 5 matches
      final allTime = await rankingRepo.getStandings(teamId: 'team_1');
      final lucasAll = allTime.firstWhere((e) => e.playerId == 'p1');
      expect(lucasAll.matchesPlayed, 5);
      expect(lucasAll.goals, 6 + 3); // 6 in Oct + 3 in Sep = 9

      // With month filter: '2026-10'
      final octStandings = await rankingRepo.getStandings(teamId: 'team_1', month: '2026-10');
      final lucasOct = octStandings.firstWhere((e) => e.playerId == 'p1');
      expect(lucasOct.matchesPlayed, 4);
      expect(lucasOct.goals, 6);

      // With month filter: '2026-09'
      final sepStandings = await rankingRepo.getStandings(teamId: 'team_1', month: '2026-09');
      expect(sepStandings.length, 1);
      expect(sepStandings.first.playerId, 'p1');
      expect(sepStandings.first.goals, 3);
    });

    test('getTopScorers and getTopAssists with month filter', () async {
      // Scorers in October: Lucas has 6 goals, Karim has 5 goals, Sofiane has 2
      final octScorers = await rankingRepo.getTopScorers(teamId: 'team_1', month: '2026-10');
      expect(octScorers.first.playerId, 'p1');
      expect(octScorers.first.goals, 6);
      expect(octScorers[1].playerId, 'p2');
      expect(octScorers[1].goals, 5);

      // Assists in October: Lucas has 4 assists, Karim has 1 assist, Sofiane has 1
      final octAssists = await rankingRepo.getTopAssists(teamId: 'team_1', month: '2026-10');
      expect(octAssists.first.playerId, 'p1');
      expect(octAssists.first.assists, 4);
    });

    test('multi-tenant isolation: Team Beta data does not leak into Team Alpha', () async {
      final team1Mvp = await rankingRepo.getMvpRanking(teamId: 'team_1', month: '2026-10');
      expect(team1Mvp.any((e) => e.playerId == 'p_beta'), isFalse);

      final team2Mvp = await rankingRepo.getMvpRanking(teamId: 'team_2', month: '2026-10');
      expect(team2Mvp.length, 1);
      expect(team2Mvp.first.playerId, 'p_beta');
    });
  });
}
