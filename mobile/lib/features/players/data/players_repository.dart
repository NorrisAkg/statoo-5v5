import 'package:sqflite/sqflite.dart';
import '../../../core/data/app_database.dart';
import '../domain/player.dart';
import '../domain/player_detail_data.dart';

abstract class PlayersRepository {
  Future<List<Player>> getPlayers({String? teamId});
  Future<Player?> getPlayer(String id, {required String teamId});
  Future<PlayerDetailStats> getPlayerStats(String id, {required String teamId});
  Future<List<PlayerMatchHistoryItem>> getPlayerMatchHistory(String id, {required String teamId});
  Future<Player> createPlayer({
    required String name,
    String? nickname,
    String? avatarUrl,
    String? teamId,
  });
  Future<void> updatePlayer({
    required String id,
    required String teamId,
    required String name,
    String? nickname,
  });
  Future<void> togglePlayerActive({
    required String id,
    required String teamId,
    required bool isActive,
  });
  Future<bool> canDeletePlayer(String id, {required String teamId});
  Future<Set<String>> getDeletablePlayerIds({required String teamId});
  Future<void> deletePlayer(String id, {required String teamId});

  /// Returns true if a player with the same [name] (case-insensitive) already
  /// exists in the given [teamId]. If [excludePlayerId] is provided, that
  /// player is excluded from the check (useful for edits).
  Future<bool> isNameTaken({
    required String name,
    required String teamId,
    String? excludePlayerId,
  });
}

class SqlitePlayersRepository implements PlayersRepository {
  SqlitePlayersRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  @override
  Future<List<Player>> getPlayers({String? teamId}) async {
    if (teamId == null || teamId.isEmpty) return const [];
    final db = await _appDatabase.database;
    final rows = await db.query(
      'players',
      where: 'team_id = ?',
      whereArgs: [teamId],
      orderBy: 'is_active DESC, name ASC',
    );

    return rows.map((row) {
      return Player(
        id: row['id']! as String,
        teamId: row['team_id']! as String,
        name: row['name']! as String,
        nickname: row['nickname'] as String?,
        avatarUrl: row['avatar_url'] as String?,
        isActive: (row['is_active'] as int?) == 1,
        createdAt: DateTime.parse(row['created_at']! as String),
        updatedAt: DateTime.parse(row['updated_at']! as String),
      );
    }).toList();
  }

  @override
  Future<Player?> getPlayer(String id, {required String teamId}) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      'players',
      where: 'id = ? AND team_id = ?',
      whereArgs: [id, teamId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return Player(
      id: row['id']! as String,
      teamId: row['team_id']! as String,
      name: row['name']! as String,
      nickname: row['nickname'] as String?,
      avatarUrl: row['avatar_url'] as String?,
      isActive: (row['is_active'] as int?) == 1,
      createdAt: DateTime.parse(row['created_at']! as String),
      updatedAt: DateTime.parse(row['updated_at']! as String),
    );
  }

  @override
  Future<PlayerDetailStats> getPlayerStats(String id, {required String teamId}) async {
    final db = await _appDatabase.database;
    final rows = await db.rawQuery('''
      SELECT 
        COUNT(CASE WHEN status = 'CLOSED' AND is_ranked = 1 THEN 1 END) AS matches_played,
        COALESCE(SUM(is_win), 0) AS wins,
        COALESCE(SUM(is_draw), 0) AS draws,
        COALESCE(SUM(is_loss), 0) AS losses,
        COALESCE(SUM(points), 0) AS total_points,
        COALESCE(SUM(CASE WHEN status = 'CLOSED' THEN goals ELSE 0 END), 0) AS goals,
        COALESCE(SUM(CASE WHEN status = 'CLOSED' THEN assists ELSE 0 END), 0) AS assists,
        COALESCE(SUM(CASE WHEN status = 'CLOSED' THEN yellow_cards ELSE 0 END), 0) AS yellow_cards,
        COALESCE(SUM(CASE WHEN status = 'CLOSED' THEN red_cards ELSE 0 END), 0) AS red_cards,
        COUNT(CASE WHEN status = 'CLOSED' THEN 1 END) AS appearances
      FROM v_player_match_results
      WHERE player_id = ? AND team_id = ?
        AND player_id IN (SELECT id FROM players WHERE team_id = ?)
    ''', [id, teamId, teamId]);

    if (rows.isEmpty) {
      return const PlayerDetailStats.empty();
    }
    return PlayerDetailStats.fromMap(rows.first);
  }

  @override
  Future<List<PlayerMatchHistoryItem>> getPlayerMatchHistory(String id, {required String teamId}) async {
    final db = await _appDatabase.database;
    final rows = await db.rawQuery('''
      SELECT 
        pt.id AS participation_id,
        pt.session_id,
        pt.player_id,
        pt.team,
        pt.goals,
        pt.assists,
        pt.yellow_cards,
        pt.red_cards,
        s.played_at,
        s.status,
        s.is_ranked,
        s.score_a,
        s.score_b,
        s.result
      FROM participations pt
      JOIN sessions s ON s.id = pt.session_id
      WHERE pt.player_id = ? AND s.team_id = ?
        AND pt.player_id IN (SELECT id FROM players WHERE team_id = ?)
      ORDER BY s.played_at DESC
    ''', [id, teamId, teamId]);

    return rows.map(PlayerMatchHistoryItem.fromMap).toList();
  }

  @override
  Future<Player> createPlayer({
    required String name,
    String? nickname,
    String? avatarUrl,
    String? teamId,
  }) async {
    final db = await _appDatabase.database;
    final now = DateTime.now();

    if (teamId == null || teamId.trim().isEmpty) {
      throw ArgumentError('teamId is required to create a player');
    }
    final resolvedTeamId = teamId.trim();

    final player = Player(
      id: 'p_${now.millisecondsSinceEpoch}',
      teamId: resolvedTeamId,
      name: name.trim(),
      nickname: nickname?.trim().isNotEmpty == true ? nickname!.trim() : null,
      avatarUrl: avatarUrl,
      createdAt: now,
      updatedAt: now,
    );

    await db.insert('players', {
      'id': player.id,
      'team_id': player.teamId,
      'name': player.name,
      'nickname': player.nickname,
      'avatar_url': player.avatarUrl,
      'is_active': 1,
      'created_at': player.createdAt.toIso8601String(),
      'updated_at': player.updatedAt.toIso8601String(),
    });

    return player;
  }

  @override
  Future<void> updatePlayer({
    required String id,
    required String teamId,
    required String name,
    String? nickname,
  }) async {
    final db = await _appDatabase.database;
    await db.update(
      'players',
      {
        'name': name.trim(),
        'nickname': (nickname != null && nickname.trim().isNotEmpty) ? nickname.trim() : null,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ? AND team_id = ?',
      whereArgs: [id, teamId],
    );
  }

  @override
  Future<void> togglePlayerActive({
    required String id,
    required String teamId,
    required bool isActive,
  }) async {
    final db = await _appDatabase.database;
    await db.update(
      'players',
      {
        'is_active': isActive ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ? AND team_id = ?',
      whereArgs: [id, teamId],
    );
  }

  @override
  Future<bool> canDeletePlayer(String id, {required String teamId}) async {
    final db = await _appDatabase.database;
    final count = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM participations WHERE player_id = ?',
      [id],
    )) ?? 0;
    if (count > 0) return false;
    // Only a player of this group can be deleted.
    final owned = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM players WHERE id = ? AND team_id = ?',
      [id, teamId],
    )) ?? 0;
    return owned > 0;
  }

  @override
  Future<Set<String>> getDeletablePlayerIds({required String teamId}) async {
    final db = await _appDatabase.database;
    final rows = await db.rawQuery('''
      SELECT id FROM players 
      WHERE team_id = ? AND id NOT IN (SELECT DISTINCT player_id FROM participations)
    ''', [teamId]);
    return rows.map((r) => r['id']! as String).toSet();
  }

  @override
  Future<void> deletePlayer(String id, {required String teamId}) async {
    final db = await _appDatabase.database;
    await db.delete('players', where: 'id = ? AND team_id = ?', whereArgs: [id, teamId]);
  }

  @override
  Future<bool> isNameTaken({
    required String name,
    required String teamId,
    String? excludePlayerId,
  }) async {
    final db = await _appDatabase.database;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;

    final where = StringBuffer('team_id = ? AND name = ? COLLATE NOCASE');
    final args = <Object>[teamId, trimmed];

    if (excludePlayerId != null) {
      where.write(' AND id != ?');
      args.add(excludePlayerId);
    }

    final count = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM players WHERE $where',
        args,
      ),
    ) ?? 0;
    return count > 0;
  }
}
