import 'package:flutter_test/flutter_test.dart';
import 'package:statoo/features/sessions/domain/session.dart';
import 'package:statoo/features/sessions/domain/participation.dart';
import 'package:statoo/features/stats/domain/stats_calculator.dart';

void main() {
  group('StatsCalculator', () {
    test('calcule correctement les points et stats pour une victoire, défaite et nul', () {
      final sessions = [
        Session(
          id: 's1',
          playedAt: DateTime.now(),
          status: SessionStatus.closed,
          isRanked: true,
          result: MatchResult.teamA, // Équipe A gagne
        ),
        Session(
          id: 's2',
          playedAt: DateTime.now(),
          status: SessionStatus.closed,
          isRanked: true,
          result: MatchResult.draw, // Nul
        ),
        Session(
          id: 's3',
          playedAt: DateTime.now(),
          status: SessionStatus.draft, // Non classé (brouillon), ignoré
          isRanked: true,
        ),
      ];

      final participations = [
        // S1 : P1 dans l'équipe A (gagne), P2 dans l'équipe B (perd)
        const Participation(id: '1', sessionId: 's1', playerId: 'p1', team: Team.a, goals: 2, assists: 1),
        const Participation(id: '2', sessionId: 's1', playerId: 'p2', team: Team.b, yellowCards: 1),
        
        // S2 : P1 dans l'équipe A (nul), P2 dans l'équipe B (nul)
        const Participation(id: '3', sessionId: 's2', playerId: 'p1', team: Team.a, goals: 1),
        const Participation(id: '4', sessionId: 's2', playerId: 'p2', team: Team.b),

        // S3 : P1 et P2 jouent, mais brouillon (ignoré)
        const Participation(id: '5', sessionId: 's3', playerId: 'p1', team: Team.a),
      ];

      final stats = StatsCalculator.computePlayerStats(sessions, participations);

      final p1 = stats.firstWhere((s) => s.playerId == 'p1');
      final p2 = stats.firstWhere((s) => s.playerId == 'p2');

      // Assertions P1 (1 victoire, 1 nul -> 4 pts, 2 matchs)
      expect(p1.matchesPlayed, 2);
      expect(p1.wins, 1);
      expect(p1.draws, 1);
      expect(p1.losses, 0);
      expect(p1.totalPoints, 4);
      expect(p1.goals, 3); // 2 + 1
      expect(p1.assists, 1);

      // Assertions P2 (1 défaite, 1 nul -> 1 pt, 2 matchs)
      expect(p2.matchesPlayed, 2);
      expect(p2.wins, 0);
      expect(p2.draws, 1);
      expect(p2.losses, 1);
      expect(p2.totalPoints, 1);
      expect(p2.yellowCards, 1);
    });
  });
}
