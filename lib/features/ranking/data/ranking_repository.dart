import '../../../core/data/app_database.dart';
import '../domain/assist_entry.dart';
import '../domain/card_entry.dart';
import '../domain/scorer_entry.dart';
import '../domain/standing_entry.dart';
import '../domain/standing_per_match_entry.dart';

abstract class RankingRepository {
  Future<List<StandingEntry>> getStandings();
  Future<List<StandingPerMatchEntry>> getStandingsPerMatch();
  Future<List<ScorerEntry>> getTopScorers();
  Future<List<AssistEntry>> getTopAssists();
  Future<List<CardEntry>> getTopCards({String sortBy = 'all'});
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

  @override
  Future<List<CardEntry>> getTopCards({String sortBy = 'all'}) async {
    final db = await _appDatabase.database;
    final orderBy = switch (sortBy) {
      'yellow' => 'yellow_cards DESC, red_cards DESC, matches_played ASC, name ASC',
      'red' => 'red_cards DESC, yellow_cards DESC, matches_played ASC, name ASC',
      _ => '(red_cards * 3 + yellow_cards) DESC, red_cards DESC, yellow_cards DESC, matches_played ASC, name ASC',
    };
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
      ORDER BY rank
    ''');
    return results.map(CardEntry.fromMap).toList();
  }
}
