import '../../../core/data/app_database.dart';
import '../domain/group_totals.dart';

abstract class StatsRepository {
  Future<GroupTotals> getGroupTotals({String? teamId});
}

class SqliteStatsRepository implements StatsRepository {
  SqliteStatsRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  @override
  Future<GroupTotals> getGroupTotals({String? teamId}) async {
    final db = await _appDatabase.database;
    final sql = teamId != null
        ? 'SELECT * FROM v_group_totals WHERE team_id = ? LIMIT 1'
        : 'SELECT * FROM v_group_totals LIMIT 1';
    final results = await db.rawQuery(sql, teamId != null ? [teamId] : null);
    if (results.isEmpty) {
      return const GroupTotals(
        totalSessions: 0,
        rankedSessions: 0,
        friendlySessions: 0,
        totalPlayers: 0,
        activePlayers: 0,
        totalGoals: 0,
        avgGoalsPerSession: 0,
        totalAssists: 0,
        totalYellowCards: 0,
        totalRedCards: 0,
        totalPlayerGoals: 0,
        unassignedGoalsDifference: 0,
      );
    }
    return GroupTotals.fromMap(results.first);
  }
}
