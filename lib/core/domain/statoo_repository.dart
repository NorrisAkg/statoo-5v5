import '../../features/players/domain/player.dart';
import '../../features/sessions/domain/participation.dart';
import '../../features/sessions/domain/session.dart';

abstract class StatooRepository {
  Future<List<Player>> getPlayers();
  Future<List<Session>> getSessions();
  Future<List<Participation>> getParticipations();
  Future<void> saveSession(Session session, List<Participation> participations);
}
