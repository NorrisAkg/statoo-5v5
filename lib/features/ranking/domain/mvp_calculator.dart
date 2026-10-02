import 'dart:math' as math;

class MvpCalculator {
  const MvpCalculator._();

  /// Calculates the performance score for a single match:
  /// - Win: 10 pts
  /// - Draw: 3 pts (or specified [drawPoints])
  /// - Loss: 0 pt
  /// - Goals: +2 pts each
  /// - Assists: +1 pt each
  /// - Yellow card: -0.5 pt each
  /// - Red card: -1.0 pt each
  static double calculateMatchScore({
    required bool isWin,
    required bool isDraw,
    required int goals,
    required int assists,
    required int yellowCards,
    required int redCards,
    int drawPoints = 3,
  }) {
    double resultPoints = 0;
    if (isWin) {
      resultPoints = 10;
    } else if (isDraw) {
      resultPoints = drawPoints.toDouble();
    }

    final offensivePoints = (goals * 2) + assists;
    final fairPlayMalus = (yellowCards * 0.5) + redCards;

    return resultPoints + offensivePoints - fairPlayMalus;
  }

  /// A player is eligible for Player of the Month if:
  /// 1. The group has at least 1 session in that month
  /// 2. The player has played at least 1 session in that month
  /// 3. The player missed at most 1 session: matchesPlayed >= totalSessions - 1
  static bool isEligible({
    required int matchesPlayed,
    required int totalSessions,
  }) {
    if (totalSessions <= 0 || matchesPlayed <= 0) {
      return false;
    }
    final requiredMatches = math.max(1, totalSessions - 1);
    return matchesPlayed >= requiredMatches;
  }

  /// Calculates how many additional matches the player needed to be eligible.
  static int missingMatches({
    required int matchesPlayed,
    required int totalSessions,
  }) {
    if (totalSessions <= 0) return 0;
    final requiredMatches = math.max(1, totalSessions - 1);
    return math.max(0, requiredMatches - matchesPlayed);
  }

  /// Calculates the average score rounded to 2 decimal places.
  static double calculateAverageScore({
    required double totalScore,
    required int matchesPlayed,
  }) {
    if (matchesPlayed <= 0) return 0;
    final avg = totalScore / matchesPlayed;
    return double.parse(avg.toStringAsFixed(2));
  }
}
