import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/features/team/data/team_repository.dart';
import 'package:statoo/features/team/domain/team_info.dart';
import 'package:statoo/main.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('PERF-01 SQLite Lifecycle Management', () {
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tempDir = await Directory.systemTemp.createTemp('statoo-lifecycle-test-');
      await databaseFactory.setDatabasesPath(tempDir.path);
    });

    tearDown(() async {
      await AppDatabase.instance.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('LIFECYCLE-01 close() releases database connection and reopens transparently', () async {
      final db = await AppDatabase.instance.database;
      expect(db.isOpen, isTrue);

      final repo = SqliteTeamRepository(AppDatabase.instance);
      await repo.saveTeamInfo(
        TeamInfo(
          id: 'test-team',
          name: 'FC Test',
          createdAt: DateTime.now(),
        ),
      );

      // Explicit close (simulating background suspend)
      await AppDatabase.instance.close();
      expect(db.isOpen, isFalse);

      // Re-accessing database must reopen seamlessly
      final reopenedDb = await AppDatabase.instance.database;
      expect(reopenedDb.isOpen, isTrue);

      final team = await repo.getTeamInfo();
      expect(team?.id, 'test-team');
      expect(team?.name, 'FC Test');
    });

    test('LIFECYCLE-02 handleLifecycle(paused and detached) closes database', () async {
      final db = await AppDatabase.instance.database;
      expect(db.isOpen, isTrue);

      // Inactive or resumed must not close the database
      await AppDatabase.instance.handleLifecycle(AppLifecycleState.inactive);
      expect(db.isOpen, isTrue);

      await AppDatabase.instance.handleLifecycle(AppLifecycleState.resumed);
      expect(db.isOpen, isTrue);

      // Paused must close
      await AppDatabase.instance.handleLifecycle(AppLifecycleState.paused);
      expect(db.isOpen, isFalse);

      // Next query reopens
      final reopenedDb = await AppDatabase.instance.database;
      expect(reopenedDb.isOpen, isTrue);

      // Detached must close
      await AppDatabase.instance.handleLifecycle(AppLifecycleState.detached);
      expect(db.isOpen, isFalse);

      // Next query reopens again seamlessly
      final reopenedDb2 = await AppDatabase.instance.database;
      expect(reopenedDb2.isOpen, isTrue);
    });

    test('LIFECYCLE-03 AppLifecycleObserver delegates paused transition to close database', () async {
      final db = await AppDatabase.instance.database;
      expect(db.isOpen, isTrue);

      AppLifecycleObserver().didChangeAppLifecycleState(AppLifecycleState.paused);

      // Wait a microtask for unawaited async close to complete
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(db.isOpen, isFalse);

      final reopened = await AppDatabase.instance.database;
      expect(reopened.isOpen, isTrue);
    });
  });
}
