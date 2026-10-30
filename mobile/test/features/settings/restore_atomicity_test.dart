import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/features/settings/data/backup_service.dart';
import 'package:statoo/features/settings/data/group_settings_repository.dart';
import 'package:statoo/features/settings/domain/backup_payload.dart';
import 'package:statoo/features/team/data/team_repository.dart';
import 'package:statoo/features/team/domain/team_info.dart';

class _FailCommit implements Database {
  _FailCommit(this.database);
  @override
  final Database database;
  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction) action, {
    bool? exclusive,
  }) => database.transaction((txn) async {
    await action(txn);
    throw StateError('Injected failure before commit');
  });
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(sqfliteFfiInit);
  late Database db;
  late Directory directory;
  late AppDatabase app;
  late SharedPreferences prefs;
  BackupPayload payload({
    bool empty = false,
    int? minimum = 8,
    Map<String, dynamic> meta = const {},
  }) => BackupPayload(
    team: null,
    version: 2,
    exportedAt: DateTime(2026),
    teams: empty
        ? const []
        : const [
            {'id': 'new', 'name': 'New', 'created_at': '2026-10-27'},
            {'id': 'second', 'name': 'Second', 'created_at': '2026-10-27'},
          ],
    players: const [],
    sessions: const [],
    participations: const [],
    meta: meta,
    minPlayersPerSession: minimum,
  );
  Future<int?> minimum() =>
      SqliteGroupSettingsRepository(app)
          .getInt('new', 'min_players_per_session');
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'team_name': 'Old',
      'active_team_id': 'old',
      'min_players_per_session': 6,
    });
    prefs = await SharedPreferences.getInstance();
    directory = await Directory.systemTemp.createTemp('statoo-restore-');
    db = await databaseFactoryFfi.openDatabase(
      '${directory.path}/test.db',
      options: OpenDatabaseOptions(singleInstance: false),
    );
    app = AppDatabase.forTesting(db);
    await app.initSchemaForTest(db);
    await db.insert('teams', {
      'id': 'old',
      'name': 'Old',
      'created_at': '2026-10-26',
    });
  });
  tearDown(() async {
    await db.close();
    await directory.delete(recursive: true);
  });
  test('rollback after callback preserves both stores', () async {
    final oldMeta = await db.query('meta');
    await expectLater(
      BackupService(AppDatabase.forTesting(_FailCommit(db)))
          .restoreBackup(payload(), merge: false),
      throwsStateError,
    );
    expect((await db.query('teams')).single['id'], 'old');
    expect(prefs.getString('active_team_id'), 'old');
    expect(prefs.getString('team_name'), 'Old');
    expect(prefs.getInt('min_players_per_session'), 6);
    expect(await db.query('meta'), oldMeta);
  });
  test(
    'successful restore is authoritative without preference writes',
    () async {
      await BackupService(app).restoreBackup(payload(), merge: false);
      expect((await SqliteTeamRepository(app).getTeamInfo())!.id, 'new');
      expect(await minimum(), 8);
      expect(prefs.getString('active_team_id'), 'old');
      expect(prefs.getString('team_name'), 'Old');
      expect(prefs.getInt('min_players_per_session'), 6);
      await db.close();
      db = await databaseFactoryFfi.openDatabase(
        '${directory.path}/test.db',
        options: OpenDatabaseOptions(singleInstance: false),
      );
      app = AppDatabase.forTesting(db);
      expect((await SqliteTeamRepository(app).getTeamInfo())!.id, 'new');
      expect(await minimum(), 8);
      final exported = await BackupService(AppDatabase.forTesting(db))
          .createBackupPayload();
      expect(exported.minPlayersPerSession, 8);
      expect(exported.meta.containsKey('_restore_completed'), isFalse);
    },
  );
  test('empty restore never resurrects legacy group', () async {
    await BackupService(app).restoreBackup(payload(empty: true), merge: false);
    for (var i = 0; i < 2; i++) {
      expect(await SqliteTeamRepository(app).getTeamInfo(), isNull);
      expect(await SqliteTeamRepository(app).getActiveTeamId(), isNull);
      expect(await db.query('teams'), isEmpty);
    }
  });
  for (final active in ['second', 'missing']) {
    test('restored active group resolves $active', () async {
      await BackupService(
        app,
      ).restoreBackup(payload(meta: {'active_team_id': active}), merge: false);
      expect(
        await SqliteTeamRepository(app).getActiveTeamId(),
        active == 'second' ? 'second' : 'new',
      );
    });
  }
  test('missing minimum retains previous SQL fallback', () async {
    await BackupService(app).restoreBackup(payload(), merge: false);
    await BackupService(app)
        .restoreBackup(payload(minimum: null), merge: false);
    expect(await minimum(), 8);
  });
  test('missing minimum retains legacy fallback', () async {
    await BackupService(app)
        .restoreBackup(payload(minimum: null), merge: false);
    expect(await minimum(), 6);
  });
  test('scoped setting overrides restored fallback', () async {
    await BackupService(app).restoreBackup(
      payload(meta: {'min_players_per_session_new': '12'}),
      merge: false,
    );
    expect(await minimum(), 12);
  });
  test('merge does not install replacement marker or global setting', () async {
    await BackupService(app).restoreBackup(payload(), merge: true);
    expect(await minimum(), isNull);
    expect(
      await db.query(
        'meta',
        where: 'key = ?',
        whereArgs: ['_restore_completed'],
      ),
      isEmpty,
    );
    expect(prefs.getInt('min_players_per_session'), 6);
  });
  test('legacy migration remains available without replacement', () async {
    await db.delete('teams');
    expect((await SqliteTeamRepository(app).getTeamInfo())!.name, 'Old');
  });
  test('import cannot disable replacement marker', () async {
    await BackupService(app).restoreBackup(
      payload(empty: true, meta: {'_restore_completed': 'false'}),
      merge: false,
    );
    expect(await SqliteTeamRepository(app).getTeamInfo(), isNull);
  });
  test('absent minimum preserves default fallback', () async {
    await prefs.remove('min_players_per_session');
    await BackupService(app)
        .restoreBackup(payload(minimum: null), merge: false);
    expect(await minimum(), isNull);
    expect(
      (await BackupService(app).createBackupPayload()).minPlayersPerSession,
      isNull,
    );
  });
  test('explicit group creation works after empty restore', () async {
    await BackupService(app).restoreBackup(payload(empty: true), merge: false);
    final repository = SqliteTeamRepository(app);
    await repository.saveTeamInfo(
      TeamInfo(
        id: 'created',
        name: 'Created',
        createdAt: DateTime(2026),
      ),
    );
    expect((await repository.getTeamInfo())!.id, 'created');
  });
  test('bad SQL row preserves all old state', () async {
    final bad = BackupPayload(
      team: null,
      version: 2,
      exportedAt: DateTime(2026),
      teams: const [
        {'id': 'bad'},
      ],
      players: const [],
      sessions: const [],
      participations: const [],
      minPlayersPerSession: 8,
    );
    await expectLater(
      BackupService(app).restoreBackup(bad, merge: false),
      throwsA(isA<DatabaseException>()),
    );
    expect((await db.query('teams')).single['id'], 'old');
    expect(prefs.getInt('min_players_per_session'), 6);
  });
}
