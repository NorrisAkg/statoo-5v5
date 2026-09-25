import 'package:flutter_test/flutter_test.dart';
import 'package:statoo/features/stats/domain/group_totals.dart';

void main() {
  group('GroupTotals deserialization from SQL view v_group_totals', () {
    test('GroupTotals parses correctly from map', () {
      final map = {
        'total_sessions': 14,
        'ranked_sessions': 12,
        'friendly_sessions': 2,
        'total_players': 14,
        'active_players': 12,
        'total_goals': 64,
        'avg_goals_per_session': 4.57,
        'total_assists': 42,
        'total_yellow_cards': 3,
        'total_red_cards': 1,
        'total_player_goals': 60,
        'unassigned_goals_difference': 4,
      };

      final totals = GroupTotals.fromMap(map);

      expect(totals.totalSessions, 14);
      expect(totals.rankedSessions, 12);
      expect(totals.friendlySessions, 2);
      expect(totals.totalPlayers, 14);
      expect(totals.activePlayers, 12);
      expect(totals.totalGoals, 64);
      expect(totals.avgGoalsPerSession, 4.57);
      expect(totals.totalAssists, 42);
      expect(totals.totalYellowCards, 3);
      expect(totals.totalRedCards, 1);
      expect(totals.totalPlayerGoals, 60);
      expect(totals.unassignedGoalsDifference, 4);
    });

    test('GroupTotals handles empty or zero values gracefully', () {
      final totals = GroupTotals.fromMap({});

      expect(totals.totalSessions, 0);
      expect(totals.rankedSessions, 0);
      expect(totals.friendlySessions, 0);
      expect(totals.totalPlayers, 0);
      expect(totals.activePlayers, 0);
      expect(totals.totalGoals, 0);
      expect(totals.avgGoalsPerSession, 0.0);
      expect(totals.totalAssists, 0);
      expect(totals.totalYellowCards, 0);
      expect(totals.totalRedCards, 0);
      expect(totals.totalPlayerGoals, 0);
      expect(totals.unassignedGoalsDifference, 0);
    });
  });
}
