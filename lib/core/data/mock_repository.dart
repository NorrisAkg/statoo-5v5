import '../../features/players/domain/player.dart';
import '../../features/sessions/domain/session.dart';
import '../../features/sessions/domain/participation.dart';
import '../domain/statoo_repository.dart';

class MockRepository implements StatooRepository {
  final List<Player> _players = [
    Player(id: 'p1', name: 'Lucas', nickname: 'Lulu', createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1)),
    Player(id: 'p2', name: 'Karim', createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1)),
    Player(id: 'p3', name: 'Sofiane', createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1)),
    Player(id: 'p4', name: 'Mehdi', nickname: 'Didi', createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1)),
    Player(id: 'p5', name: 'Hugo', createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1)),
    Player(id: 'p6', name: 'Yassine', nickname: 'Yass', createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1)),
    Player(id: 'p7', name: 'Théo', createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1)),
    Player(id: 'p8', name: 'Benjamin', createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1)),
    Player(id: 'p9', name: 'Nicolas', createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1)),
    Player(id: 'p10', name: 'Enzo', createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1)),
    Player(id: 'p11', name: 'Thomas', createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1)),
    Player(id: 'p12', name: 'Antoine', createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1)),
    Player(id: 'p13', name: 'Maxime', createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1)),
    Player(id: 'p14', name: 'Julien', createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1)),
  ];

  final List<Session> _sessions = [
    Session(
      id: 's9',
      playedAt: DateTime(2026, 9, 9, 20, 30),
      status: SessionStatus.closed,
      isRanked: true,
      scoreA: 5,
      scoreB: 3,
      result: MatchResult.teamA,
    ),
  ];

  final List<Participation> _participations = [
    const Participation(id: 'part1', sessionId: 's9', playerId: 'p1', team: Team.a, goals: 2, assists: 1), // Lucas
    const Participation(id: 'part2', sessionId: 's9', playerId: 'p2', team: Team.a), // Karim
    const Participation(id: 'part3', sessionId: 's9', playerId: 'p3', team: Team.a), // Sofiane
    const Participation(id: 'part4', sessionId: 's9', playerId: 'p4', team: Team.a), // Mehdi
    const Participation(id: 'part5', sessionId: 's9', playerId: 'p5', team: Team.a), // Hugo
    
    const Participation(id: 'part6', sessionId: 's9', playerId: 'p6', team: Team.b), // Yassine
    const Participation(id: 'part7', sessionId: 's9', playerId: 'p7', team: Team.b), // Théo
    const Participation(id: 'part8', sessionId: 's9', playerId: 'p8', team: Team.b), // Benjamin
    const Participation(id: 'part9', sessionId: 's9', playerId: 'p9', team: Team.b), // Nicolas
    const Participation(id: 'part10', sessionId: 's9', playerId: 'p10', team: Team.b), // Enzo
  ];

  @override
  Future<List<Player>> getPlayers() async => _players;

  @override
  Future<List<Session>> getSessions() async => _sessions;

  @override
  Future<List<Participation>> getParticipations() async => _participations;

  @override
  Future<void> saveSession(Session session, List<Participation> participations) async {
    _sessions.removeWhere((s) => s.id == session.id);
    _sessions.add(session);
    _participations.removeWhere((p) => p.sessionId == session.id);
    _participations.addAll(participations);
  }
}
