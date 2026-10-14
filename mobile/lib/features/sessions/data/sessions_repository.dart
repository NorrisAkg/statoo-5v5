import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import '../../../core/data/app_database.dart';
import '../domain/goal_score_sync.dart';
import '../domain/participation.dart';
import '../domain/session.dart';
import '../domain/session_summary.dart';

abstract class SessionsRepository {
  Future<List<SessionSummaryItem>> getSessionSummaries({
    required String teamId,
    String filter = 'all',
  });
  Future<Session?> getSession(String id, {required String teamId});
  Future<List<SessionParticipantDetail>> getSessionParticipants(
    String sessionId, {
    required String teamId,
  });
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
    required String teamId,
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
    int? unassignedGoalsC,
  });
  Future<void> updateTournamentWins({
    required String sessionId,
    required String teamId,
    required int winsA,
    required int winsB,
    required int winsC,
    MatchResult? result,
  });
  Future<void> updateParticipationStats({
    required String participationId,
    required String sessionId,
    required String teamId,
    required int goals,
    required int assists,
    required int yellowCards,
    required int redCards,
  });
  Future<void> addParticipations({
    required String sessionId,
    required String teamId,
    required List<Participation> participations,
  });
  Future<void> switchPlayerTeam({
    required String sessionId,
    required String participationId,
    required Team newTeam,
    required String teamId,
  });
  Future<void> removeParticipation({
    required String sessionId,
    required String participationId,
    required String teamId,
  });
  /// Returns false when nothing was closed (unknown session, other team, or no score).
  Future<bool> closeSession(String sessionId, {required String teamId});
  Future<void> reopenSession(String sessionId, {required String teamId});
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

  SessionType _parseSessionType(String? val) =>
      val == 'TOURNAMENT_3' ? SessionType.tournament3 : SessionType.classic2;

  String _sessionTypeToString(SessionType t) =>
      t == SessionType.tournament3 ? 'TOURNAMENT_3' : 'CLASSIC_2';

  MatchResult? _parseResult(String? val) {
    return switch (val) {
      'A' => MatchResult.teamA,
      'B' => MatchResult.teamB,
      'C' => MatchResult.teamC,
      'DRAW' => MatchResult.draw,
      'DRAW_AB' => MatchResult.drawAB,
      'DRAW_BC' => MatchResult.drawBC,
      'DRAW_AC' => MatchResult.drawAC,
      'DRAW_ALL' => MatchResult.drawAll,
      _ => null,
    };
  }

  String? _resultToString(MatchResult? r) {
    return switch (r) {
      MatchResult.teamA => 'A',
      MatchResult.teamB => 'B',
      MatchResult.teamC => 'C',
      MatchResult.draw => 'DRAW',
      MatchResult.drawAB => 'DRAW_AB',
      MatchResult.drawBC => 'DRAW_BC',
      MatchResult.drawAC => 'DRAW_AC',
      MatchResult.drawAll => 'DRAW_ALL',
      null => null,
    };
  }

  Team _parseTeam(String val) {
    return switch (val) {
      'C' => Team.c,
      'B' => Team.b,
      _ => Team.a,
    };
  }

  String _teamToString(Team t) {
    return switch (t) {
      Team.c => 'C',
      Team.b => 'B',
      Team.a => 'A',
    };
  }

  Session _mapSessionRow(Map<String, dynamic> row) {
    return Session(
      id: row['id']! as String,
      playedAt: DateTime.parse(row['played_at']! as String),
      status: _parseStatus(row['status']! as String),
      splitMode: _parseSplitMode(row['split_mode'] as String?),
      sessionType: _parseSessionType(row['session_type'] as String?),
      allowUnevenTeams: (row['allow_uneven_teams'] as int?) == 1,
      isRanked: (row['is_ranked'] as int?) == 1,
      scoreA: row['score_a'] as int?,
      scoreB: row['score_b'] as int?,
      scoreC: row['score_c'] as int?,
      winsA: (row['wins_a'] as int?) ?? 0,
      winsB: (row['wins_b'] as int?) ?? 0,
      winsC: (row['wins_c'] as int?) ?? 0,
      drawPoints: (row['draw_points'] as int?) ?? 1,
      result: _parseResult(row['result'] as String?),
      unassignedGoalsA: (row['unassigned_goals_a'] as int?) ?? 0,
      unassignedGoalsB: (row['unassigned_goals_b'] as int?) ?? 0,
      unassignedGoalsC: (row['unassigned_goals_c'] as int?) ?? 0,
      notes: row['notes'] as String?,
      teamNames: row['team_names'] == null ? const {} : Map<String, String>.from(jsonDecode(row['team_names']! as String) as Map),
      teamColors: row['team_colors'] == null ? const {} : Map<String, int>.from(jsonDecode(row['team_colors']! as String) as Map),
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
        COALESCE(SUM(CASE WHEN pt.team = 'B' THEN pt.goals ELSE 0 END), 0) as goals_b,
        COALESCE(SUM(CASE WHEN pt.team = 'C' THEN pt.goals ELSE 0 END), 0) as goals_c
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
        totalGoalsAssignedC: (r['goals_c'] as num?)?.toInt() ?? 0,
        isActiveSession: session.id == activeId,
      );
    }).toList();
  }

  @override
  Future<Session?> getSession(String id, {required String teamId}) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      'sessions',
      where: 'id = ? AND team_id = ?',
      whereArgs: [id, teamId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _mapSessionRow(rows.first);
  }

  @override
  Future<List<SessionParticipantDetail>> getSessionParticipants(
    String sessionId, {
    required String teamId,
  }) async {
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
      JOIN sessions s ON s.id = pt.session_id
      JOIN players p ON p.id = pt.player_id AND p.team_id = s.team_id
      WHERE pt.session_id = ? AND s.team_id = ?
      ORDER BY pt.team ASC, p.name ASC
    ''', [sessionId, teamId]);

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
    return await getSession(activeId, teamId: teamId);
  }

  @override
  Future<void> saveSession(
    Session session,
    List<Participation> participations, {
    required String teamId,
  }) async {
    final db = await _appDatabase.database;
    await db.transaction((txn) async {
      // INSERT OR REPLACE on an id owned by another group would overwrite its data.
      final existing = await txn.query(
        'sessions',
        columns: ['team_id'],
        where: 'id = ?',
        whereArgs: [session.id],
        limit: 1,
      );
      if (existing.isNotEmpty && existing.first['team_id'] != teamId) {
        throw StateError('Session ${session.id} belongs to another group');
      }
      await _assertPlayersInTeam(txn, teamId, participations);

      await txn.insert(
        'sessions',
        {
          'id': session.id,
          'team_id': teamId,
          'played_at': session.playedAt.toIso8601String(),
          'status': _statusToString(session.status),
          'split_mode': _splitModeToString(session.splitMode),
          'session_type': _sessionTypeToString(session.sessionType),
          'allow_uneven_teams': session.allowUnevenTeams ? 1 : 0,
          'is_ranked': session.isRanked ? 1 : 0,
          'score_a': session.scoreA,
          'score_b': session.scoreB,
          'score_c': session.scoreC,
          'wins_a': session.winsA,
          'wins_b': session.winsB,
          'wins_c': session.winsC,
          'draw_points': session.drawPoints,
          'result': _resultToString(session.result),
          'unassigned_goals_a': session.unassignedGoalsA,
          'unassigned_goals_b': session.unassignedGoalsB,
          'unassigned_goals_c': session.unassignedGoalsC,
          'notes': session.notes,
          'team_names': jsonEncode(session.teamNames),
          'team_colors': jsonEncode(session.teamColors),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final rateRows = await txn.query('meta', where: 'key = ?', whereArgs: ['finance_rate_$teamId']);
      final rate = rateRows.isEmpty ? 100 : int.tryParse(rateRows.single['value']! as String) ?? 100;
      final members = await txn.query('players', where: 'team_id = ? AND is_active = 1', whereArgs: [teamId]);
      final occurrenceRows = await txn.query('meta', where:'key = ?', whereArgs:['shared_occurrence_${session.id}']);
      final occurrence = occurrenceRows.isEmpty ? '${session.playedAt.toIso8601String().substring(0,10)}-1' : occurrenceRows.single['value']! as String;
      final aliases = await txn.query('meta', where:'key = ?', whereArgs:['shared_finance_alias_${teamId}_$occurrence']);
      final financialId = aliases.isEmpty ? session.id : aliases.single['value']! as String;
      await txn.insert('meta',{'key':'shared_occurrence_${session.id}','value':occurrence},conflictAlgorithm:ConflictAlgorithm.ignore);
      await txn.insert('meta',{'key':'shared_finance_alias_${teamId}_$occurrence','value':financialId},conflictAlgorithm:ConflictAlgorithm.ignore);
      await txn.insert('meta', {'key': 'finance_point_${teamId}_$financialId', 'value': jsonEncode({
        'played_at': session.playedAt.toIso8601String(), 'rate': rate, 'cancelled': false,
        'lines': members.map((p) => {'member_id': p['id'], 'contribution': 0, 'penalty_paid': 0, 'penalty_due': 0, 'reason': ''}).toList(),
        'expenses': <dynamic>[], 'donations': <dynamic>[],
      })}, conflictAlgorithm: ConflictAlgorithm.ignore);
      await txn.delete('participations', where: 'session_id = ?', whereArgs: [session.id]);

      for (final p in participations) {
        await txn.insert('participations', {
          'id': p.id,
          'session_id': session.id,
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

  /// Every participating player must belong to [teamId]; a stray id from
  /// another group would leak its stats into this group's rankings.
  Future<void> _assertPlayersInTeam(
    DatabaseExecutor db,
    String teamId,
    List<Participation> participations,
  ) async {
    final ids = participations.map((p) => p.playerId).toSet().toList();
    if (ids.isEmpty) return;
    final placeholders = List.filled(ids.length, '?').join(',');
    final count = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM players WHERE team_id = ? AND id IN ($placeholders)',
            [teamId, ...ids],
          ),
        ) ??
        0;
    if (count != ids.length) {
      throw StateError('Some players do not belong to the active group');
    }
  }

  @override
  Future<void> updateSessionScore({
    required String sessionId,
    required String teamId,
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
      where: 'id = ? AND team_id = ?',
      whereArgs: [sessionId, teamId],
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
    int? unassignedGoalsC,
  }) async {
    final db = await _appDatabase.database;
    final requested = <Team, int>{
      if (unassignedGoalsA != null) Team.a: unassignedGoalsA.clamp(0, 999),
      if (unassignedGoalsB != null) Team.b: unassignedGoalsB.clamp(0, 999),
      if (unassignedGoalsC != null) Team.c: unassignedGoalsC.clamp(0, 999),
    };
    if (requested.isEmpty) return;

    await db.transaction((txn) async {
      final rows = await txn.query(
        'sessions',
        where: 'id = ? AND team_id = ?',
        whereArgs: [sessionId, teamId],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final session = rows.first;
      final scores = <Team, int>{
        Team.a: (session['score_a'] as int?) ?? 0,
        Team.b: (session['score_b'] as int?) ?? 0,
      };
      final updates = <String, dynamic>{};

      for (final entry in requested.entries) {
        final team = entry.key;
        final suffix = _teamToString(team).toLowerCase();
        final previous = (session['unassigned_goals_$suffix'] as int?) ?? 0;
        updates['unassigned_goals_$suffix'] = entry.value;

        // A tournament has no match score: wins decide, so the score is left alone.
        if (!_isScoreTracked(session, team)) continue;
        final increase = scoreIncreaseForAttributedGoals(
          score: scores[team]!,
          assignedGoals: await _assignedGoals(txn, sessionId, team),
          unassignedGoals: previous,
          added: entry.value - previous,
        );
        if (increase > 0) scores[team] = (scores[team]! + increase).clamp(0, 999);
      }

      if (_isScoreChanged(session, scores)) {
        updates.addAll(_scoreColumns(scores));
      }
      await txn.update(
        'sessions',
        updates,
        where: 'id = ? AND team_id = ?',
        whereArgs: [sessionId, teamId],
      );
    });
  }

  /// Only the two-team format keeps a running match score.
  bool _isScoreTracked(Map<String, Object?> session, Team team) =>
      session['session_type'] != 'TOURNAMENT_3' && team != Team.c;

  Future<int> _assignedGoals(DatabaseExecutor txn, String sessionId, Team team) async {
    return Sqflite.firstIntValue(
          await txn.rawQuery(
            'SELECT COALESCE(SUM(goals), 0) FROM participations WHERE session_id = ? AND team = ?',
            [sessionId, _teamToString(team)],
          ),
        ) ??
        0;
  }

  bool _isScoreChanged(Map<String, Object?> session, Map<Team, int> scores) =>
      scores[Team.a] != ((session['score_a'] as int?) ?? 0) ||
      scores[Team.b] != ((session['score_b'] as int?) ?? 0);

  Map<String, Object?> _scoreColumns(Map<Team, int> scores) {
    final a = scores[Team.a]!;
    final b = scores[Team.b]!;
    return {
      'score_a': a,
      'score_b': b,
      'result': a > b ? 'A' : (a < b ? 'B' : 'DRAW'),
    };
  }

  @override
  Future<void> updateParticipationStats({
    required String participationId,
    required String sessionId,
    required String teamId,
    required int goals,
    required int assists,
    required int yellowCards,
    required int redCards,
  }) async {
    final db = await _appDatabase.database;
    await db.transaction((txn) async {
      final sessions = await txn.query(
        'sessions',
        where: 'id = ? AND team_id = ?',
        whereArgs: [sessionId, teamId],
        limit: 1,
      );
      if (sessions.isEmpty) return;
      final parts = await txn.query(
        'participations',
        columns: ['team', 'goals'],
        where: 'id = ? AND session_id = ?',
        whereArgs: [participationId, sessionId],
        limit: 1,
      );
      if (parts.isEmpty) return;

      final session = sessions.first;
      final team = _parseTeam(parts.first['team']! as String);
      final previousGoals = (parts.first['goals'] as int?) ?? 0;

      // Measured before the write: the player's previous goals are part of the sum.
      final assignedBefore = await _assignedGoals(txn, sessionId, team);

      await txn.update(
        'participations',
        {
          'goals': goals,
          'assists': assists,
          'yellow_cards': yellowCards,
          'red_cards': redCards,
        },
        where: 'id = ? AND session_id = ?',
        whereArgs: [participationId, sessionId],
      );

      if (!_isScoreTracked(session, team)) return;
      final suffix = _teamToString(team).toLowerCase();
      final score = (session['score_$suffix'] as int?) ?? 0;
      final increase = scoreIncreaseForAttributedGoals(
        score: score,
        assignedGoals: assignedBefore,
        unassignedGoals: (session['unassigned_goals_$suffix'] as int?) ?? 0,
        added: goals - previousGoals,
      );
      if (increase == 0) return;

      final scores = <Team, int>{
        Team.a: (session['score_a'] as int?) ?? 0,
        Team.b: (session['score_b'] as int?) ?? 0,
      };
      scores[team] = (score + increase).clamp(0, 999);
      await txn.update(
        'sessions',
        _scoreColumns(scores),
        where: 'id = ? AND team_id = ?',
        whereArgs: [sessionId, teamId],
      );
    });
  }

  @override
  Future<void> addParticipations({
    required String sessionId,
    required String teamId,
    required List<Participation> participations,
  }) async {
    final db = await _appDatabase.database;
    await db.transaction((txn) async {
      final owned = await txn.query(
        'sessions',
        columns: ['id'],
        where: 'id = ? AND team_id = ?',
        whereArgs: [sessionId, teamId],
        limit: 1,
      );
      if (owned.isEmpty) throw StateError('Session $sessionId not found in the active group');
      await _assertPlayersInTeam(txn, teamId, participations);

      for (final p in participations) {
        await txn.insert(
          'participations',
          {
            'id': p.id,
            'session_id': sessionId,
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
  Future<void> updateTournamentWins({
    required String sessionId,
    required String teamId,
    required int winsA,
    required int winsB,
    required int winsC,
    MatchResult? result,
  }) async {
    final db = await _appDatabase.database;
    final resStr = _resultToString(result);
    await db.update(
      'sessions',
      {
        'wins_a': winsA,
        'wins_b': winsB,
        'wins_c': winsC,
        'result': resStr,
      },
      where: 'id = ? AND team_id = ?',
      whereArgs: [sessionId, teamId],
    );
  }

  @override
  Future<bool> closeSession(String sessionId, {required String teamId}) async {
    final db = await _appDatabase.database;
    final key = _activeSessionKey(teamId);
    return await db.transaction((txn) async {
      // A CLOSED session must carry a result, and scores (for classic) or result (for tournament).
      final updated = await txn.update(
        'sessions',
        {'status': 'CLOSED'},
        where:
            "id = ? AND team_id = ? AND status = ? AND result IS NOT NULL AND ((session_type = 'TOURNAMENT_3') OR (score_a IS NOT NULL AND score_b IS NOT NULL))",
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
  Future<void> switchPlayerTeam({
    required String sessionId,
    required String participationId,
    required Team newTeam,
    required String teamId,
  }) async {
    final db = await _appDatabase.database;
    await db.transaction((txn) async {
      final sess = await txn.query(
        'sessions',
        columns: ['id'],
        where: 'id = ? AND team_id = ?',
        whereArgs: [sessionId, teamId],
      );
      if (sess.isEmpty) return;

      await txn.update(
        'participations',
        {'team': _teamToString(newTeam)},
        where: 'id = ? AND session_id = ?',
        whereArgs: [participationId, sessionId],
      );
    });
  }

  @override
  Future<void> removeParticipation({
    required String sessionId,
    required String participationId,
    required String teamId,
  }) async {
    final db = await _appDatabase.database;
    await db.transaction((txn) async {
      final sess = await txn.query(
        'sessions',
        columns: ['id'],
        where: 'id = ? AND team_id = ?',
        whereArgs: [sessionId, teamId],
      );
      if (sess.isEmpty) return;

      await txn.delete(
        'participations',
        where: 'id = ? AND session_id = ?',
        whereArgs: [participationId, sessionId],
      );
    });
  }

  @override
  Future<void> reopenSession(String sessionId, {required String teamId}) async {
    final db = await _appDatabase.database;
    await db.transaction((txn) async {
      await txn.update(
        'sessions',
        {'status': 'DRAFT'},
        where: 'id = ? AND team_id = ?',
        whereArgs: [sessionId, teamId],
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
