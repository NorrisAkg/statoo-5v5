class GroupTotals {
  const GroupTotals({
    required this.totalSessions,
    required this.rankedSessions,
    required this.friendlySessions,
    required this.totalPlayers,
    required this.activePlayers,
    required this.totalGoals,
    required this.avgGoalsPerSession,
    required this.totalAssists,
    required this.totalYellowCards,
    required this.totalRedCards,
    required this.totalPlayerGoals,
    required this.unassignedGoalsDifference,
  });

  const GroupTotals.empty()
      : totalSessions = 0,
        rankedSessions = 0,
        friendlySessions = 0,
        totalPlayers = 0,
        activePlayers = 0,
        totalGoals = 0,
        avgGoalsPerSession = 0.0,
        totalAssists = 0,
        totalYellowCards = 0,
        totalRedCards = 0,
        totalPlayerGoals = 0,
        unassignedGoalsDifference = 0;

  factory GroupTotals.fromMap(Map<String, dynamic> map) {
    return GroupTotals(
      totalSessions: (map['total_sessions'] as num?)?.toInt() ?? 0,
      rankedSessions: (map['ranked_sessions'] as num?)?.toInt() ?? 0,
      friendlySessions: (map['friendly_sessions'] as num?)?.toInt() ?? 0,
      totalPlayers: (map['total_players'] as num?)?.toInt() ?? 0,
      activePlayers: (map['active_players'] as num?)?.toInt() ?? 0,
      totalGoals: (map['total_goals'] as num?)?.toInt() ?? 0,
      avgGoalsPerSession: (map['avg_goals_per_session'] as num?)?.toDouble() ?? 0.0,
      totalAssists: (map['total_assists'] as num?)?.toInt() ?? 0,
      totalYellowCards: (map['total_yellow_cards'] as num?)?.toInt() ?? 0,
      totalRedCards: (map['total_red_cards'] as num?)?.toInt() ?? 0,
      totalPlayerGoals: (map['total_player_goals'] as num?)?.toInt() ?? 0,
      unassignedGoalsDifference: (map['unassigned_goals_difference'] as num?)?.toInt() ?? 0,
    );
  }

  final int totalSessions;
  final int rankedSessions;
  final int friendlySessions;
  final int totalPlayers;
  final int activePlayers;
  final int totalGoals;
  final double avgGoalsPerSession;
  final int totalAssists;
  final int totalYellowCards;
  final int totalRedCards;
  final int totalPlayerGoals;
  final int unassignedGoalsDifference;
}
