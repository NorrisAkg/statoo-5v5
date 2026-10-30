import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:statoo/core/data/app_database.dart';

const _expectedViews = [
  'v_group_totals',
  'v_player_match_results',
  'v_standings',
  'v_standings_per_match',
  'v_top_assists',
  'v_top_cards',
  'v_top_scorers',
];

const _expectedTriggers = [
  'trg_participations_same_team_insert',
  'trg_participations_same_team_update',
];

Future<Map<String, Object?>> _openInIsolate(String directory) =>
    Isolate.run(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      await databaseFactory.setDatabasesPath(directory);
      final db = await AppDatabase.instance.database;
      try {
        final version = await db.getVersion();
        final views = (await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='view' ORDER BY name",
        )).map((r) => r['name']! as String).toList();
        final triggers = (await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='trigger' ORDER BY name",
        )).map((r) => r['name']! as String).toList();

        return {
          'version': version,
          'views': views,
          'triggers': triggers,
        };
      } finally {
        await db.close();
      }
    });

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('DATA-01 Versioned SQL Views and Triggers in AppDatabase', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('statoo-views-test-');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('VVIEW01 fresh install initializes schema v8 with all 7 views and triggers', () async {
      final info = await _openInIsolate(tempDir.path);
      final version = info['version']! as int;
      final views = info['views']! as List<String>;
      final triggers = info['triggers']! as List<String>;

      expect(version, 8);
      expect(views, _expectedViews);
      expect(triggers, _expectedTriggers);
    });

    test('VVIEW02 reopening existing database preserves views idempotently', () async {
      // First open
      await _openInIsolate(tempDir.path);

      // Reopen
      final info = await _openInIsolate(tempDir.path);
      final views = info['views']! as List<String>;
      final triggers = info['triggers']! as List<String>;

      expect(views, _expectedViews);
      expect(triggers, _expectedTriggers);
    });

    test('VVIEW03 missing view in sqlite_master triggers self-healing restoration', () async {
      // First open
      await _openInIsolate(tempDir.path);

      // Drop one view manually
      final db = await databaseFactory.openDatabase(
        '${tempDir.path}/statoo.db',
      );
      await db.execute('DROP VIEW IF EXISTS v_standings');
      final viewsBefore = (await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='view' ORDER BY name",
      )).map((r) => r['name']! as String).toList();
      expect(viewsBefore.contains('v_standings'), isFalse);
      await db.close();

      // Reopen through application singleton: should detect missing view and restore
      final info = await _openInIsolate(tempDir.path);
      final viewsAfter = info['views']! as List<String>;

      expect(viewsAfter.contains('v_standings'), isTrue);
      expect(viewsAfter, _expectedViews);
    });

    test('VVIEW04 missing tenant trigger in sqlite_master triggers self-healing restoration', () async {
      // First open
      await _openInIsolate(tempDir.path);

      // Drop one trigger manually
      final db = await databaseFactory.openDatabase(
        '${tempDir.path}/statoo.db',
      );
      await db.execute('DROP TRIGGER IF EXISTS trg_participations_same_team_insert');
      final triggersBefore = (await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='trigger' ORDER BY name",
      )).map((r) => r['name']! as String).toList();
      expect(triggersBefore.contains('trg_participations_same_team_insert'), isFalse);
      await db.close();

      // Reopen: should detect missing trigger and restore
      final info = await _openInIsolate(tempDir.path);
      final triggersAfter = info['triggers']! as List<String>;

      expect(triggersAfter.contains('trg_participations_same_team_insert'), isTrue);
      expect(triggersAfter, _expectedTriggers);
    });
  });
}
