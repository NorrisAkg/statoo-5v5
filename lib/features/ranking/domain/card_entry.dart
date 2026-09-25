class CardEntry {
  const CardEntry({
    required this.rank,
    required this.playerId,
    required this.name,
    required this.matchesPlayed,
    required this.yellowCards,
    required this.redCards,
    required this.totalCards,
    this.nickname,
    this.avatarUrl,
  });

  factory CardEntry.fromMap(Map<String, dynamic> map) {
    return CardEntry(
      rank: (map['rank'] as num?)?.toInt() ?? 0,
      playerId: map['player_id'] as String,
      name: map['name'] as String,
      matchesPlayed: (map['matches_played'] as num?)?.toInt() ?? 0,
      yellowCards: (map['yellow_cards'] as num?)?.toInt() ?? 0,
      redCards: (map['red_cards'] as num?)?.toInt() ?? 0,
      totalCards: (map['total_cards'] as num?)?.toInt() ?? 0,
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
  final int yellowCards;
  final int redCards;
  final int totalCards;
}
