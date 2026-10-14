import 'package:flutter_test/flutter_test.dart';
import 'package:statoo/features/ranking/domain/mvp_calculator.dart';
import 'package:statoo/features/ranking/domain/mvp_entry.dart';

void main() {
  group('MvpCalculator match score formula', () {
    test('calculates correct score for win with goals and assists', () {
      // Win (10 pts) + 2 goals (4 pts) + 1 assist (1 pt) - 0 cards = 15.0 pts
      final score = MvpCalculator.calculateMatchScore(
        isWin: true,
        isDraw: false,
        goals: 2,
        assists: 1,
        yellowCards: 0,
        redCards: 0,
      );
      expect(score, 15.0);
    });

    test('calculates correct score for draw with yellow card', () {
      // Draw (3 pts) + 1 goal (2 pts) + 0 assist - 1 yellow (-0.5 pt) = 4.5 pts
      final score = MvpCalculator.calculateMatchScore(
        isWin: false,
        isDraw: true,
        goals: 1,
        assists: 0,
        yellowCards: 1,
        redCards: 0,
      );
      expect(score, 4.5);
    });

    test('calculates correct score for loss with red card and yellow card', () {
      // Loss (0 pts) + 3 goals (6 pts) + 2 assists (2 pts) - 1 yellow (-0.5) - 1 red (-1.0) = 6.5 pts
      final score = MvpCalculator.calculateMatchScore(
        isWin: false,
        isDraw: false,
        goals: 3,
        assists: 2,
        yellowCards: 1,
        redCards: 1,
      );
      expect(score, 6.5);
    });

    test('calculates score with custom draw points when specified', () {
      // Custom draw points (e.g. 2 instead of 3 if scaled): resultPts parameter
      final score = MvpCalculator.calculateMatchScore(
        isWin: false,
        isDraw: true,
        goals: 0,
        assists: 0,
        yellowCards: 0,
        redCards: 0,
        drawPoints: 2,
      );
      expect(score, 2.0);
    });
  });

  group('MvpCalculator eligibility rules', () {
    test('player who missed 0 matches is eligible', () {
      final isEligible = MvpCalculator.isEligible(
        matchesPlayed: 4,
        totalSessions: 4,
      );
      expect(isEligible, isTrue);
      expect(MvpCalculator.missingMatches(matchesPlayed: 4, totalSessions: 4), 0);
    });

    test('player who missed 1 match (N - 1) is eligible', () {
      final isEligible = MvpCalculator.isEligible(
        matchesPlayed: 3,
        totalSessions: 4,
      );
      expect(isEligible, isTrue);
      expect(MvpCalculator.missingMatches(matchesPlayed: 3, totalSessions: 4), 0);
    });

    test('player who missed 2 matches is NOT eligible', () {
      final isEligible = MvpCalculator.isEligible(
        matchesPlayed: 2,
        totalSessions: 4,
      );
      expect(isEligible, isFalse);
      expect(MvpCalculator.missingMatches(matchesPlayed: 2, totalSessions: 4), 1);
    });

    test('player who missed 3 matches in 4 sessions has missingMatches = 2', () {
      expect(MvpCalculator.missingMatches(matchesPlayed: 1, totalSessions: 4), 2);
    });

    test('when totalSessions is 1, player with 1 match is eligible', () {
      final isEligible = MvpCalculator.isEligible(
        matchesPlayed: 1,
        totalSessions: 1,
      );
      expect(isEligible, isTrue);
      expect(MvpCalculator.missingMatches(matchesPlayed: 1, totalSessions: 1), 0);
    });

    test('when totalSessions is 1, player with 0 match is NOT eligible', () {
      // Even though 0 >= (1 - 1), player must have played at least 1 match
      final isEligible = MvpCalculator.isEligible(
        matchesPlayed: 0,
        totalSessions: 1,
      );
      expect(isEligible, isFalse);
    });

    test('when totalSessions is 0, no player is eligible', () {
      final isEligible = MvpCalculator.isEligible(
        matchesPlayed: 0,
        totalSessions: 0,
      );
      expect(isEligible, isFalse);
    });
  });

  group('MvpCalculator average score and rounding', () {
    test('calculates average score over multiple matches with 2 decimal precision', () {
      // 14.5 + 4.5 = 19.0 / 2 = 9.5
      final avg = MvpCalculator.calculateAverageScore(
        totalScore: 19,
        matchesPlayed: 2,
      );
      expect(avg, 9.5);
    });

    test('handles division by zero gracefully', () {
      final avg = MvpCalculator.calculateAverageScore(
        totalScore: 0,
        matchesPlayed: 0,
      );
      expect(avg, 0.0);
    });

    test('rounds correctly to 2 decimals', () {
      // 20.0 / 3 = 6.6666... -> 6.67
      final avg = MvpCalculator.calculateAverageScore(
        totalScore: 20,
        matchesPlayed: 3,
      );
      expect(avg, 6.67);
    });
  });

  group('MvpEntry deserialization and properties', () {
    test('fromMap parses all fields correctly', () {
      final map = {
        'rank': 1,
        'player_id': 'p1',
        'name': 'Lucas',
        'nickname': 'Lulu',
        'avatar_url': 'https://example.com/avatar.jpg',
        'matches_played': 4,
        'total_sessions': 4,
        'wins': 3,
        'draws': 1,
        'losses': 0,
        'goals': 5,
        'assists': 3,
        'yellow_cards': 1,
        'red_cards': 0,
        'score': 12.38,
        'is_eligible': 1,
        'missing_matches': 0,
      };

      final entry = MvpEntry.fromMap(map);
      expect(entry.rank, 1);
      expect(entry.playerId, 'p1');
      expect(entry.name, 'Lucas');
      expect(entry.nickname, 'Lulu');
      expect(entry.avatarUrl, 'https://example.com/avatar.jpg');
      expect(entry.matchesPlayed, 4);
      expect(entry.totalSessions, 4);
      expect(entry.wins, 3);
      expect(entry.draws, 1);
      expect(entry.losses, 0);
      expect(entry.goals, 5);
      expect(entry.assists, 3);
      expect(entry.yellowCards, 1);
      expect(entry.redCards, 0);
      expect(entry.score, 12.38);
      expect(entry.isEligible, isTrue);
      expect(entry.missingMatches, 0);
    });

    test('fromMap handles null and missing optional fields with defaults', () {
      final map = {
        'rank': 2,
        'player_id': 'p2',
        'name': 'Karim',
        'matches_played': 2,
        'total_sessions': 4,
        'wins': 1,
        'draws': 0,
        'losses': 1,
        'goals': 1,
        'assists': 0,
        'yellow_cards': 0,
        'red_cards': 1,
        'score': 4.5,
        'is_eligible': 0,
        'missing_matches': 1,
      };

      final entry = MvpEntry.fromMap(map);
      expect(entry.rank, 2);
      expect(entry.nickname, isNull);
      expect(entry.avatarUrl, isNull);
      expect(entry.isEligible, isFalse);
      expect(entry.missingMatches, 1);
    });
  });
}
