import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/data/app_database.dart';

class LiveStatsRepository {
  LiveStatsRepository(this.database);
  final AppDatabase database;
  String _key(String group, String session) => 'live_stats_${group}_$session';
  Future<List<Map<String, dynamic>>> _read(
    DatabaseExecutor db,
    String group,
    String session,
  ) async {
    final rows = await db.query(
      'meta',
      where: 'key = ?',
      whereArgs: [_key(group, session)],
    );
    if (rows.isEmpty) return [];
    try {
      final entries = (jsonDecode(rows.single['value']! as String) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      for (final e in entries) {
        final a = e['action'];
        if (e['id'] is! String ||
            e['before'] is! Map ||
            e['after'] is! Map ||
            a is! Map ||
            !['goal', 'win', 'yellow', 'red'].contains(a['type']) ||
            !['A', 'B', 'C'].contains(a['team'])) {
          throw const FormatException();
        }
      }
      return entries;
    } on Object {
      throw StateError(
        'Journal local illisible. Aucune modification effectuée.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> journal(
    String group,
    String session,
  ) async => await _read(await database.database, group, session);
  Future<Map<String, dynamic>> _snapshot(
    DatabaseExecutor db,
    String group,
    String id,
  ) async {
    final rows = await db.query(
      'sessions',
      where: 'id = ? AND team_id = ?',
      whereArgs: [id, group],
    );
    if (rows.isEmpty || rows.single['status'] != 'DRAFT') {
      throw StateError('Séance indisponible ou clôturée.');
    }
    final active = await db.query(
      'meta',
      where: 'key = ?',
      whereArgs: ['active_session_id_$group'],
    );
    if (active.isEmpty || active.single['value'] != id) {
      throw StateError('Cette séance n’est pas en cours.');
    }
    const fields = [
      'score_a',
      'score_b',
      'score_c',
      'wins_a',
      'wins_b',
      'wins_c',
      'unassigned_goals_a',
      'unassigned_goals_b',
      'unassigned_goals_c',
      'result',
      'session_type',
    ];
    final parts = await db.query(
      'participations',
      where: 'session_id = ?',
      whereArgs: [id],
      orderBy: 'id',
    );
    return {
      'session': {for (final k in fields) k: rows.single[k]},
      'players': parts
          .map(
            (p) => {
              for (final k in [
                'id',
                'team',
                'goals',
                'assists',
                'yellow_cards',
                'red_cards',
              ])
                k: p[k],
            },
          )
          .toList(),
    };
  }

  void _same(Map<String, dynamic> current, dynamic expected) {
    if (jsonEncode(current) != jsonEncode(expected)) {
      throw StateError(
        'La séance a changé depuis cette action. Rechargez les données avant de corriger.',
      );
    }
  }

  Future<void> _write(
    DatabaseExecutor db,
    String id,
    Map<String, dynamic> value,
  ) async {
    final session = Map<String, Object?>.from(value['session'] as Map)
      ..remove('session_type');
    await db.update('sessions', session, where: 'id = ?', whereArgs: [id]);
    for (final raw in value['players'] as List) {
      final p = Map<String, Object?>.from(raw as Map);
      final playerId = p.remove('id');
      p.remove('team');
      await db.update(
        'participations',
        p,
        where: 'id = ? AND session_id = ?',
        whereArgs: [playerId, id],
      );
    }
  }

  Future<void> _saveJournal(
    DatabaseExecutor db,
    String group,
    String id,
    List<Map<String, dynamic>> entries,
  ) => db
      .insert('meta', {
        'key': _key(group, id),
        'value': jsonEncode(entries),
      }, conflictAlgorithm: ConflictAlgorithm.replace)
      .then((_) {});
  void _delta(
    Map<String, dynamic> snapshot,
    Map<String, dynamic> a,
    int sign, {
    bool score = true,
  }) {
    final s = snapshot['session'] as Map<String, dynamic>;
    final players = (snapshot['players'] as List).cast<Map<String, dynamic>>();
    final team = a['team'];
    final type = a['type'];
    final player = a['player'];
    final assist = a['assist'];
    if (!['A', 'B', 'C'].contains(team) ||
        (team == 'C' && s['session_type'] != 'TOURNAMENT_3')) {
      throw StateError('Équipe inconnue.');
    }
    if (!['goal', 'yellow', 'red', 'win'].contains(type)) {
      throw StateError('Action invalide.');
    }
    Map<String, dynamic>? participant(dynamic id) {
      if (id == null) return null;
      final matches = players.where((p) => p['id'] == id && p['team'] == team);
      if (matches.isEmpty) {
        throw StateError('Choisissez un joueur de cette équipe.');
      }
      return matches.single;
    }

    final p = participant(player);
    final passer = participant(assist);
    if (assist != null &&
        (type != 'goal' || player == null || player == assist)) {
      throw StateError('Passeur invalide.');
    }
    void increment(Map<String, dynamic> row, String field, int amount) {
      final n = ((row[field] as int?) ?? 0) + amount;
      if (n < 0) throw StateError('Compteur invalide.');
      row[field] = n;
    }

    final suffix = (team as String).toLowerCase();
    if (type == 'win') {
      if (s['session_type'] != 'TOURNAMENT_3' ||
          ![1, -1].contains(a['delta'])) {
        throw StateError('Victoire invalide.');
      }
      increment(s, 'wins_$suffix', sign * (a['delta'] as int));
    } else if (type == 'goal') {
      if (p == null) {
        increment(s, 'unassigned_goals_$suffix', sign);
      } else {
        increment(p, 'goals', sign);
      }
      if (passer != null) increment(passer, 'assists', sign);
      if (score && s['session_type'] != 'TOURNAMENT_3') {
        increment(s, 'score_$suffix', sign);
      }
    } else {
      if (p == null) throw StateError('Choisissez un joueur.');
      increment(p, type == 'yellow' ? 'yellow_cards' : 'red_cards', sign);
    }
    if (s['session_type'] == 'TOURNAMENT_3') {
      final wins = [s['wins_a'] as int, s['wins_b'] as int, s['wins_c'] as int];
      final max = wins.reduce((a, b) => a > b ? a : b);
      final leaders = [
        for (var i = 0; i < 3; i++)
          if (wins[i] == max) ['A', 'B', 'C'][i],
      ];
      s['result'] = leaders.length == 1
          ? leaders.single
          : leaders.length == 3
          ? 'DRAW_ALL'
          : 'DRAW_${leaders.join()}';
    } else {
      final x = (s['score_a'] as int?) ?? 0;
      final y = (s['score_b'] as int?) ?? 0;
      s['result'] = x > y
          ? 'A'
          : y > x
          ? 'B'
          : 'DRAW';
    }
  }

  Future<void> apply(
    String group,
    String session,
    Map<String, dynamic> action, {
    String? edit,
  }) async {
    final db = await database.database;
    await db.transaction((txn) async {
      final before = await _snapshot(txn, group, session);
      final entries = await _read(txn, group, session);
      final after = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(before)) as Map,
      );
      if (edit == null &&
          entries.isNotEmpty &&
          jsonEncode(before) != jsonEncode(entries.last['after'])) {
        for (final entry in entries) {
          entry['stale'] = true;
        }
      }
      if (edit != null) {
        if (entries.isEmpty) throw StateError('But introuvable.');
        _same(before, entries.last['after']);
        final candidates = entries
            .where((e) => e['id'] == edit || e['target'] == edit)
            .toList();
        if (candidates.isEmpty) throw StateError('But introuvable.');
        if (candidates.last['stale'] == true) {
          throw StateError(
            'Ce but appartient à un historique modifié sur un autre appareil.',
          );
        }
        final old = Map<String, dynamic>.from(candidates.last['action'] as Map);
        if (old['type'] != 'goal' ||
            action['type'] != 'goal' ||
            old['team'] != action['team']) {
          throw StateError('Correction invalide.');
        }
        _delta(after, old, -1, score: false);
      }
      _delta(after, action, 1, score: edit == null);
      final id = '${DateTime.now().microsecondsSinceEpoch}_${entries.length}';
      entries.add({
        'id': id,
        'target': edit,
        'action': action,
        'before': before,
        'after': after,
      });
      await _write(txn, session, after);
      await _saveJournal(txn, group, session, entries);
    });
  }

  Future<void> undo(String group, String session) async {
    final db = await database.database;
    await db.transaction((txn) async {
      final current = await _snapshot(txn, group, session);
      final entries = await _read(txn, group, session);
      if (entries.isEmpty) return;
      _same(current, entries.last['after']);
      await _write(
        txn,
        session,
        Map<String, dynamic>.from(entries.removeLast()['before'] as Map),
      );
      await _saveJournal(txn, group, session, entries);
    });
  }
}
