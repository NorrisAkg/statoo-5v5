import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/features/settings/data/backup_service.dart';
import 'package:statoo/features/settings/domain/backup_payload.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  late Database db;
  late BackupService service;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    final app = AppDatabase.forTesting(db);
    await app.initSchemaForTest(db);
    service = BackupService(app);
    for (final name in ['Alpha', 'Bêta']) {
      await db.insert('teams', {
        'id': name,
        'name': name,
        'created_at': '2026-10-14',
      });
    }
    await db.insert('meta', {'key': 'outbox_demo', 'value': 'pending'});
  });
  tearDown(() => db.close());
  final incoming = BackupPayload(
    version: 2,
    exportedAt: DateTime(2026),
    team: const {'id': 'new', 'name': 'Importé', 'created_at': '2026-10-14'},
    players: const [],
    sessions: const [],
    participations: const [],
  );
  for (final change in ['add', 'remove', 'rename']) {
    test(
      'UX01-13 stale group confirmation is rejected atomically: $change',
      () async {
        final reviewed = {'Alpha': 'Alpha', 'Bêta': 'Bêta'};
        switch (change) {
          case 'add':
            await db.insert('teams', {
              'id': 'third',
              'name': 'Nouveau',
              'created_at': '2026-10-14',
            });
          case 'remove':
            await db.delete('teams', where: 'id = ?', whereArgs: ['Bêta']);
          case 'rename':
            await db.update(
              'teams',
              {'name': 'Renommé'},
              where: 'id = ?',
              whereArgs: ['Bêta'],
            );
        }
        final beforeTeams = await db.query('teams');
        final beforeMeta = await db.query('meta');
        await expectLater(
          service.restoreBackup(
            incoming,
            merge: false,
            expectedGroups: reviewed,
          ),
          throwsStateError,
        );
        expect(await db.query('teams'), beforeTeams);
        expect(await db.query('meta'), beforeMeta);
      },
    );
  }
  test(
    'UX01-06 matching confirmation permits exactly the reviewed replacement',
    () async {
      await service.restoreBackup(
        incoming,
        merge: false,
        expectedGroups: {'Alpha': 'Alpha', 'Bêta': 'Bêta'},
      );
      expect((await db.query('teams')).single['id'], 'new');
      expect(await db.query('meta'), isEmpty);
    },
  );
}
