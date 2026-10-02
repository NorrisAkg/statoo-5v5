import 'dart:math' as math;

import 'mvp_weights.dart';

class MvpCalculator {
  const MvpCalculator._();

  /// Calculates the performance score for a single match. With the default
  /// [MvpWeights]: win 10, draw 3 (or [drawPoints]), loss 0, goal +2,
  /// assist +1, yellow -0.5, red -1.
  static double calculateMatchScore({
    required bool isWin,
    required bool isDraw,
    required int goals,
    required int assists,
    required int yellowCards,
    required int redCards,
    MvpWeights weights = MvpWeights.defaults,
    int? drawPoints,
  }) {
    final double resultPoints;
    if (isWin) {
      resultPoints = weights.win;
    } else if (isDraw) {
      resultPoints = drawPoints?.toDouble() ?? weights.draw;
    } else {
      resultPoints = weights.loss;
    }

    final offensivePoints = (goals * weights.goal) + (assists * weights.assist);
    final fairPlayMalus = (yellowCards * weights.yellowCard) + (redCards * weights.redCard);

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
