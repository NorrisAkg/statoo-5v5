import 'package:intl/intl.dart';

class PlayerDetailStats {
  const PlayerDetailStats({
    required this.matchesPlayed,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.points,
    required this.goals,
    required this.assists,
    required this.yellowCards,
    required this.redCards,
    required this.appearances,
  });

  const PlayerDetailStats.empty()
      : matchesPlayed = 0,
        wins = 0,
        draws = 0,
        losses = 0,
        points = 0,
        goals = 0,
        assists = 0,
        yellowCards = 0,
        redCards = 0,
        appearances = 0;

  factory PlayerDetailStats.fromMap(Map<String, dynamic> map) {
    return PlayerDetailStats(
      matchesPlayed: (map['matches_played'] as num?)?.toInt() ?? 0,
      wins: (map['wins'] as num?)?.toInt() ?? 0,
      draws: (map['draws'] as num?)?.toInt() ?? 0,
      losses: (map['losses'] as num?)?.toInt() ?? 0,
      points: (map['total_points'] as num?)?.toInt() ?? 0,
      goals: (map['goals'] as num?)?.toInt() ?? 0,
      assists: (map['assists'] as num?)?.toInt() ?? 0,
      yellowCards: (map['yellow_cards'] as num?)?.toInt() ?? 0,
      redCards: (map['red_cards'] as num?)?.toInt() ?? 0,
      appearances: (map['appearances'] as num?)?.toInt() ?? 0,
    );
  }

  final int matchesPlayed;
  final int wins;
  final int draws;
  final int losses;
  final int points;
  final int goals;
  final int assists;
  final int yellowCards;
  final int redCards;
  final int appearances;

  double get pointsPerMatch => matchesPlayed > 0 ? points / matchesPlayed : 0.0;
  double get winRate => matchesPlayed > 0 ? wins / matchesPlayed : 0.0;
}

class PlayerMatchHistoryItem {
  const PlayerMatchHistoryItem({
    required this.participationId,
    required this.sessionId,
    required this.playerId,
    required this.team,
    required this.goals,
    required this.assists,
    required this.yellowCards,
    required this.redCards,
    required this.playedAt,
    required this.status,
    required this.isRanked,
    this.scoreA,
    this.scoreB,
    this.result,
  });

  factory PlayerMatchHistoryItem.fromMap(Map<String, dynamic> map) {
    return PlayerMatchHistoryItem(
      participationId: map['participation_id'] as String,
      sessionId: map['session_id'] as String,
      playerId: map['player_id'] as String,
      team: map['team'] as String,
      goals: (map['goals'] as num?)?.toInt() ?? 0,
      assists: (map['assists'] as num?)?.toInt() ?? 0,
      yellowCards: (map['yellow_cards'] as num?)?.toInt() ?? 0,
      redCards: (map['red_cards'] as num?)?.toInt() ?? 0,
      playedAt: DateTime.parse(map['played_at'] as String),
      status: map['status'] as String,
      isRanked: (map['is_ranked'] as num?)?.toInt() == 1,
      scoreA: (map['score_a'] as num?)?.toInt(),
      scoreB: (map['score_b'] as num?)?.toInt(),
      result: map['result'] as String?,
    );
  }

  final String participationId;
  final String sessionId;
  final String playerId;
  final String team;
  final int goals;
  final int assists;
  final int yellowCards;
  final int redCards;
  final DateTime playedAt;
  final String status;
  final bool isRanked;
  final int? scoreA;
  final int? scoreB;
  final String? result;

  bool get isClosed => status == 'CLOSED';
  bool get isWin => isClosed && isRanked && ((result == 'A' && team == 'A') || (result == 'B' && team == 'B'));
  bool get isDraw => isClosed && isRanked && result == 'DRAW';
  bool get isLoss => isClosed && isRanked && ((result == 'A' && team == 'B') || (result == 'B' && team == 'A'));

  String get outcomeText {
    if (!isClosed) return 'En cours';
    if (!isRanked) return 'Amical';
    if (isWin) return 'Victoire';
    if (isDraw) return 'Nul';
    return 'Défaite';
  }

  String get scoreText {
    if (scoreA == null || scoreB == null) return '- - -';
    return '$scoreA - $scoreB';
  }

  String get formattedDate {
    final now = DateTime.now();
    if (playedAt.year == now.year && playedAt.month == now.month && playedAt.day == now.day) {
      return "Aujourd'hui";
    }
    return DateFormat('EEE d MMM', 'fr_FR').format(playedAt);
  }
}
