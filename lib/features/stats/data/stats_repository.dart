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
    if (teamId == null || teamId.isEmpty) return const GroupTotals.empty();
    final db = await _appDatabase.database;
    final results = await db.rawQuery(
      'SELECT * FROM v_group_totals WHERE team_id = ? LIMIT 1',
      [teamId],
    );
    if (results.isEmpty) {
      return const GroupTotals.empty();
    }
    return GroupTotals.fromMap(results.first);
  }
}
