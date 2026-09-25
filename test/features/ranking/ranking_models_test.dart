import 'package:flutter_test/flutter_test.dart';
import 'package:statoo/features/ranking/domain/assist_entry.dart';
import 'package:statoo/features/ranking/domain/card_entry.dart';
import 'package:statoo/features/ranking/domain/scorer_entry.dart';
import 'package:statoo/features/ranking/domain/standing_entry.dart';
import 'package:statoo/features/ranking/domain/standing_per_match_entry.dart';

void main() {
  group('Ranking domain models deserialization from SQL views', () {
    test('StandingEntry parses correctly from v_standings row', () {
      final map = {
        'rank': 1,
        'player_id': 'p1',
        'name': 'Lucas',
        'nickname': 'Lulu',
        'avatar_url': null,
        'is_active': 1,
        'matches_played': 14,
        'wins': 9,
        'draws': 3,
        'losses': 2,
        'points': 30,
        'goals': 9,
        'assists': 11,
      };

      final entry = StandingEntry.fromMap(map);
      expect(entry.rank, 1);
      expect(entry.playerId, 'p1');
      expect(entry.name, 'Lucas');
      expect(entry.nickname, 'Lulu');
      expect(entry.matchesPlayed, 14);
      expect(entry.wins, 9);
      expect(entry.draws, 3);
      expect(entry.losses, 2);
      expect(entry.points, 30);
      expect(entry.goals, 9);
      expect(entry.assists, 11);
    });

    test('StandingPerMatchEntry parses correctly from v_standings_per_match row', () {
      final map = {
        'rank': 1,
        'player_id': 'p4',
        'name': 'Mehdi',
        'nickname': 'Didi',
        'avatar_url': null,
        'is_active': 1,
        'matches_played': 12,
        'wins': 8,
        'draws': 3,
        'losses': 1,
        'points': 27,
        'points_per_match': 2.25,
        'is_eligible': 1,
        'missing_matches': 0,
        'total_sessions': 14,
      };

      final entry = StandingPerMatchEntry.fromMap(map);
      expect(entry.rank, 1);
      expect(entry.pointsPerMatch, 2.25);
      expect(entry.isEligible, isTrue);
      expect(entry.missingMatches, 0);
      expect(entry.totalSessions, 14);
    });

    test('StandingPerMatchEntry handles non-eligible player correctly', () {
      final map = {
        'rank': 9,
        'player_id': 'p9',
        'name': 'Nicolas',
        'nickname': 'Nico',
        'avatar_url': null,
        'is_active': 1,
        'matches_played': 6,
        'wins': 6,
        'draws': 0,
        'losses': 0,
        'points': 18,
        'points_per_match': 3.0,
        'is_eligible': 0,
        'missing_matches': 1,
        'total_sessions': 14,
      };

      final entry = StandingPerMatchEntry.fromMap(map);
      expect(entry.isEligible, isFalse);
      expect(entry.missingMatches, 1);
    });

    test('ScorerEntry parses correctly from v_top_scorers row', () {
      final map = {
        'rank': 1,
        'player_id': 'p1',
        'name': 'Lucas',
        'nickname': 'Lulu',
        'avatar_url': null,
        'matches_played': 14,
        'goals': 9,
      };

      final entry = ScorerEntry.fromMap(map);
      expect(entry.rank, 1);
      expect(entry.goals, 9);
    });

    test('AssistEntry parses correctly from v_top_assists row', () {
      final map = {
        'rank': 1,
        'player_id': 'p1',
        'name': 'Lucas',
        'nickname': 'Lulu',
        'avatar_url': null,
        'matches_played': 14,
        'assists': 11,
      };

      final entry = AssistEntry.fromMap(map);
      expect(entry.rank, 1);
      expect(entry.assists, 11);
    });

    test('CardEntry parses correctly from v_top_cards row', () {
      final map = {
        'rank': 1,
        'player_id': 'p2',
        'name': 'Karim Benali',
        'nickname': 'Kaka',
        'avatar_url': null,
        'matches_played': 8,
        'yellow_cards': 2,
        'red_cards': 1,
        'total_cards': 3,
      };

      final entry = CardEntry.fromMap(map);
      expect(entry.rank, 1);
      expect(entry.playerId, 'p2');
      expect(entry.name, 'Karim Benali');
      expect(entry.nickname, 'Kaka');
      expect(entry.matchesPlayed, 8);
      expect(entry.yellowCards, 2);
      expect(entry.redCards, 1);
      expect(entry.totalCards, 3);
    });
  });
}
