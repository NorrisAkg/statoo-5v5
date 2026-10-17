import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/features/team/data/team_repository.dart';
import 'package:statoo/features/team/domain/team_info.dart';
import 'package:statoo/features/settings/data/backup_service.dart';

void main() {
  for (final existing in [false, true]) {
    test(
      'PAR23 merge preserves short names (existing target: $existing)',
      () async {
        sqfliteFfiInit();
        SharedPreferences.setMockInitialValues({});
        final sourceDb = await databaseFactoryFfi.openDatabase(
          inMemoryDatabasePath,
          options: OpenDatabaseOptions(singleInstance: false),
        );
        final source = AppDatabase.forTesting(sourceDb);
        await source.initSchemaForTest(sourceDb);
        final targetDb = await databaseFactoryFfi.openDatabase(
          inMemoryDatabasePath,
          options: OpenDatabaseOptions(singleInstance: false),
        );
        final target = AppDatabase.forTesting(targetDb);
        await target.initSchemaForTest(targetDb);
        addTearDown(() async {
          await sourceDb.close();
          await targetDb.close();
        });
        await SqliteTeamRepository(source).saveTeamInfo(
          TeamInfo.fromMap({
            'id': 'g',
            'name': 'Football Club',
            'short_name': 'FC',
            'created_at': '2026-10-16',
          }),
        );
        final payload = await BackupService(source).createBackupPayload();
        if (existing)
          await SqliteTeamRepository(target).saveTeamInfo(
            TeamInfo.fromMap({
              'id': 'target',
              'name': 'Target',
              'short_name': 'TC',
              'created_at': '2026-10-16',
            }),
          );
        await BackupService(target).restoreBackup(
          payload,
          merge: true,
          targetTeamId: existing ? 'target' : null,
        );
        final team = await SqliteTeamRepository(target)
            .getTeamById(existing ? 'target' : 'g');
        expect(team!.toMap()['short_name'], existing ? 'TC' : 'FC');
      },
    );
  }
  test(
    'PAR23 local short name survives reload and enters the common backup',
    () async {
      sqfliteFfiInit();
      SharedPreferences.setMockInitialValues({});
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await db.execute('PRAGMA foreign_keys = ON');
      final app = AppDatabase.forTesting(db);
      await app.initSchemaForTest(db);
      addTearDown(db.close);
      final repo = SqliteTeamRepository(app);
      await repo.saveTeamInfo(
        TeamInfo.fromMap({
          'id': 'g',
          'name': 'Football Club',
          'short_name': ' FC ',
          'created_at': '2026-10-16',
        }),
      );
      expect((await repo.getTeamById('g'))!.toMap()['short_name'], 'FC');
      expect((await repo.getAllTeams()).single.toMap()['short_name'], 'FC');
      expect(
        (await BackupService(
          app,
        ).createBackupPayload()).meta['team_short_name_g'],
        'FC',
      );
      await db.insert('players', {
        'id': 'p',
        'team_id': 'g',
        'name': 'Alice',
        'created_at': '2026-10-16',
        'updated_at': '2026-10-16',
      });
      await repo.saveTeamInfo(
        TeamInfo.fromMap({
          'id': 'g',
          'name': 'Football Club',
          'short_name': '',
          'created_at': '2026-10-16',
        }),
      );
      expect((await repo.getTeamById('g'))!.toMap()['short_name'], '');
      expect(
        await db.query('players'),
        hasLength(1),
        reason: 'Updating the group identity must preserve its members',
      );
    },
  );
}
