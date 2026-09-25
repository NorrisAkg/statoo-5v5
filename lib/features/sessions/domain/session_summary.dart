import 'package:intl/intl.dart';
import 'participation.dart';
import 'session.dart';

class SessionSummaryItem {
  const SessionSummaryItem({
    required this.session,
    required this.playerCount,
    this.totalGoalsAssignedA = 0,
    this.totalGoalsAssignedB = 0,
    this.isActiveSession = false,
  });

  final Session session;
  final int playerCount;
  final int totalGoalsAssignedA;
  final int totalGoalsAssignedB;
  final bool isActiveSession;

  bool get isDraft => session.status == SessionStatus.draft;
  bool get isInProgress => isDraft && isActiveSession;
  bool get isWaitingDraft => isDraft && !isActiveSession;
  bool get isClosed => session.status == SessionStatus.closed;
  bool get isRanked => session.isRanked;

  bool get hasGoalWarning {
    if (!isClosed) return false;
    final totalA = session.scoreA ?? 0;
    final totalB = session.scoreB ?? 0;
    final sumA = totalGoalsAssignedA + session.unassignedGoalsA;
    final sumB = totalGoalsAssignedB + session.unassignedGoalsB;
    return (sumA != totalA) || (sumB != totalB);
  }

  String get formattedDateTime {
    final dateStr = DateFormat('EEE d MMM', 'fr_FR').format(session.playedAt);
    final timeStr = DateFormat("HH'h'mm", 'fr_FR').format(session.playedAt);
    return '$dateStr · $timeStr';
  }

  String get monthYearGroup {
    return DateFormat('MMMM yyyy', 'fr_FR').format(session.playedAt).toUpperCase();
  }
}

class SessionParticipantDetail {
  const SessionParticipantDetail({
    required this.participation,
    required this.playerName,
    this.playerNickname,
    this.playerAvatarUrl,
  });

  final Participation participation;
  final String playerName;
  final String? playerNickname;
  final String? playerAvatarUrl;
}
