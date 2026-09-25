import '../../../core/data/app_database.dart';
import '../domain/player.dart';

abstract class PlayersRepository {
  Future<List<Player>> getPlayers();
  Future<Player> createPlayer({
    required String name,
    String? nickname,
    String? avatarUrl,
  });
  Future<void> deletePlayer(String id);
}

class SqlitePlayersRepository implements PlayersRepository {
  SqlitePlayersRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  @override
  Future<List<Player>> getPlayers() async {
    final db = await _appDatabase.database;
    final rows = await db.query('players', orderBy: 'is_active DESC, name ASC');

    return rows.map((row) {
      return Player(
        id: row['id']! as String,
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
  Future<Player> createPlayer({
    required String name,
    String? nickname,
    String? avatarUrl,
  }) async {
    final db = await _appDatabase.database;
    final now = DateTime.now();
    final player = Player(
      id: 'p_${now.millisecondsSinceEpoch}',
      name: name.trim(),
      nickname: nickname?.trim().isNotEmpty == true ? nickname!.trim() : null,
      avatarUrl: avatarUrl,
      createdAt: now,
      updatedAt: now,
    );

    await db.insert('players', {
      'id': player.id,
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
  Future<void> deletePlayer(String id) async {
    final db = await _appDatabase.database;
    await db.delete('players', where: 'id = ?', whereArgs: [id]);
  }
}
