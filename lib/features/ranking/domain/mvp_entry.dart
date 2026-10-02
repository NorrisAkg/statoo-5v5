class MvpEntry {
  const MvpEntry({
    required this.rank,
    required this.playerId,
    required this.name,
    required this.matchesPlayed,
    required this.totalSessions,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.goals,
    required this.assists,
    required this.yellowCards,
    required this.redCards,
    required this.score,
    required this.isEligible,
    required this.missingMatches,
    this.isActive = true,
    this.nickname,
    this.avatarUrl,
  });

  factory MvpEntry.fromMap(Map<String, dynamic> map) {
    return MvpEntry(
      rank: (map['rank'] as num?)?.toInt() ?? 0,
      playerId: map['player_id'] as String,
      name: map['name'] as String,
      nickname: (map['nickname'] as String?)?.isNotEmpty == true ? map['nickname'] as String : null,
      avatarUrl: map['avatar_url'] as String?,
      isActive: (map['is_active'] as num?)?.toInt() != 0,
      matchesPlayed: (map['matches_played'] as num?)?.toInt() ?? 0,
      totalSessions: (map['total_sessions'] as num?)?.toInt() ?? 0,
      wins: (map['wins'] as num?)?.toInt() ?? 0,
      draws: (map['draws'] as num?)?.toInt() ?? 0,
      losses: (map['losses'] as num?)?.toInt() ?? 0,
      goals: (map['goals'] as num?)?.toInt() ?? 0,
      assists: (map['assists'] as num?)?.toInt() ?? 0,
      yellowCards: (map['yellow_cards'] as num?)?.toInt() ?? 0,
      redCards: (map['red_cards'] as num?)?.toInt() ?? 0,
      score: (map['score'] as num?)?.toDouble() ?? 0.0,
      isEligible: (map['is_eligible'] as num?)?.toInt() == 1 || map['is_eligible'] == true,
      missingMatches: (map['missing_matches'] as num?)?.toInt() ?? 0,
    );
  }

  final int rank;
  final String playerId;
  final String name;
  final String? nickname;
  final String? avatarUrl;
  final bool isActive;
  final int matchesPlayed;
  final int totalSessions;
  final int wins;
  final int draws;
  final int losses;
  final int goals;
  final int assists;
  final int yellowCards;
  final int redCards;
  final double score;
  final bool isEligible;
  final int missingMatches;
}
