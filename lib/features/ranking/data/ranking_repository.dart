import '../../../core/data/app_database.dart';
import '../domain/assist_entry.dart';
import '../domain/card_entry.dart';
import '../domain/mvp_calculator.dart';
import '../domain/mvp_entry.dart';
import '../domain/scorer_entry.dart';
import '../domain/standing_entry.dart';
import '../domain/standing_per_match_entry.dart';

abstract class RankingRepository {
  Future<List<String>> getAvailableMonths({String? teamId});
  Future<List<StandingEntry>> getStandings({String? teamId, String? month});
  Future<List<StandingPerMatchEntry>> getStandingsPerMatch({String? teamId});
  Future<List<ScorerEntry>> getTopScorers({String? teamId, String? month});
  Future<List<AssistEntry>> getTopAssists({String? teamId, String? month});
  Future<List<CardEntry>> getTopCards({String? teamId, String sortBy = 'all', String? month});
  Future<List<MvpEntry>> getMvpRanking({required String month, String? teamId});
  Future<MvpEntry?> getPlayerOfTheMonth({String? teamId, String? month});
}

class SqliteRankingRepository implements RankingRepository {
  SqliteRankingRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  @override
  Future<List<String>> getAvailableMonths({String? teamId}) async {
    if (teamId == null || teamId.isEmpty) return const [];
    final db = await _appDatabase.database;
    final results = await db.rawQuery('''
      SELECT DISTINCT substr(played_at, 1, 7) AS month
      FROM sessions
      WHERE team_id = ? AND status = 'CLOSED' AND is_ranked = 1
      ORDER BY month DESC
    ''', [teamId]);

    return results
        .map((r) => r['month'] as String?)
        .where((m) => m != null && m.isNotEmpty)
        .cast<String>()
        .toList();
  }

  @override
  Future<List<StandingEntry>> getStandings({String? teamId, String? month}) async {
    if (teamId == null || teamId.isEmpty) return const [];
    final db = await _appDatabase.database;

    if (month == null || month.isEmpty) {
      final results = await db.rawQuery(
        'SELECT * FROM v_standings WHERE team_id = ?',
        [teamId],
      );
      return results.map(StandingEntry.fromMap).toList();
    }

    final results = await db.rawQuery('''
      WITH player_aggregates AS (
        SELECT 
          pl.id AS player_id,
          pl.team_id,
          pl.name,
          pl.nickname,
          pl.avatar_url,
          pl.is_active,
          COUNT(pm.participation_id) AS matches_played,
          COALESCE(SUM(pm.is_win), 0) AS wins,
          COALESCE(SUM(pm.is_draw), 0) AS draws,
          COALESCE(SUM(pm.is_loss), 0) AS losses,
          COALESCE(SUM(pm.points), 0) AS points,
          COALESCE(SUM(pm.goals), 0) AS goals,
          COALESCE(SUM(pm.assists), 0) AS assists
        FROM players pl
        JOIN v_player_match_results pm ON pm.player_id = pl.id
        JOIN sessions s ON s.id = pm.session_id
        WHERE pl.team_id = ? AND s.status = 'CLOSED' AND s.is_ranked = 1 AND substr(s.played_at, 1, 7) = ?
        GROUP BY pl.id, pl.team_id, pl.name, pl.nickname, pl.avatar_url, pl.is_active
      )
      SELECT 
        ROW_NUMBER() OVER (ORDER BY points DESC, wins DESC, matches_played DESC, name ASC) AS rank,
        player_id,
        team_id,
        name,
        nickname,
        avatar_url,
        is_active,
        matches_played,
        wins,
        draws,
        losses,
        points,
        goals,
        assists
      FROM player_aggregates
      ORDER BY rank
    ''', [teamId, month]);

    return results.map(StandingEntry.fromMap).toList();
  }

  @override
  Future<List<StandingPerMatchEntry>> getStandingsPerMatch({String? teamId}) async {
    if (teamId == null || teamId.isEmpty) return const [];
    final db = await _appDatabase.database;
    final results = await db.rawQuery(
      'SELECT * FROM v_standings_per_match WHERE team_id = ?',
      [teamId],
    );
    return results.map(StandingPerMatchEntry.fromMap).toList();
  }

  @override
  Future<List<ScorerEntry>> getTopScorers({String? teamId, String? month}) async {
    if (teamId == null || teamId.isEmpty) return const [];
    final db = await _appDatabase.database;

    if (month == null || month.isEmpty) {
      final results = await db.rawQuery(
        'SELECT * FROM v_top_scorers WHERE team_id = ?',
        [teamId],
      );
      return results.map(ScorerEntry.fromMap).toList();
    }

    final results = await db.rawQuery('''
      WITH scorer_aggregates AS (
        SELECT 
          pl.id AS player_id,
          pl.team_id,
          pl.name,
          pl.nickname,
          pl.avatar_url,
          COUNT(s.id) AS matches_played,
          COALESCE(SUM(pt.goals), 0) AS goals
        FROM players pl
        JOIN participations pt ON pt.player_id = pl.id
        JOIN sessions s ON s.id = pt.session_id
        WHERE pl.team_id = ? AND s.status = 'CLOSED' AND substr(s.played_at, 1, 7) = ?
        GROUP BY pl.id, pl.team_id, pl.name, pl.nickname, pl.avatar_url
      )
      SELECT 
        ROW_NUMBER() OVER (ORDER BY goals DESC, matches_played ASC, name ASC) AS rank,
        player_id,
        team_id,
        name,
        nickname,
        avatar_url,
        matches_played,
        goals
      FROM scorer_aggregates
      WHERE goals > 0 OR matches_played > 0
      ORDER BY rank
    ''', [teamId, month]);

    return results.map(ScorerEntry.fromMap).toList();
  }

  @override
  Future<List<AssistEntry>> getTopAssists({String? teamId, String? month}) async {
    if (teamId == null || teamId.isEmpty) return const [];
    final db = await _appDatabase.database;

    if (month == null || month.isEmpty) {
      final results = await db.rawQuery(
        'SELECT * FROM v_top_assists WHERE team_id = ?',
        [teamId],
      );
      return results.map(AssistEntry.fromMap).toList();
    }

    final results = await db.rawQuery('''
      WITH assist_aggregates AS (
        SELECT 
          pl.id AS player_id,
          pl.team_id,
          pl.name,
          pl.nickname,
          pl.avatar_url,
          COUNT(s.id) AS matches_played,
          COALESCE(SUM(pt.assists), 0) AS assists
        FROM players pl
        JOIN participations pt ON pt.player_id = pl.id
        JOIN sessions s ON s.id = pt.session_id
        WHERE pl.team_id = ? AND s.status = 'CLOSED' AND substr(s.played_at, 1, 7) = ?
        GROUP BY pl.id, pl.team_id, pl.name, pl.nickname, pl.avatar_url
      )
      SELECT 
        ROW_NUMBER() OVER (ORDER BY assists DESC, matches_played ASC, name ASC) AS rank,
        player_id,
        team_id,
        name,
        nickname,
        avatar_url,
        matches_played,
        assists
      FROM assist_aggregates
      WHERE assists > 0 OR matches_played > 0
      ORDER BY rank
    ''', [teamId, month]);

    return results.map(AssistEntry.fromMap).toList();
  }

  @override
  Future<List<CardEntry>> getTopCards({String? teamId, String sortBy = 'all', String? month}) async {
    if (teamId == null || teamId.isEmpty) return const [];
    final db = await _appDatabase.database;
    final orderBy = switch (sortBy) {
      'yellow' => 'yellow_cards DESC, red_cards DESC, matches_played ASC, name ASC',
      'red' => 'red_cards DESC, yellow_cards DESC, matches_played ASC, name ASC',
      _ => '(red_cards * 3 + yellow_cards) DESC, red_cards DESC, yellow_cards DESC, matches_played ASC, name ASC',
    };

    if (month == null || month.isEmpty) {
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
        WHERE team_id = ?
        ORDER BY rank
      ''', [teamId]);
      return results.map(CardEntry.fromMap).toList();
    }

    final results = await db.rawQuery('''
      WITH card_aggregates AS (
        SELECT 
          pl.id AS player_id,
          pl.team_id,
          pl.name,
          pl.nickname,
          pl.avatar_url,
          COUNT(s.id) AS matches_played,
          COALESCE(SUM(pt.yellow_cards), 0) AS yellow_cards,
          COALESCE(SUM(pt.red_cards), 0) AS red_cards,
          COALESCE(SUM(pt.yellow_cards + pt.red_cards), 0) AS total_cards
        FROM players pl
        JOIN participations pt ON pt.player_id = pl.id
        JOIN sessions s ON s.id = pt.session_id
        WHERE pl.team_id = ? AND s.status = 'CLOSED' AND substr(s.played_at, 1, 7) = ?
        GROUP BY pl.id, pl.team_id, pl.name, pl.nickname, pl.avatar_url
      )
      SELECT 
        ROW_NUMBER() OVER (ORDER BY $orderBy) AS rank,
        player_id,
        team_id,
        name,
        nickname,
        avatar_url,
        matches_played,
        yellow_cards,
        red_cards,
        total_cards
      FROM card_aggregates
      WHERE total_cards > 0 OR matches_played > 0
      ORDER BY rank
    ''', [teamId, month]);

    return results.map(CardEntry.fromMap).toList();
  }

  @override
  Future<List<MvpEntry>> getMvpRanking({required String month, String? teamId}) async {
    if (teamId == null || teamId.isEmpty || month.isEmpty) return const [];
    final db = await _appDatabase.database;

    // 1. Count total ranked closed sessions in that month
    final sessionCountResults = await db.rawQuery('''
      SELECT COUNT(*) AS total
      FROM sessions
      WHERE team_id = ? AND status = 'CLOSED' AND is_ranked = 1 AND substr(played_at, 1, 7) = ?
    ''', [teamId, month]);

    final totalSessions = (sessionCountResults.first['total'] as num?)?.toInt() ?? 0;
    if (totalSessions == 0) return const [];

    // 2. Fetch raw aggregate stats per player in that month
    final rows = await db.rawQuery('''
      SELECT 
        pl.id AS player_id,
        pl.name,
        pl.nickname,
        pl.avatar_url,
        pl.is_active,
        COUNT(pm.participation_id) AS matches_played,
        COALESCE(SUM(pm.is_win), 0) AS wins,
        COALESCE(SUM(pm.is_draw), 0) AS draws,
        COALESCE(SUM(pm.is_loss), 0) AS losses,
        COALESCE(SUM(pm.goals), 0) AS goals,
        COALESCE(SUM(pm.assists), 0) AS assists,
        COALESCE(SUM(pm.yellow_cards), 0) AS yellow_cards,
        COALESCE(SUM(pm.red_cards), 0) AS red_cards,
        COALESCE(SUM(
          (pm.is_win * 10.0) +
          (pm.is_draw * 3.0) +
          (pm.goals * 2.0) +
          (pm.assists * 1.0) -
          (pm.yellow_cards * 0.5) -
          (pm.red_cards * 1.0)
        ), 0.0) AS total_score
      FROM players pl
      JOIN v_player_match_results pm ON pm.player_id = pl.id
      JOIN sessions s ON s.id = pm.session_id
      WHERE pl.team_id = ? AND s.status = 'CLOSED' AND s.is_ranked = 1 AND substr(s.played_at, 1, 7) = ?
      GROUP BY pl.id, pl.name, pl.nickname, pl.avatar_url, pl.is_active
    ''', [teamId, month]);

    final entries = <MvpEntry>[];

    for (final row in rows) {
      final matchesPlayed = (row['matches_played'] as num?)?.toInt() ?? 0;
      final totalScore = (row['total_score'] as num?)?.toDouble() ?? 0.0;
      final score = MvpCalculator.calculateAverageScore(
        totalScore: totalScore,
        matchesPlayed: matchesPlayed,
      );
      final isEligible = MvpCalculator.isEligible(
        matchesPlayed: matchesPlayed,
        totalSessions: totalSessions,
      );
      final missingMatches = MvpCalculator.missingMatches(
        matchesPlayed: matchesPlayed,
        totalSessions: totalSessions,
      );

      entries.add(
        MvpEntry(
          rank: 0,
          playerId: row['player_id']! as String,
          name: row['name']! as String,
          nickname: (row['nickname'] as String?)?.isNotEmpty == true ? row['nickname']! as String : null,
          avatarUrl: row['avatar_url'] as String?,
          isActive: (row['is_active'] as num?)?.toInt() != 0,
          matchesPlayed: matchesPlayed,
          totalSessions: totalSessions,
          wins: (row['wins'] as num?)?.toInt() ?? 0,
          draws: (row['draws'] as num?)?.toInt() ?? 0,
          losses: (row['losses'] as num?)?.toInt() ?? 0,
          goals: (row['goals'] as num?)?.toInt() ?? 0,
          assists: (row['assists'] as num?)?.toInt() ?? 0,
          yellowCards: (row['yellow_cards'] as num?)?.toInt() ?? 0,
          redCards: (row['red_cards'] as num?)?.toInt() ?? 0,
          score: score,
          isEligible: isEligible,
          missingMatches: missingMatches,
        ),
      );
    }

    // Sort: 
    // 1. isEligible DESC
    // 2. score DESC
    // 3. matchesPlayed DESC
    // 4. goals DESC
    // 5. assists DESC
    // 6. name ASC
    entries.sort((a, b) {
      if (a.isEligible != b.isEligible) {
        return a.isEligible ? -1 : 1;
      }
      final scoreComp = b.score.compareTo(a.score);
      if (scoreComp != 0) return scoreComp;

      final matchesComp = b.matchesPlayed.compareTo(a.matchesPlayed);
      if (matchesComp != 0) return matchesComp;

      final goalsComp = b.goals.compareTo(a.goals);
      if (goalsComp != 0) return goalsComp;

      final assistsComp = b.assists.compareTo(a.assists);
      if (assistsComp != 0) return assistsComp;

      return a.name.compareTo(b.name);
    });

    // Assign final ranks
    return [
      for (var i = 0; i < entries.length; i++)
        MvpEntry(
          rank: i + 1,
          playerId: entries[i].playerId,
          name: entries[i].name,
          nickname: entries[i].nickname,
          avatarUrl: entries[i].avatarUrl,
          isActive: entries[i].isActive,
          matchesPlayed: entries[i].matchesPlayed,
          totalSessions: entries[i].totalSessions,
          wins: entries[i].wins,
          draws: entries[i].draws,
          losses: entries[i].losses,
          goals: entries[i].goals,
          assists: entries[i].assists,
          yellowCards: entries[i].yellowCards,
          redCards: entries[i].redCards,
          score: entries[i].score,
          isEligible: entries[i].isEligible,
          missingMatches: entries[i].missingMatches,
          month: month,
        ),
    ];
  }

  @override
  Future<MvpEntry?> getPlayerOfTheMonth({String? teamId, String? month}) async {
    if (teamId == null || teamId.isEmpty) return null;

    if (month != null && month.isNotEmpty) {
      final mvpList = await getMvpRanking(month: month, teamId: teamId);
      return mvpList.where((e) => e.isEligible).firstOrNull;
    }

    final availableMonths = await getAvailableMonths(teamId: teamId);
    for (final m in availableMonths) {
      final mvpList = await getMvpRanking(month: m, teamId: teamId);
      final eligible = mvpList.where((e) => e.isEligible).firstOrNull;
      if (eligible != null) {
        return eligible;
      }
    }
    return null;
  }
}
