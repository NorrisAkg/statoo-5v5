import '../../../core/data/app_database.dart';
import '../domain/assist_entry.dart';
import '../domain/card_entry.dart';
import '../domain/scorer_entry.dart';
import '../domain/standing_entry.dart';
import '../domain/standing_per_match_entry.dart';

abstract class RankingRepository {
  Future<List<StandingEntry>> getStandings({String? teamId});
  Future<List<StandingPerMatchEntry>> getStandingsPerMatch({String? teamId});
  Future<List<ScorerEntry>> getTopScorers({String? teamId});
  Future<List<AssistEntry>> getTopAssists({String? teamId});
  Future<List<CardEntry>> getTopCards({String? teamId, String sortBy = 'all'});
}

class SqliteRankingRepository implements RankingRepository {
  SqliteRankingRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  @override
  Future<List<StandingEntry>> getStandings({String? teamId}) async {
    final db = await _appDatabase.database;
    final sql = teamId != null
        ? 'SELECT * FROM v_standings WHERE team_id = ?'
        : 'SELECT * FROM v_standings';
    final results = await db.rawQuery(sql, teamId != null ? [teamId] : null);
    return results.map(StandingEntry.fromMap).toList();
  }

  @override
  Future<List<StandingPerMatchEntry>> getStandingsPerMatch({String? teamId}) async {
    final db = await _appDatabase.database;
    final sql = teamId != null
        ? 'SELECT * FROM v_standings_per_match WHERE team_id = ?'
        : 'SELECT * FROM v_standings_per_match';
    final results = await db.rawQuery(sql, teamId != null ? [teamId] : null);
    return results.map(StandingPerMatchEntry.fromMap).toList();
  }

  @override
  Future<List<ScorerEntry>> getTopScorers({String? teamId}) async {
    final db = await _appDatabase.database;
    final sql = teamId != null
        ? 'SELECT * FROM v_top_scorers WHERE team_id = ?'
        : 'SELECT * FROM v_top_scorers';
    final results = await db.rawQuery(sql, teamId != null ? [teamId] : null);
    return results.map(ScorerEntry.fromMap).toList();
  }

  @override
  Future<List<AssistEntry>> getTopAssists({String? teamId}) async {
    final db = await _appDatabase.database;
    final sql = teamId != null
        ? 'SELECT * FROM v_top_assists WHERE team_id = ?'
        : 'SELECT * FROM v_top_assists';
    final results = await db.rawQuery(sql, teamId != null ? [teamId] : null);
    return results.map(AssistEntry.fromMap).toList();
  }

  @override
  Future<List<CardEntry>> getTopCards({String? teamId, String sortBy = 'all'}) async {
    final db = await _appDatabase.database;
    final orderBy = switch (sortBy) {
      'yellow' => 'yellow_cards DESC, red_cards DESC, matches_played ASC, name ASC',
      'red' => 'red_cards DESC, yellow_cards DESC, matches_played ASC, name ASC',
      _ => '(red_cards * 3 + yellow_cards) DESC, red_cards DESC, yellow_cards DESC, matches_played ASC, name ASC',
    };
    final whereClause = teamId != null ? 'WHERE team_id = ?' : '';
    final results = await db.rawQuery('''
      SELECT 
        ROW_NUMBER() OVER (ORDER BY $orderBy) AS rank,
        player_id,
        name,
        nickname,
        avatar_url,
        matches_played,
        yellow_cards,
        red_cards,
        total_cards
      FROM v_top_cards
      $whereClause
      ORDER BY rank
    ''', teamId != null ? [teamId] : null);
    return results.map(CardEntry.fromMap).toList();
  }
}
