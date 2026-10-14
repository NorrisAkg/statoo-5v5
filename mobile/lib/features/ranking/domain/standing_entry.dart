class StandingEntry {
  const StandingEntry({
    required this.rank,
    required this.playerId,
    required this.name,
    required this.isActive,
    required this.matchesPlayed,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.points,
    required this.goals,
    required this.assists,
    this.nickname,
    this.avatarUrl,
  });

  factory StandingEntry.fromMap(Map<String, dynamic> map) {
    return StandingEntry(
      rank: (map['rank'] as num?)?.toInt() ?? 0,
      playerId: map['player_id'] as String,
      name: map['name'] as String,
      isActive: (map['is_active'] as num?)?.toInt() == 1,
      matchesPlayed: (map['matches_played'] as num?)?.toInt() ?? 0,
      wins: (map['wins'] as num?)?.toInt() ?? 0,
      draws: (map['draws'] as num?)?.toInt() ?? 0,
      losses: (map['losses'] as num?)?.toInt() ?? 0,
      points: (map['points'] as num?)?.toInt() ?? 0,
      goals: (map['goals'] as num?)?.toInt() ?? 0,
      assists: (map['assists'] as num?)?.toInt() ?? 0,
      nickname: (map['nickname'] as String?)?.isNotEmpty == true ? map['nickname'] as String : null,
      avatarUrl: map['avatar_url'] as String?,
    );
  }

  final int rank;
  final String playerId;
  final String name;
  final String? nickname;
  final String? avatarUrl;
  final bool isActive;
  final int matchesPlayed;
  final int wins;
  final int draws;
  final int losses;
  final int points;
  final int goals;
  final int assists;
}
