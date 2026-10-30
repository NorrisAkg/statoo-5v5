import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/features/settings/data/backup_service.dart';
import 'package:statoo/features/settings/domain/backup_payload.dart';

// Forward real SQLite queries, pausing only after a selected read. This probe
// works both with independent SELECTs and with transaction-scoped SELECTs.
class _ReadProbe implements DatabaseExecutor {
  _ReadProbe(this.inner, this.afterRead);
  final DatabaseExecutor inner;
  final Future<void> Function(String) afterRead;

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final rows = await inner.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
    await afterRead(table);
    return rows;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TransactionProbe extends _ReadProbe implements Transaction {
  _TransactionProbe(super.inner, super.afterRead);
}

class _DatabaseProbe extends _ReadProbe implements Database {
  _DatabaseProbe(this.database, Future<void> Function(String) afterRead)
    : super(database, afterRead);
  @override
  final Database database;

  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) => database.transaction(
    (txn) => action(_TransactionProbe(txn, afterRead)),
    exclusive: exclusive,
  );
}

void main() {
  late Database db;
  late BackupService service;
  const bound = Duration(seconds: 10);
  const now = '2026-10-27T12:00:00';

  Future<Database> open() async {
    final value = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        singleInstance: false,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      ),
    );
    await AppDatabase.forTesting(value).initSchemaForTest(value);
    return value;
  }

  Future<void> insert(
    DatabaseExecutor executor,
    String id,
    int revision,
  ) async {
    await executor.insert('teams', {
      'id': id,
      'name': 'Group $revision',
      'created_at': now,
    });
    await executor.insert('players', {
      'id': '$id-p',
      'team_id': id,
      'name': 'Player $revision',
      'created_at': now,
      'updated_at': now,
    });
    await executor.insert('sessions', {
      'id': '$id-s',
      'team_id': id,
      'played_at': now,
      'status': 'CLOSED',
      'score_a': revision,
      'score_b': 0,
      'result': 'A',
      'is_ranked': 1,
    });
    await executor.insert('participations', {
      'id': '$id-pt',
      'session_id': '$id-s',
      'player_id': '$id-p',
      'team': 'A',
      'goals': revision,
    });
    await executor.insert('meta', {
      'key': 'snapshot_revision',
      'value': '$revision',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await executor.insert('meta', {
      'key': 'active_team_id',
      'value': id,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> mutate({bool replace = false}) => db.transaction((txn) async {
    if (replace) {
      await txn.delete('participations');
      await txn.delete('sessions');
      await txn.delete('players');
      await txn.delete('teams');
      await insert(txn, 'new', 2);
    } else {
      await txn.update('teams', {'name': 'Group 2'});
      await txn.update('players', {'name': 'Player 2'});
      await txn.update('sessions', {'score_a': 2});
      await txn.update('participations', {'goals': 2});
      await txn.update(
        'meta',
        {'value': '2'},
        where: 'key = ?',
        whereArgs: ['snapshot_revision'],
      );
    }
  });

  void coherent(BackupPayload payload, int revision, {String id = 'old'}) {
    expect(payload.teams.single['id'], id);
    expect(payload.team, payload.teams.single);
    expect(payload.teams.single['name'], 'Group $revision');
    expect(payload.players.single['name'], 'Player $revision');
    expect(payload.players.single['team_id'], id);
    expect(payload.sessions.single['team_id'], id);
    expect(payload.sessions.single['score_a'], revision);
    expect(
      payload.participations.single['session_id'],
      payload.sessions.single['id'],
    );
    expect(
      payload.participations.single['player_id'],
      payload.players.single['id'],
    );
    expect(payload.participations.single['goals'], revision);
    expect(payload.meta['snapshot_revision'], '$revision');
    expect(payload.meta['active_team_id'], id);
    expect(payload.minPlayersPerSession, 6);
    expect(payload.version, BackupPayload.currentVersion);
  }

  setUp(() async {
    sqfliteFfiInit();
    SharedPreferences.setMockInitialValues({'min_players_per_session': 6});
    db = await open();
    service = BackupService(AppDatabase.forTesting(db));
    await insert(db, 'old', 1);
  });
  tearDown(() => db.close());

  Future<List<BackupPayload>> racing(
    String pauseAfter, {
    bool replace = false,
    bool second = false,
  }) async {
    final entered = Completer<void>();
    final resume = Completer<void>();
    final probe = _DatabaseProbe(db, (table) async {
      if (table == pauseAfter && !entered.isCompleted) {
        entered.complete();
        await resume.future.timeout(bound);
      }
    });
    final exporting = BackupService(AppDatabase.forTesting(probe))
        .createBackupPayload();
    await entered.future.timeout(bound);
    final writing = mutate(replace: replace);
    // Submit the write to sqflite's queue before allowing the next SELECT.
    await Future<void>.delayed(Duration.zero);
    final later = second ? service.createBackupPayload() : null;
    resume.complete();
    final first = await exporting.timeout(bound);
    await writing.timeout(bound);
    return [first, if (later != null) await later.timeout(bound)];
  }

  for (final table in ['teams', 'players', 'sessions', 'participations']) {
    test(
      'SNAP01 snapshot remains coherent when a write follows $table',
      () async {
        final payload = (await racing(table)).single;
        coherent(payload, 1);
        coherent(await service.createBackupPayload(), 2);
      },
    );
  }

  test(
    'SNAP02 concurrent replacement never exports orphan references',
    () async {
      final payload = (await racing('teams', replace: true)).single;
      coherent(payload, 1);
      coherent(await service.createBackupPayload(), 2, id: 'new');
    },
  );

  test('SNAP03 completed mutation is visible in the whole export', () async {
    await mutate();
    coherent(await service.createBackupPayload(), 2);
  });

  test('SNAP04 empty database remains an empty supported backup', () async {
    final empty = await open();
    try {
      SharedPreferences.setMockInitialValues({});
      final payload = await BackupService(AppDatabase.forTesting(empty))
          .createBackupPayload();
      expect(payload.teams, isEmpty);
      expect(payload.team, isNull);
      expect(payload.players, isEmpty);
      expect(payload.sessions, isEmpty);
      expect(payload.participations, isEmpty);
      expect(payload.meta['schema_version'], '1');
      expect(payload.minPlayersPerSession, isNull);
      expect(payload.version, BackupPayload.currentVersion);
    } finally {
      await empty.close();
    }
  });

  test(
    'SNAP05 failed read returns no payload and releases the database',
    () async {
      final probe = _DatabaseProbe(db, (table) async {
        if (table == 'sessions') throw StateError('Synthetic read failure');
      });
      await expectLater(
        BackupService(AppDatabase.forTesting(probe)).createBackupPayload(),
        throwsStateError,
      );
      coherent(await service.createBackupPayload().timeout(bound), 1);
      await mutate().timeout(bound);
      coherent(await service.createBackupPayload().timeout(bound), 2);
    },
  );

  test(
    'SNAP06 concurrent export round trips into another SQLite database',
    () async {
      final payload = (await racing('players')).single;
      final parsed = BackupPayload.fromJson(
        jsonDecode(jsonEncode(payload.toJson())) as Map<String, dynamic>,
      );
      final destination = await open();
      try {
        final restoring = BackupService(AppDatabase.forTesting(destination));
        await restoring.restoreBackup(parsed, merge: false);
        coherent(await restoring.createBackupPayload(), 1);
        expect(await destination.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      } finally {
        await destination.close();
      }
    },
  );

  test(
    'SNAP07 two exports around a mutation finish with coherent states',
    () async {
      final payloads = await racing('teams', second: true);
      coherent(payloads[0], 1);
      coherent(payloads[1], 2);
    },
  );
}
