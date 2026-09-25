import '../../../core/data/app_database.dart';
import '../domain/assist_entry.dart';
import '../domain/scorer_entry.dart';
import '../domain/standing_entry.dart';
import '../domain/standing_per_match_entry.dart';

abstract class RankingRepository {
  Future<List<StandingEntry>> getStandings();
  Future<List<StandingPerMatchEntry>> getStandingsPerMatch();
  Future<List<ScorerEntry>> getTopScorers();
  Future<List<AssistEntry>> getTopAssists();
}

class SqliteRankingRepository implements RankingRepository {
  SqliteRankingRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  @override
  Future<List<StandingEntry>> getStandings() async {
    final db = await _appDatabase.database;
    final results = await db.rawQuery('SELECT * FROM v_standings');
    return results.map(StandingEntry.fromMap).toList();
  }

  @override
  Future<List<StandingPerMatchEntry>> getStandingsPerMatch() async {
    final db = await _appDatabase.database;
    final results = await db.rawQuery('SELECT * FROM v_standings_per_match');
    return results.map(StandingPerMatchEntry.fromMap).toList();
  }

  @override
  Future<List<ScorerEntry>> getTopScorers() async {
    final db = await _appDatabase.database;
    final results = await db.rawQuery('SELECT * FROM v_top_scorers');
    return results.map(ScorerEntry.fromMap).toList();
  }

  @override
  Future<List<AssistEntry>> getTopAssists() async {
    final db = await _appDatabase.database;
    final results = await db.rawQuery('SELECT * FROM v_top_assists');
    return results.map(AssistEntry.fromMap).toList();
  }
}
