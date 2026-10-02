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
    this.month,
  });

  factory MvpEntry.fromMap(Map<String, dynamic> map, [String? month]) {
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
      month: month ?? map['month'] as String?,
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
  final String? month;

  MvpEntry copyWith({
    int? rank,
    String? playerId,
    String? name,
    String? nickname,
    String? avatarUrl,
    bool? isActive,
    int? matchesPlayed,
    int? totalSessions,
    int? wins,
    int? draws,
    int? losses,
    int? goals,
    int? assists,
    int? yellowCards,
    int? redCards,
    double? score,
    bool? isEligible,
    int? missingMatches,
    String? month,
  }) {
    return MvpEntry(
      rank: rank ?? this.rank,
      playerId: playerId ?? this.playerId,
      name: name ?? this.name,
      nickname: nickname ?? this.nickname,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isActive: isActive ?? this.isActive,
      matchesPlayed: matchesPlayed ?? this.matchesPlayed,
      totalSessions: totalSessions ?? this.totalSessions,
      wins: wins ?? this.wins,
      draws: draws ?? this.draws,
      losses: losses ?? this.losses,
      goals: goals ?? this.goals,
      assists: assists ?? this.assists,
      yellowCards: yellowCards ?? this.yellowCards,
      redCards: redCards ?? this.redCards,
      score: score ?? this.score,
      isEligible: isEligible ?? this.isEligible,
      missingMatches: missingMatches ?? this.missingMatches,
      month: month ?? this.month,
    );
  }
}
