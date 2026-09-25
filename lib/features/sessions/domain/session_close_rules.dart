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

bool hasScore(Session session) =>
    session.scoreA != null && session.scoreB != null && session.result != null;

List<CloseBlocker> closeBlockers({
  required Session session,
  required int teamACount,
  required int teamBCount,
}) {
  return [
    if (!hasScore(session)) CloseBlocker.missingScore,
    if (!session.allowUnevenTeams && (teamACount - teamBCount).abs() > 1) CloseBlocker.unevenTeams,
  ];
}
