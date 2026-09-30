import 'package:sqflite/sqflite.dart';
import '../../../core/data/app_database.dart';
import '../domain/participation.dart';
import '../domain/session.dart';
import '../domain/session_summary.dart';

abstract class SessionsRepository {
  Future<List<SessionSummaryItem>> getSessionSummaries({
    required String teamId,
    String filter = 'all',
  });
  Future<Session?> getSession(String id);
  Future<List<SessionParticipantDetail>> getSessionParticipants(String sessionId);
  Future<Session?> getActiveDraftSession({required String teamId});
  Future<String?> getActiveSessionId({required String teamId});
  Future<void> setActiveSessionId(String? sessionId, {required String teamId});
  Future<void> saveSession(
    Session session,
    List<Participation> participations, {
    required String teamId,
  });
  Future<void> updateSessionScore({
    required String sessionId,
    required int scoreA,
    required int scoreB,
  });
  Future<void> incrementScore({
    required String sessionId,
    required String teamId,
    required Team team,
    required int delta,
  });
  Future<void> updateUnassignedGoals({
    required String sessionId,
    required String teamId,
    int? unassignedGoalsA,
    int? unassignedGoalsB,
  });
  Future<void> updateParticipationStats({
    required String participationId,
    required int goals,
    required int assists,
    required int yellowCards,
    required int redCards,
  });
  Future<void> addParticipations({
    required String sessionId,
    required List<Participation> participations,
  });
  /// Returns false when nothing was closed (unknown session, other team, or no score).
  Future<bool> closeSession(String sessionId, {required String teamId});
  Future<void> reopenSession(String sessionId);
  Future<void> deleteSession(String sessionId, {required String teamId});
}

class SqliteSessionsRepository implements SessionsRepository {
  SqliteSessionsRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  SessionStatus _parseStatus(String val) =>
      val == 'CLOSED' ? SessionStatus.closed : SessionStatus.draft;

  String _statusToString(SessionStatus s) =>
      s == SessionStatus.closed ? 'CLOSED' : 'DRAFT';

  SplitMode _parseSplitMode(String? val) {
    return switch (val) {
      'RANDOM_ADJUSTED' => SplitMode.randomAdjusted,
      'MANUAL' => SplitMode.manual,
      _ => SplitMode.random,
    };
  }

  String _splitModeToString(SplitMode m) {
    return switch (m) {
      SplitMode.randomAdjusted => 'RANDOM_ADJUSTED',
      SplitMode.manual => 'MANUAL',
      SplitMode.random => 'RANDOM',
    };
  }

  MatchResult? _parseResult(String? val) {
    return switch (val) {
      'A' => MatchResult.teamA,
      'B' => MatchResult.teamB,
      'DRAW' => MatchResult.draw,
      _ => null,
    };
  }

  String? _resultToString(MatchResult? r) {
    return switch (r) {
      MatchResult.teamA => 'A',
      MatchResult.teamB => 'B',
      MatchResult.draw => 'DRAW',
      null => null,
    };
  }

  Team _parseTeam(String val) => val == 'B' ? Team.b : Team.a;
  String _teamToString(Team t) => t == Team.b ? 'B' : 'A';

  Session _mapSessionRow(Map<String, dynamic> row) {
    return Session(
      id: row['id']! as String,
      playedAt: DateTime.parse(row['played_at']! as String),
      status: _parseStatus(row['status']! as String),
      splitMode: _parseSplitMode(row['split_mode'] as String?),
      allowUnevenTeams: (row['allow_uneven_teams'] as int?) == 1,
      isRanked: (row['is_ranked'] as int?) == 1,
      scoreA: row['score_a'] as int?,
      scoreB: row['score_b'] as int?,
      result: _parseResult(row['result'] as String?),
      unassignedGoalsA: (row['unassigned_goals_a'] as int?) ?? 0,
      unassignedGoalsB: (row['unassigned_goals_b'] as int?) ?? 0,
      notes: row['notes'] as String?,
    );
  }

  /// Clé meta scopée par team pour l'active session
  String _activeSessionKey(String teamId) => 'active_session_id_$teamId';

  @override
  Future<String?> getActiveSessionId({required String teamId}) async {
    final db = await _appDatabase.database;
    final key = _activeSessionKey(teamId);
    final metaRows = await db.query(
      'meta',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (metaRows.isEmpty) return null;
    final activeId = metaRows.first['value'] as String?;
    if (activeId == null) return null;

    // Verify session still exists, has DRAFT status, and belongs to this team
    final sessionRows = await db.query(
      'sessions',
      columns: ['status'],
      where: 'id = ? AND team_id = ?',
      whereArgs: [activeId, teamId],
      limit: 1,
    );
    if (sessionRows.isEmpty || sessionRows.first['status'] != 'DRAFT') {
      await db.delete('meta', where: 'key = ?', whereArgs: [key]);
      return null;
    }
    return activeId;
  }

  @override
  Future<void> setActiveSessionId(String? sessionId, {required String teamId}) async {
    final db = await _appDatabase.database;
    final key = _activeSessionKey(teamId);
    if (sessionId != null) {
      await db.insert(
        'meta',
        {'key': key, 'value': sessionId},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      await db.delete('meta', where: 'key = ?', whereArgs: [key]);
    }
  }

  @override
  Future<List<SessionSummaryItem>> getSessionSummaries({
    required String teamId,
    String filter = 'all',
  }) async {
    final db = await _appDatabase.database;
    final activeId = await getActiveSessionId(teamId: teamId);

    // Base filter always scoped to the team
    final conditions = <String>['s.team_id = ?'];
    final args = <dynamic>[teamId];

    if (filter == 'ranked') {
      conditions.add('s.is_ranked = 1');
    } else if (filter == 'friendly') {
      conditions.add('s.is_ranked = 0');
    } else if (filter == 'draft') {
      conditions.add("s.status = 'DRAFT'");
    }

    final whereClause = 'WHERE ${conditions.join(' AND ')}';

    final rows = await db.rawQuery('''
      SELECT 
        s.*,
        COUNT(pt.id) as player_count,
        COALESCE(SUM(CASE WHEN pt.team = 'A' THEN pt.goals ELSE 0 END), 0) as goals_a,
        COALESCE(SUM(CASE WHEN pt.team = 'B' THEN pt.goals ELSE 0 END), 0) as goals_b
      FROM sessions s
      LEFT JOIN participations pt ON pt.session_id = s.id
      $whereClause
      GROUP BY s.id
      ORDER BY s.played_at DESC
    ''', args);

    return rows.map((r) {
      final session = _mapSessionRow(r);
      return SessionSummaryItem(
        session: session,
        playerCount: (r['player_count'] as num?)?.toInt() ?? 0,
        totalGoalsAssignedA: (r['goals_a'] as num?)?.toInt() ?? 0,
        totalGoalsAssignedB: (r['goals_b'] as num?)?.toInt() ?? 0,
        isActiveSession: session.id == activeId,
      );
    }).toList();
  }

  @override
  Future<Session?> getSession(String id) async {
    final db = await _appDatabase.database;
    final rows = await db.query('sessions', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return _mapSessionRow(rows.first);
  }

  @override
  Future<List<SessionParticipantDetail>> getSessionParticipants(String sessionId) async {
    final db = await _appDatabase.database;
    final rows = await db.rawQuery('''
      SELECT 
        pt.id as participation_id,
        pt.session_id,
        pt.player_id,
        pt.team,
        pt.goals,
        pt.assists,
        pt.yellow_cards,
        pt.red_cards,
        p.name as player_name,
        p.nickname as player_nickname,
        p.avatar_url as player_avatar_url
      FROM participations pt
      JOIN players p ON p.id = pt.player_id
      WHERE pt.session_id = ?
      ORDER BY pt.team ASC, p.name ASC
    ''', [sessionId]);

    return rows.map((r) {
      final part = Participation(
        id: r['participation_id']! as String,
        sessionId: r['session_id']! as String,
        playerId: r['player_id']! as String,
        team: _parseTeam(r['team']! as String),
        goals: (r['goals'] as num?)?.toInt() ?? 0,
        assists: (r['assists'] as num?)?.toInt() ?? 0,
        yellowCards: (r['yellow_cards'] as num?)?.toInt() ?? 0,
        redCards: (r['red_cards'] as num?)?.toInt() ?? 0,
      );
      return SessionParticipantDetail(
        participation: part,
        playerName: r['player_name']! as String,
        playerNickname: r['player_nickname'] as String?,
        playerAvatarUrl: r['player_avatar_url'] as String?,
      );
    }).toList();
  }

  @override
  Future<Session?> getActiveDraftSession({required String teamId}) async {
    final activeId = await getActiveSessionId(teamId: teamId);
    if (activeId == null) return null;
    return await getSession(activeId);
  }

  @override
  Future<void> saveSession(
    Session session,
    List<Participation> participations, {
    required String teamId,
  }) async {
    final db = await _appDatabase.database;
    await db.transaction((txn) async {
      await txn.insert(
        'sessions',
        {
          'id': session.id,
          'team_id': teamId,
          'played_at': session.playedAt.toIso8601String(),
          'status': _statusToString(session.status),
          'split_mode': _splitModeToString(session.splitMode),
          'allow_uneven_teams': session.allowUnevenTeams ? 1 : 0,
          'is_ranked': session.isRanked ? 1 : 0,
          'score_a': session.scoreA,
          'score_b': session.scoreB,
          'result': _resultToString(session.result),
          'unassigned_goals_a': session.unassignedGoalsA,
          'unassigned_goals_b': session.unassignedGoalsB,
          'notes': session.notes,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await txn.delete('participations', where: 'session_id = ?', whereArgs: [session.id]);

      for (final p in participations) {
        await txn.insert('participations', {
          'id': p.id,
          'session_id': p.sessionId,
          'player_id': p.playerId,
          'team': _teamToString(p.team),
          'goals': p.goals,
          'assists': p.assists,
          'yellow_cards': p.yellowCards,
          'red_cards': p.redCards,
        });
      }
    });
  }

  @override
  Future<void> updateSessionScore({
    required String sessionId,
    required int scoreA,
    required int scoreB,
  }) async {
    final db = await _appDatabase.database;
    String result = 'DRAW';
    if (scoreA > scoreB) {
      result = 'A';
    } else if (scoreB > scoreA) {
      result = 'B';
    }

    await db.update(
      'sessions',
      {
        'score_a': scoreA,
        'score_b': scoreB,
        'result': result,
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  @override
  Future<void> incrementScore({
    required String sessionId,
    required String teamId,
    required Team team,
    required int delta,
  }) async {
    final db = await _appDatabase.database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'sessions',
        columns: ['score_a', 'score_b'],
        where: 'id = ? AND team_id = ?',
        whereArgs: [sessionId, teamId],
      );
      if (rows.isEmpty) return;
      var scoreA = (rows.first['score_a'] as int?) ?? 0;
      var scoreB = (rows.first['score_b'] as int?) ?? 0;
      if (team == Team.a) {
        scoreA = (scoreA + delta).clamp(0, 999);
      } else {
        scoreB = (scoreB + delta).clamp(0, 999);
      }
      final result = scoreA > scoreB
          ? 'A'
          : scoreA < scoreB
              ? 'B'
              : 'DRAW';
      await txn.update(
        'sessions',
        {
          'score_a': scoreA,
          'score_b': scoreB,
          'result': result,
        },
        where: 'id = ? AND team_id = ?',
        whereArgs: [sessionId, teamId],
      );
    });
  }

  @override
  Future<void> updateUnassignedGoals({
    required String sessionId,
    required String teamId,
    int? unassignedGoalsA,
    int? unassignedGoalsB,
  }) async {
    final db = await _appDatabase.database;
    final updates = <String, dynamic>{};
    if (unassignedGoalsA != null) updates['unassigned_goals_a'] = unassignedGoalsA.clamp(0, 999);
    if (unassignedGoalsB != null) updates['unassigned_goals_b'] = unassignedGoalsB.clamp(0, 999);
    if (updates.isEmpty) return;

    await db.update(
      'sessions',
      updates,
      where: 'id = ? AND team_id = ?',
      whereArgs: [sessionId, teamId],
    );
  }

  @override
  Future<void> updateParticipationStats({
    required String participationId,
    required int goals,
    required int assists,
    required int yellowCards,
    required int redCards,
  }) async {
    final db = await _appDatabase.database;
    await db.update(
      'participations',
      {
        'goals': goals,
        'assists': assists,
        'yellow_cards': yellowCards,
        'red_cards': redCards,
      },
      where: 'id = ?',
      whereArgs: [participationId],
    );
  }

  @override
  Future<void> addParticipations({
    required String sessionId,
    required List<Participation> participations,
  }) async {
    final db = await _appDatabase.database;
    await db.transaction((txn) async {
      for (final p in participations) {
        await txn.insert(
          'participations',
          {
            'id': p.id,
            'session_id': p.sessionId,
            'player_id': p.playerId,
            'team': _teamToString(p.team),
            'goals': p.goals,
            'assists': p.assists,
            'yellow_cards': p.yellowCards,
            'red_cards': p.redCards,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  @override
  Future<bool> closeSession(String sessionId, {required String teamId}) async {
    final db = await _appDatabase.database;
    final key = _activeSessionKey(teamId);
    return await db.transaction((txn) async {
      // A CLOSED session must carry a score and a result (CDC §4.2), whatever the caller checked.
      final updated = await txn.update(
        'sessions',
        {'status': 'CLOSED'},
        where: 'id = ? AND team_id = ? AND status = ? AND score_a IS NOT NULL AND score_b IS NOT NULL AND result IS NOT NULL',
        whereArgs: [sessionId, teamId, 'DRAFT'],
      );
      if (updated == 0) return false;
      await txn.delete(
        'meta',
        where: 'key = ? AND value = ?',
        whereArgs: [key, sessionId],
      );
      return true;
    });
  }

  @override
  Future<void> reopenSession(String sessionId) async {
    final db = await _appDatabase.database;
    await db.transaction((txn) async {
      await txn.update(
        'sessions',
        {'status': 'DRAFT'},
        where: 'id = ?',
        whereArgs: [sessionId],
      );
    });
  }

  @override
  Future<void> deleteSession(String sessionId, {required String teamId}) async {
    final db = await _appDatabase.database;
    final key = _activeSessionKey(teamId);
    await db.transaction((txn) async {
      await txn.delete(
        'sessions',
        where: 'id = ? AND team_id = ?',
        whereArgs: [sessionId, teamId],
      );
      await txn.delete(
        'meta',
        where: 'key = ? AND value = ?',
        whereArgs: [key, sessionId],
      );
    });
  }
}
