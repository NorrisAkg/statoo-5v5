import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:statoo/core/data/app_database.dart';

const _tables = ['teams', 'players', 'sessions', 'participations', 'meta'];

Future<Map<String, Object?>> _state(Database db) async => {
  for (final table in _tables)
    table: await db.query(table, orderBy: table == 'meta' ? 'key' : 'id'),
};

Future<bool> _rejects(Future<Object?> Function() action) async {
  try {
    await action();
    return false;
  } on DatabaseException {
    return true;
  }
}

// A fresh isolate exercises the production singleton and opening callbacks,
// without adding a testing-only opening path to application code.
Future<Map<String, Object?>> _openApplication(
  String directory, {
  bool probeGuards = false,
}) => Isolate.run(() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  await databaseFactory.setDatabasesPath(directory);
  final db = await AppDatabase.instance.database;
  try {
    final result = <String, Object?>{
      'version': await db.getVersion(),
      'foreignKeys': (await db.rawQuery('PRAGMA foreign_keys'))
          .single
          .values
          .single,
      'foreignKeyCheck': await db.rawQuery('PRAGMA foreign_key_check'),
      'state': await _state(db),
      'views': await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='view' ORDER BY name",
      ),
      'totals': await db.rawQuery(
        'SELECT team_id, total_sessions, total_players FROM v_group_totals ORDER BY team_id',
      ),
      'standings': await db.rawQuery('SELECT * FROM v_standings'),
    };
    if (probeGuards) {
      result['orphanRejected'] = await _rejects(
        () => db.insert('participations', {
          'id': 'probe-orphan',
          'session_id': 's0',
          'player_id': 'missing',
          'team': 'A',
        }),
      );
      result['crossGroupRejected'] = await _rejects(
        () => db.insert('participations', {
          'id': 'probe-cross',
          'session_id': 's0',
          'player_id': 'p6',
          'team': 'A',
        }),
      );
      result['deletePlayerRejected'] = await _rejects(
        () => db.delete('players', where: 'id = ?', whereArgs: ['p0']),
      );
      await db.insert('sessions', {
        'id': 'probe-session',
        'team_id': 'g0',
        'played_at': '2026-10-25',
        'status': 'DRAFT',
      });
      await db.insert('participations', {
        'id': 'probe-part',
        'session_id': 'probe-session',
        'player_id': 'p0',
        'team': 'A',
      });
      await db.delete(
        'sessions',
        where: 'id = ?',
        whereArgs: ['probe-session'],
      );
      result['cascadePreserved'] = (await db.query(
        'participations',
        where: 'id = ?',
        whereArgs: ['probe-part'],
      )).isEmpty;
    }
    return result;
  } finally {
    await db.close();
  }
});

Map<String, Object?> _withoutNewNullableColumns(Map<String, Object?> state) => {
  ...state,
  'sessions': [
    for (final row in state['sessions']! as List)
      Map<String, Object?>.from(row as Map)
        ..remove('team_names')
        ..remove('team_colors'),
  ],
};

void _expectMigrated(Map<String, Object?> result, Map<String, Object?> before) {
  expect(result['version'], 8);
  expect(result['foreignKeys'], 1);
  expect(result['foreignKeyCheck'], isEmpty);
  final after = result['state']! as Map<String, Object?>;
  expect(_withoutNewNullableColumns(after), before);
  for (final row in after['sessions']! as List) {
    final session = row as Map;
    expect(session.containsKey('team_names'), isTrue);
    expect(session.containsKey('team_colors'), isTrue);
    expect(session['team_names'], isNull);
    expect(session['team_colors'], isNull);
  }
  expect(result['views'], hasLength(7));
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  late Directory directory;
  String getPath() => '${directory.path}/statoo.db';

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('statoo-migration-test-');
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });

  Future<Map<String, Object?>> historical({
    int version = 6,
    bool populated = true,
    bool views = true,
    bool large = false,
    String? corruption,
  }) async {
    final fixture = jsonDecode(
      await File('test/fixtures/migrations/v$version.json').readAsString(),
    ) as Map<String, dynamic>;
    expect(fixture['version'], version);
    final db = await databaseFactoryFfi.openDatabase(
      getPath(),
      options: OpenDatabaseOptions(
        version: version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) async {
          for (final sql in fixture['statements'] as List) {
            final statement = sql as String;
            if (views || !statement.contains('CREATE VIEW')) {
              await db.execute(statement);
            }
          }
        },
      ),
    );
    try {
      if (populated) {
        final batch = db.batch();
        for (var group = 0; group < 2; group++) {
          batch.insert('teams', {
            'id': 'g$group',
            'name': 'Groupe $group',
            'format': '5v5',
            'location': 'Terrain $group',
            'created_at': '2026-09-01',
          });
        }
        final playerCount = large ? 50 : 12;
        final perGroup = playerCount ~/ 2;
        for (var player = 0; player < playerCount; player++) {
          batch.insert('players', {
            'id': 'p$player',
            'team_id': 'g${player ~/ perGroup}',
            'name': 'Joueur $player',
            'nickname': 'Surnom $player',
            'avatar_url': player == 0 ? '/photo/original.jpg' : null,
            'is_active': player == perGroup - 1 ? 0 : 1,
            'created_at': '2026-09-01',
            'updated_at': '2026-10-25',
          });
        }
        final sessionCount = large ? 500 : 4;
        for (var session = 0; session < sessionCount; session++) {
          final group = session % 2;
          final tournament = session % 3 == 1;
          batch.insert('sessions', {
            'id': 's$session',
            'team_id': 'g$group',
            'played_at': '2026-10-25T09:00:00',
            'status': session == 2 ? 'DRAFT' : 'CLOSED',
            'split_mode': 'MANUAL',
            'session_type': tournament ? 'TOURNAMENT_3' : 'CLASSIC_2',
            'allow_uneven_teams': 0,
            'is_ranked': session == 3 ? 0 : 1,
            'score_a': tournament ? null : 2,
            'score_b': tournament ? null : 1,
            'score_c': null,
            'wins_a': tournament ? 4 : 0,
            'wins_b': tournament ? 4 : 0,
            'wins_c': tournament ? 1 : 0,
            'draw_points': 2,
            'result': tournament ? 'DRAW_AB' : 'A',
            'unassigned_goals_a': 0,
            'unassigned_goals_b': 0,
            'unassigned_goals_c': 0,
            'notes': 'Notes conservées $session',
          });
          final participationCount = large ? 10 : 6;
          for (var part = 0; part < participationCount; part++) {
            batch.insert('participations', {
              'id': 'pt-$session-$part',
              'session_id': 's$session',
              'player_id': 'p${group * perGroup + (part + session) % perGroup}',
              'team': tournament
                  ? ['A', 'B', 'C'][part % 3]
                  : (part < participationCount ~/ 2 ? 'A' : 'B'),
              'goals': part == 0 ? 2 : (part == 3 ? 1 : 0),
              'assists': part == 1 ? 1 : 0,
              'yellow_cards': part == 2 ? 1 : 0,
              'red_cards': part == 4 ? 1 : 0,
            });
          }
        }
        for (final entry in {
          'active_team_id': 'g0',
          'active_session_id_g0': 's2',
          'team_short_name_g0': 'GA',
          'finance_rate_g0': '100',
          'outbox_fixture': '{"status":"pending"}',
        }.entries) {
          batch.insert('meta', {'key': entry.key, 'value': entry.value});
        }
        await batch.commit(noResult: true);
      }
      if (corruption != null) {
        await db.execute('PRAGMA foreign_keys = OFF');
        if (corruption == 'null-team') {
          await db.update(
            'sessions',
            {'team_id': null},
            where: 'id = ?',
            whereArgs: ['s0'],
          );
        } else {
          await db.update(
            'participations',
            {'player_id': 'missing'},
            where: 'id = ?',
            whereArgs: ['pt-0-0'],
          );
        }
      }
      return await _state(db);
    } finally {
      await db.close();
    }
  }

  test('MIG01 empty historical v6 with views opens as v8', () async {
    final before = await historical(populated: false);
    _expectMigrated(await _openApplication(directory.path), before);
  });

  test(
    'MIG02 preserves all historical v6 data across groups and formats',
    () async {
      final before = await historical();
      final result = await _openApplication(directory.path);
      _expectMigrated(result, before);
      expect(result['totals'], [
        {'team_id': 'g0', 'total_sessions': 1, 'total_players': 6},
        {'team_id': 'g1', 'total_sessions': 2, 'total_players': 6},
      ]);
    },
  );

  test('MIG03 removing views must not cascade-delete participations', () async {
    final before = await historical(views: false);
    _expectMigrated(await _openApplication(directory.path), before);
  });

  test(
    'MIG04 restores foreign keys, group guards, RESTRICT and CASCADE',
    () async {
      await historical();
      final result = await _openApplication(directory.path, probeGuards: true);
      for (final key in [
        'orphanRejected',
        'crossGroupRejected',
        'deletePlayerRejected',
        'cascadePreserved',
      ]) {
        expect(result[key], isTrue, reason: key);
      }
    },
  );

  for (final corruption in ['null-team', 'orphan']) {
    test(
      '${corruption == 'null-team' ? 'MIG05' : 'MIG06'} rejects $corruption without losing original data',
      () async {
        final before = await historical(views: false, corruption: corruption);
        await expectLater(
          _openApplication(directory.path),
          throwsA(anyOf(isA<DatabaseException>(), isA<StateError>())),
        );
        final original = await databaseFactoryFfi.openDatabase(getPath());
        try {
          expect(await original.getVersion(), 6);
          expect(await _state(original), before);
          expect(
            await original.rawQuery(
              "SELECT name FROM sqlite_master WHERE name IN ('sessions_new','participations_new')",
            ),
            isEmpty,
          );
        } finally {
          await original.close();
        }
      },
    );
  }

  test('MIG07 historical v7 still upgrades additively', () async {
    final before = await historical(version: 7);
    _expectMigrated(await _openApplication(directory.path), before);
  });

  test('MIG08 reopening migrated v8 preserves data and schema', () async {
    final before = await historical();
    final first = await _openApplication(directory.path);
    final second = await _openApplication(directory.path);
    _expectMigrated(second, before);
    expect(second, first);
  });

  test(
    'MIG09 fresh installation still opens with foreign keys and views',
    () async {
      final result = await _openApplication(directory.path);
      expect(result['version'], 8);
      expect(result['foreignKeys'], 1);
      expect(result['foreignKeyCheck'], isEmpty);
      expect(result['views'], hasLength(7));
      final state = result['state']! as Map<String, Object?>;
      for (final table in _tables.where((name) => name != 'meta')) {
        expect(state[table], isEmpty);
      }
    },
  );

  test(
    'MIG10 preserves 50 players, 500 sessions and 5000 participations',
    () async {
      final before = await historical(large: true);
      expect(before['participations'], hasLength(5000));
      _expectMigrated(await _openApplication(directory.path), before);
    },
  );

  test('MIG11 failed migration restores the historical views exactly', () async {
    final before = await historical(corruption: 'orphan');
    final original = await databaseFactoryFfi.openDatabase(getPath());
    final views = await original.rawQuery(
      "SELECT name, sql FROM sqlite_master WHERE type='view' ORDER BY name",
    );
    await original.close();
    expect(views, hasLength(7));

    await expectLater(
      _openApplication(directory.path),
      throwsA(isA<StateError>()),
    );
    final rolledBack = await databaseFactoryFfi.openDatabase(getPath());
    try {
      expect(await rolledBack.getVersion(), 6);
      expect(await _state(rolledBack), before);
      expect(
        await rolledBack.rawQuery(
          "SELECT name, sql FROM sqlite_master WHERE type='view' ORDER BY name",
        ),
        views,
      );
      expect(
        await rolledBack.rawQuery('SELECT * FROM v_group_totals'),
        hasLength(2),
      );
    } finally {
      await rolledBack.close();
    }
  });
}
