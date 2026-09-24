import '../../sessions/domain/session.dart';
import '../../sessions/domain/participation.dart';
import 'stats_models.dart';

class StatsCalculator {
  static List<PlayerStats> computePlayerStats(List<Session> sessions, List<Participation> participations) {
    final Map<String, PlayerStats> statsMap = {};

    for (final session in sessions.where((s) => s.status == SessionStatus.closed && s.isRanked)) {
      final sessionParts = participations.where((p) => p.sessionId == session.id);
      
      for (final part in sessionParts) {
        final current = statsMap[part.playerId] ?? PlayerStats(playerId: part.playerId);
        
        int pts = 0;
        int win = 0;
        int draw = 0;
        int loss = 0;

        if (session.result == MatchResult.draw) {
          pts = 1;
          draw = 1;
        } else if ((session.result == MatchResult.teamA && part.team == Team.a) ||
                   (session.result == MatchResult.teamB && part.team == Team.b)) {
          pts = 3;
          win = 1;
        } else {
          pts = 0;
          loss = 1;
        }

        statsMap[part.playerId] = current.copyWith(
          matchesPlayed: current.matchesPlayed + 1,
          totalPoints: current.totalPoints + pts,
          wins: current.wins + win,
          draws: current.draws + draw,
          losses: current.losses + loss,
          goals: current.goals + part.goals,
          assists: current.assists + part.assists,
          yellowCards: current.yellowCards + part.yellowCards,
          redCards: current.redCards + part.redCards,
        );
      }
    }

    return statsMap.values.toList();
  }
}
