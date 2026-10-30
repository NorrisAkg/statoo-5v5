import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/features/settings/data/backup_service.dart';
import 'package:statoo/features/settings/data/group_settings_repository.dart';
import 'package:statoo/features/settings/domain/backup_payload.dart';
import 'package:statoo/features/team/data/team_repository.dart';

class CountingDatabase extends AppDatabase {
  CountingDatabase(super.db) : super.forTesting();
  int reads = 0;
  @override
  Future<Database> get database {
    reads++;
    return super.database;
  }
}

Map<String, dynamic> wire() => {
  'app': 'statoo_5v5',
  'version': 2,
  'team': {'id': 'incoming', 'name': 'Incoming', 'created_at': '2026-10-26'},
  'players': <dynamic>[],
  'sessions': <dynamic>[],
  'participations': <dynamic>[],
};

BackupPayload incoming(int version) => BackupPayload(
  version: version,
  exportedAt: DateTime(2026, 10, 26),
  team: const {
    'id': 'incoming',
    'name': 'Incoming',
    'created_at': '2026-10-26',
  },
  players: const [
    {
      'id': 'new-player',
      'team_id': 'incoming',
      'name': 'New',
      'created_at': '2026-10-26',
      'updated_at': '2026-10-26',
    },
  ],
  sessions: const [
    {
      'id': 'new-session',
      'team_id': 'incoming',
      'played_at': '2026-10-26',
      'status': 'DRAFT',
    },
  ],
  participations: const [
    {
      'id': 'new-part',
      'session_id': 'new-session',
      'player_id': 'new-player',
      'team': 'A',
    },
  ],
  minPlayersPerSession: 8,
);

void main() {
  for (final value in <Object?>[
    3,
    999,
    0,
    -1,
    '2',
    '999',
    null,
    true,
    2.0,
    [],
    {},
  ]) {
    test(
      'VER01 explicit version $value (${value.runtimeType}) is rejected',
      () {
        expect(
          () => BackupPayload.fromJson(wire()..['version'] = value),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('version'),
            ),
          ),
        );
      },
    );
  }
  test(
    'VER02 future version is refused before interpreting unknown teams shape',
    () {
      expect(
        () => BackupPayload.fromJson(
          wire()
            ..['version'] = 999
            ..['teams'] = 'unknown-format',
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('plus récente'),
          ),
        ),
      );
    },
  );
  test('VER09 future format is rejected before casting its app marker', () {
    final future = wire()
      ..['version'] = 999
      ..['app'] = {'unknown': 'future-shape'};
    expect(
      () => BackupPayload.fromJson(future),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('plus récente'),
        ),
      ),
    );
  });
  for (final version in [1, 2]) {
    test('VER03 supported version $version still parses', () {
      expect(
        BackupPayload.fromJson(wire()..['version'] = version).version,
        version,
      );
    });
    test(
      'VER07 supported object $version still exports in current v2 format',
      () {
        expect(incoming(version).toJson()['version'], 2);
      },
    );
  }
  test('VER03 missing version remains legacy v1', () {
    expect(BackupPayload.fromJson(wire()..remove('version')).version, 1);
  });
  for (final version in [0, -1, 3, 999]) {
    test(
      'VER07 serialization cannot launder unsupported object $version into v2',
      () {
        expect(
          () => incoming(version).toJson(),
          throwsA(isA<FormatException>()),
        );
      },
    );
  }

  group('Real restore boundary', () {
    late Database db;
    late CountingDatabase app;
    late BackupService service;
    late SharedPreferences prefs;
    Future<Map<String, Object?>> state() async {
      final tables = <String, Object?>{};
      for (final name in [
        'teams',
        'players',
        'sessions',
        'participations',
        'meta',
      ]) {
        tables[name] = await db.query(name, orderBy: 'rowid');
      }
      tables['preferences'] = {
        for (final key in prefs.getKeys()) key: prefs.get(key),
      };
      return tables;
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'active_team_id': 'local',
        'team_name': 'Local',
        'min_players_per_session': 6,
        'unrelated_preference': 'preserve',
      });
      prefs = await SharedPreferences.getInstance();
      sqfliteFfiInit();
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        ),
      );
      app = CountingDatabase(db);
      await app.initSchemaForTest(db);
      service = BackupService(app);
      for (final id in ['local', 'other']) {
        await db.insert('teams', {
          'id': id,
          'name': id,
          'created_at': '2026-10-25',
        });
      }
      await db.insert('players', {
        'id': 'local-player',
        'team_id': 'local',
        'name': 'Local player',
        'created_at': '2026-10-25',
        'updated_at': '2026-10-25',
      });
      await db.insert('sessions', {
        'id': 'local-session',
        'team_id': 'local',
        'played_at': '2026-10-25',
        'status': 'DRAFT',
      });
      await db.insert('participations', {
        'id': 'local-part',
        'session_id': 'local-session',
        'player_id': 'local-player',
        'team': 'A',
      });
      await db.insert('meta', {
        'key': 'outbox_keep',
        'value': '{"status":"pending"}',
      });
      await db.insert('meta', {'key': 'shared_group_other', 'value': '1'});
    });
    tearDown(() => db.close());

    for (final version in [0, -1, 3, 999]) {
      for (final merge in [false, true]) {
        test(
          'VER04/05 unsupported $version merge=$merge refuses before DB access and preserves all state',
          () async {
            final before = await state();
            await expectLater(
              service.restoreBackup(incoming(version), merge: merge),
              throwsA(
                isA<FormatException>().having(
                  (e) => e.message,
                  'message',
                  contains('version'),
                ),
              ),
            );
            expect(app.reads, 0);
            expect(await state(), before);
          },
        );
      }
    }
    for (final version in [1, 2]) {
      for (final merge in [false, true]) {
        test(
          'VER06 supported $version merge=$merge still restores actual data',
          () async {
            final result = await service.restoreBackup(
              incoming(version),
              merge: merge,
              targetTeamId: merge ? 'local' : null,
            );
            expect(result.isMerge, merge);
            expect(result.importedPlayersCount, 1);
            expect(
              await db.query('players', where: 'name = ?', whereArgs: ['New']),
              hasLength(1),
            );
            expect(
              await db.query(
                'sessions',
                where: 'played_at = ?',
                whereArgs: ['2026-10-26'],
              ),
              hasLength(1),
            );
            if (!merge) {
              expect((await db.query('teams')).single['id'], 'incoming');
              expect(await SqliteTeamRepository(AppDatabase.forTesting(db)).getActiveTeamId(), 'incoming');
              expect(await SqliteGroupSettingsRepository(AppDatabase.forTesting(db)).getInt('incoming', 'min_players_per_session'), 8);
            } else {
              expect(await db.query('teams'), hasLength(2));
              expect(
                await db.query(
                  'players',
                  where: 'id = ?',
                  whereArgs: ['local-player'],
                ),
                hasLength(1),
              );
            }
            expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
          },
        );
      }
    }
    test(
      'VER08 current export round trip keeps supported version and local data',
      () async {
        final exported = await service.createBackupPayload();
        expect(exported.version, 2);
        final parsed = BackupPayload.fromJson(exported.toJson());
        expect(parsed.version, 2);
        expect(parsed.teams, hasLength(2));
        expect(parsed.players.single['id'], 'local-player');
        expect(parsed.meta['outbox_keep'], '{"status":"pending"}');
      },
    );
  });
}
