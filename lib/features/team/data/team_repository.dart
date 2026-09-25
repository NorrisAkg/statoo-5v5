import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/data/app_database.dart';
import '../domain/team_info.dart';

abstract class TeamRepository {
  Future<TeamInfo?> getTeamInfo();
  Future<void> saveTeamInfo(TeamInfo team);
}

class SqliteTeamRepository implements TeamRepository {
  SqliteTeamRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  @override
  Future<TeamInfo?> getTeamInfo() async {
    final db = await _appDatabase.database;
    final results = await db.query(
      'meta',
      where: 'key IN (?, ?, ?, ?)',
      whereArgs: ['team_name', 'team_format', 'team_location', 'team_created_at'],
    );

    if (results.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('team_name');
      if (name == null || name.isEmpty) return null;
      return TeamInfo(
        name: name,
        format: prefs.getString('team_format') ?? '5v5',
        location: prefs.getString('team_location'),
      );
    }

    final map = {
      for (final row in results) row['key']! as String: row['value'] as String?,
    };

    final name = map['team_name'];
    if (name == null || name.isEmpty) return null;

    return TeamInfo(
      name: name,
      format: map['team_format'] ?? '5v5',
      location: map['team_location'],
      createdAt: map['team_created_at'] != null
          ? DateTime.tryParse(map['team_created_at']!)
          : null,
    );
  }

  @override
  Future<void> saveTeamInfo(TeamInfo team) async {
    final db = await _appDatabase.database;
    final batch = db.batch()
      ..insert(
        'meta',
        {'key': 'team_name', 'value': team.name},
        conflictAlgorithm: ConflictAlgorithm.replace,
      )
      ..insert(
        'meta',
        {'key': 'team_format', 'value': team.format},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

    if (team.location != null) {
      batch.insert(
        'meta',
        {'key': 'team_location', 'value': team.location},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    batch.insert(
      'meta',
      {'key': 'team_created_at', 'value': (team.createdAt ?? DateTime.now()).toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await batch.commit(noResult: true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('team_name', team.name);
    await prefs.setString('team_format', team.format);
    if (team.location != null) {
      await prefs.setString('team_location', team.location!);
    }
  }
}
