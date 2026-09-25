import '../../../core/data/app_database.dart';
import '../domain/group_totals.dart';

abstract class StatsRepository {
  Future<GroupTotals> getGroupTotals();
}

class SqliteStatsRepository implements StatsRepository {
  SqliteStatsRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  @override
  Future<GroupTotals> getGroupTotals() async {
    final db = await _appDatabase.database;
    final results = await db.rawQuery('SELECT * FROM v_group_totals LIMIT 1');
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
