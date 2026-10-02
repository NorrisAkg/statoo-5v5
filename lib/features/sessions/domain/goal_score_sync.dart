import 'dart:math' as math;

/// Goals already counted in a team's score but not yet given to anyone.
int freeGoals({
  required int score,
  required int assignedGoals,
  required int unassignedGoals,
}) {
  return math.max(0, score - assignedGoals - unassignedGoals);
}

/// How much a team's score must grow when [added] goals get attributed to a
/// scorer (or to the "own goal / unassigned" counter).
///
/// Goals the score already holds without a scorer are consumed first, so
/// scoring the team and then naming the scorer never counts the goal twice.
/// Removing or moving a goal never lowers the score.
int scoreIncreaseForAttributedGoals({
  required int score,
  required int assignedGoals,
  required int unassignedGoals,
  required int added,
}) {
  if (added <= 0) return 0;
  final free = freeGoals(
    score: score,
    assignedGoals: assignedGoals,
    unassignedGoals: unassignedGoals,
  );
  return math.max(0, added - free);
}
