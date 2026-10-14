class AssistEntry {
  const AssistEntry({
    required this.rank,
    required this.playerId,
    required this.name,
    required this.matchesPlayed,
    required this.assists,
    this.nickname,
    this.avatarUrl,
  });

  factory AssistEntry.fromMap(Map<String, dynamic> map) {
    return AssistEntry(
      rank: (map['rank'] as num?)?.toInt() ?? 0,
      playerId: map['player_id'] as String,
      name: map['name'] as String,
      matchesPlayed: (map['matches_played'] as num?)?.toInt() ?? 0,
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
  final int matchesPlayed;
  final int assists;
}
