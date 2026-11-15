import 'participation.dart';
import 'session.dart';

/// Blocking reasons for closing a session (CDC §4.2 and §5).
enum CloseBlocker {
  missingScore,
  unevenTeams,
  goalsMismatch,
  assistsExceedGoals,
  selfAssist,
  duplicatePlayer,
  belowMinimumPlayers,
}

/// The session vanished or changed between the check and the write.
class SessionCloseException implements Exception {
  const SessionCloseException(this.message);
  final String message;

  @override
  String toString() => 'SessionCloseException: $message';
}

MatchResult? computeTournamentResult(int winsA, int winsB, int winsC) {
  if (winsA == 0 && winsB == 0 && winsC == 0) return null;
  if (winsA > winsB && winsA > winsC) return MatchResult.teamA;
  if (winsB > winsA && winsB > winsC) return MatchResult.teamB;
  if (winsC > winsA && winsC > winsB) return MatchResult.teamC;
  if (winsA == winsB && winsA > winsC) return MatchResult.drawAB;
  if (winsB == winsC && winsB > winsA) return MatchResult.drawBC;
  if (winsA == winsC && winsA > winsB) return MatchResult.drawAC;
  return MatchResult.drawAll;
}

bool hasScore(Session session) {
  if (session.sessionType == SessionType.tournament3) {
    return session.result != null;
  }
  return session.scoreA != null && session.scoreB != null && session.result != null;
}

List<CloseBlocker> closeBlockers({
  required Session session,
  required int teamACount,
  required int teamBCount,
  int? teamCCount,
  int playerGoalsA = 0,
  int playerGoalsB = 0,
  int playerGoalsC = 0,
  int playerAssistsA = 0,
  int playerAssistsB = 0,
  int playerAssistsC = 0,
  Iterable<Participation>? participations,
  int minimumPlayers = 0,
}) {
  final uneven = _uneven(session, teamACount, teamBCount, teamCCount);
  final belowMinimum =
      teamACount + teamBCount + (teamCCount ?? 0) < minimumPlayers;

  var hasDuplicatePlayer = false;
  if (participations != null) {
    final seenPlayers = <String>{};
    for (final p in participations) {
      if (!seenPlayers.add(p.playerId)) {
        hasDuplicatePlayer = true;
        break;
      }
    }
  }

  final hasSelfAssist = participations != null &&
      participations.any((p) {
        final teamGoals = switch (p.team) {
          Team.a => playerGoalsA,
          Team.b => playerGoalsB,
          Team.c => playerGoalsC,
        };
        return p.goals + p.assists > teamGoals;
      });

  final totalAssists = playerAssistsA + playerAssistsB + playerAssistsC;
  final totalGoals = playerGoalsA + playerGoalsB + playerGoalsC;

  return [
    if (!hasScore(session)) CloseBlocker.missingScore,
    if (hasDuplicatePlayer) CloseBlocker.duplicatePlayer,
    if (belowMinimum) CloseBlocker.belowMinimumPlayers,
    if (!session.allowUnevenTeams && uneven) CloseBlocker.unevenTeams,
    if (session.scoreA != null && session.scoreB != null &&
        (playerGoalsA + session.unassignedGoalsA != session.scoreA! ||
         playerGoalsB + session.unassignedGoalsB != session.scoreB! ||
         (session.scoreC != null && playerGoalsC + session.unassignedGoalsC != session.scoreC!)))
      CloseBlocker.goalsMismatch,
    if (playerAssistsA > playerGoalsA ||
        playerAssistsB > playerGoalsB ||
        (session.sessionType == SessionType.tournament3 && playerAssistsC > playerGoalsC) ||
        totalAssists > totalGoals)
      CloseBlocker.assistsExceedGoals,
    if (hasSelfAssist) CloseBlocker.selfAssist,
  ];
}

/// MET-002 : conditions de démarrage d'une séance, identiques à celles de
/// l'API (`validate_sport`, `is_active`) : minimum de joueurs du groupe et
/// équilibre des équipes. Le score n'est pas exigé (il part de 0-0).
List<CloseBlocker> startBlockers({
  required Session session,
  required int teamACount,
  required int teamBCount,
  required int minimumPlayers,
  int? teamCCount,
}) => [
  if (teamACount + teamBCount + (teamCCount ?? 0) < minimumPlayers)
    CloseBlocker.belowMinimumPlayers,
  if (!session.allowUnevenTeams &&
      _uneven(session, teamACount, teamBCount, teamCCount))
    CloseBlocker.unevenTeams,
];

bool _uneven(Session session, int a, int b, int? c) {
  if (session.sessionType != SessionType.tournament3) return (a - b).abs() > 1;
  final counts = [a, b, c ?? 0];
  final maxCount = counts.reduce((x, y) => x > y ? x : y);
  final minCount = counts.reduce((x, y) => x < y ? x : y);
  return maxCount - minCount > 1;
}
