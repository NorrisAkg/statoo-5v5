import 'session.dart';

/// Blocking reasons for closing a session (CDC §4.2 and §5).
enum CloseBlocker { missingScore, unevenTeams }

/// The session vanished or changed between the check and the write.
class SessionCloseException implements Exception {
  const SessionCloseException(this.message);
  final String message;

  @override
  String toString() => 'SessionCloseException: $message';
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

  return [
    if (!hasScore(session)) CloseBlocker.missingScore,
    if (!session.allowUnevenTeams && uneven) CloseBlocker.unevenTeams,
  ];
}
