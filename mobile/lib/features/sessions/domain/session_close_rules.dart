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
}) {
  final bool uneven;
  if (session.sessionType == SessionType.tournament3) {
    final cCount = teamCCount ?? 0;
    final counts = [teamACount, teamBCount, cCount];
    final maxCount = counts.reduce((a, b) => a > b ? a : b);
    final minCount = counts.reduce((a, b) => a < b ? a : b);
    uneven = (maxCount - minCount) > 1;
  } else {
    uneven = (teamACount - teamBCount).abs() > 1;
  }

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
