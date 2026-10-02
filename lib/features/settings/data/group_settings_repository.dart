import 'package:sqflite/sqflite.dart';

import '../../../core/data/app_database.dart';

/// Réglages entiers propres à un groupe, stockés dans `meta` sous `<clé>_<teamId>`.
abstract class GroupSettingsRepository {
  Future<int?> getInt(String teamId, String key);
  Future<void> setInt(String teamId, String key, int value);
}

String groupSettingKey(String key, String teamId) => '${key}_$teamId';

class SqliteGroupSettingsRepository implements GroupSettingsRepository {
  SqliteGroupSettingsRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  @override
  Future<int?> getInt(String teamId, String key) async {
    if (teamId.isEmpty) return null;
    final db = await _appDatabase.database;
    final rows = await db.query(
      'meta',
      where: 'key = ?',
      whereArgs: [groupSettingKey(key, teamId)],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return int.tryParse('${rows.first['value']}');
  }

  @override
  Future<void> setInt(String teamId, String key, int value) async {
    if (teamId.isEmpty) throw StateError('No active team selected');
    final db = await _appDatabase.database;
    await db.insert(
      'meta',
      {'key': groupSettingKey(key, teamId), 'value': '$value'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
