import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/data/app_database.dart';
import '../domain/team_info.dart';

abstract class TeamRepository {
  Future<TeamInfo?> getTeamInfo();
  Future<List<TeamInfo>> getAllTeams();
  Future<TeamInfo?> getTeamById(String id);
  Future<TeamInfo?> getActiveTeam();
  Future<String?> getActiveTeamId();
  Future<void> setActiveTeamId(String id);
  Future<void> saveTeamInfo(TeamInfo team);
  Future<void> deleteTeam(String id);
  Future<Map<String, int>> getTeamCounts(String teamId);
}

class SqliteTeamRepository implements TeamRepository {
  SqliteTeamRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  @override
  Future<TeamInfo?> getTeamInfo() => getActiveTeam();

  @override
  Future<List<TeamInfo>> getAllTeams() async {
    final db = await _appDatabase.database;
    final results = await db.query('teams', orderBy: 'created_at ASC');
    return await Future.wait(results.map((row) => _readTeam(db, row)));
  }

  @override
  Future<TeamInfo?> getTeamById(String id) async {
    final db = await _appDatabase.database;
    final results = await db.query('teams', where: 'id = ?', whereArgs: [id], limit: 1);
    if (results.isEmpty) return null;
    return await _readTeam(db, results.first);
  }

  Future<TeamInfo> _readTeam(DatabaseExecutor db, Map<String, Object?> row) async {
    final values = await db.query('meta', where: 'key = ?', whereArgs: ['team_short_name_${row['id']}']);
    return TeamInfo.fromMap({...row, 'short_name': values.isEmpty ? '' : values.single['value']});
  }

  @override
  Future<String?> getActiveTeamId() async {
    final db = await _appDatabase.database;
    final results = await db.query('meta', where: 'key = ?', whereArgs: ['active_team_id'], limit: 1);
    if (results.isNotEmpty) {
      final val = results.first['value'] as String?;
      if (val != null && val.isNotEmpty) return val;
    }

    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('active_team_id');
  }

  @override
  Future<void> setActiveTeamId(String id) async {
    final db = await _appDatabase.database;
    await db.insert(
      'meta',
      {'key': 'active_team_id', 'value': id},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_team_id', id);
  }

  @override
  Future<TeamInfo?> getActiveTeam() async {
    final activeId = await getActiveTeamId();
    if (activeId != null) {
      final team = await getTeamById(activeId);
      if (team != null) return team;
    }

    // Si aucun ID actif ou équipe introuvable, prendre la première équipe
    final allTeams = await getAllTeams();
    if (allTeams.isNotEmpty) {
      final first = allTeams.first;
      await setActiveTeamId(first.id);
      return first;
    }

    // Rétrocompatibilité avec SharedPreferences si migration
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('team_name');
    if (name == null || name.isEmpty) return null;
    final fallback = TeamInfo(
      id: 'team_1',
      name: name,
      format: prefs.getString('team_format') ?? '5v5',
      location: prefs.getString('team_location'),
      createdAt: DateTime.now(),
    );
    await saveTeamInfo(fallback);
    return fallback;
  }

  @override
  Future<void> saveTeamInfo(TeamInfo team) async {
    if (team.shortName.trim().length > 30) throw ArgumentError('Nom court : 30 caractères maximum.');
    final db = await _appDatabase.database;
    final row = team.toMap()..remove('short_name');
    await db.transaction((txn) async {
      final existing = await txn.query('teams', columns: ['id'], where: 'id = ?', whereArgs: [team.id]);
      if (existing.isEmpty) {
        await txn.insert('teams', row);
      } else {
        await txn.update('teams', row, where: 'id = ?', whereArgs: [team.id]);
      }
      await txn.insert('meta', {'key':'team_short_name_${team.id}', 'value':team.shortName.trim()}, conflictAlgorithm: ConflictAlgorithm.replace);
    });

    // Mettre cette équipe comme active si aucune n'est active
    final currentActiveId = await getActiveTeamId();
    if (currentActiveId == null) {
      await setActiveTeamId(team.id);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('team_name', team.name);
    await prefs.setString('team_format', team.format);
    if (team.location != null) {
      await prefs.setString('team_location', team.location!);
    } else {
      await prefs.remove('team_location');
    }
  }

  @override
  Future<void> deleteTeam(String id) async {
    final db = await _appDatabase.database;
    await db.delete('teams', where: 'id = ?', whereArgs: [id]);
    // Per-group settings live in `meta` and are not covered by the FK cascade.
    await db.delete(
      'meta',
      where: 'key IN (?, ?, ?, ?, ?)',
      whereArgs: [
        'active_session_id_$id',
        'team_short_name_$id',
        'mvp_weights_$id',
        'min_players_per_session_$id',
        'tournament_draw_points_$id',
      ],
    );

    final currentActiveId = await getActiveTeamId();
    if (currentActiveId == id) {
      final all = await getAllTeams();
      if (all.isNotEmpty) {
        await setActiveTeamId(all.first.id);
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('active_team_id');
        await db.delete('meta', where: 'key = ?', whereArgs: ['active_team_id']);
      }
    }
  }

  @override
  Future<Map<String, int>> getTeamCounts(String teamId) async {
    final db = await _appDatabase.database;
    final pRes = await db.rawQuery('SELECT COUNT(*) as c FROM players WHERE team_id = ?', [teamId]);
    final sRes = await db.rawQuery('SELECT COUNT(*) as c FROM sessions WHERE team_id = ?', [teamId]);

    final playersCount = Sqflite.firstIntValue(pRes) ?? 0;
    final sessionsCount = Sqflite.firstIntValue(sRes) ?? 0;

    return {
      'players': playersCount,
      'sessions': sessionsCount,
    };
  }
}
