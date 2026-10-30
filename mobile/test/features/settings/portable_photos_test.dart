import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/features/settings/data/backup_service.dart';
import 'package:statoo/features/settings/domain/backup_payload.dart';

const tinyPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);
  late Database db;
  late BackupService service;
  late Directory directory;
  Map<String, dynamic> player(String? photo, {String id = 'p'}) => {
    'id': id,
    'team_id': 't',
    'name': id,
    'created_at': '2026-10-27',
    'updated_at': '2026-10-27',
    'avatar_url': photo,
  };
  BackupPayload payload(String? photo, {int version = 2}) => BackupPayload(
    version: version,
    exportedAt: DateTime(2026),
    team: const {'id': 't', 'name': 'Team', 'created_at': '2026-10-27'},
    players: [player(photo)],
    sessions: const [],
    participations: const [],
  );
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('statoo-photo-');
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    final app = AppDatabase.forTesting(db);
    await app.initSchemaForTest(db);
    service = BackupService(app);
    await db.insert('teams', {
      'id': 't',
      'name': 'Team',
      'created_at': '2026-10-27',
    });
  });
  tearDown(() async {
    await db.close();
    await directory.delete(recursive: true);
  });
  test(
    'local PNG export survives loss of source and another database',
    () async {
      final file = await File('${directory.path}/portrait.png')
          .writeAsBytes(base64Decode(tinyPng));
      await db.insert('players', player(file.path));
      final exported = await service.createBackupPayload();
      expect(
        exported.players.single['avatar_url'],
        'data:image/png;base64,$tinyPng',
      );
      expect((await db.query('players')).single['avatar_url'], file.path);
      await file.delete();
      final other = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      try {
        final app = AppDatabase.forTesting(other);
        await app.initSchemaForTest(other);
        await BackupService(app).restoreBackup(
          BackupPayload.fromJson(
            jsonDecode(jsonEncode(exported.toJson())) as Map<String, dynamic>,
          ),
          merge: false,
        );
        expect(
          (await other.query('players')).single['avatar_url'],
          'data:image/png;base64,$tinyPng',
        );
      } finally {
        await other.close();
      }
    },
  );
  for (final value in [
    null,
    'data:image/png;base64,$tinyPng',
    'https://example.invalid/photo.jpg',
  ]) {
    for (final version in [1, 2]) {
      test('legacy v$version round trip ${value?.substring(0, 10)}', () async {
        await service.restoreBackup(
          payload(value, version: version),
          merge: false,
        );
        expect(
          (await service.createBackupPayload()).players.single['avatar_url'],
          value,
        );
      });
    }
  }
  for (final kind in ['missing', 'corrupt', 'large']) {
    test('export refuses $kind local photo without mutation', () async {
      final file = File('${directory.path}/$kind.png');
      if (kind == 'corrupt') await file.writeAsString('not an image');
      if (kind == 'large') {
        await file.writeAsBytes(Uint8List(2 * 1024 * 1024 + 1));
      }
      await db.insert('players', player(file.path));
      await expectLater(
        service.createBackupPayload(),
        throwsA(isA<FormatException>()),
      );
      expect((await db.query('players')).single['avatar_url'], file.path);
    });
  }
  for (final photo in [
    'data:image/png;base64,???',
    'data:image/png;base64,SGVsbG8=',
    'data:image/svg+xml;base64,PHN2Zy8+',
  ]) {
    test('invalid embedded photo rejects restore atomically $photo', () async {
      await db.insert('players', player(null, id: 'old'));
      await expectLater(
        service.restoreBackup(payload(photo), merge: false),
        throwsA(isA<FormatException>()),
      );
      expect((await db.query('players')).single['id'], 'old');
    });
  }
  for (final path in [
    '/private/photo.png',
    'file:///private/photo.png',
    'blob:old-browser',
    r'C:\old\photo.png',
  ]) {
    test('legacy path is not imported $path', () async {
      final result = await service.restoreBackup(payload(path), merge: false);
      expect(result.unavailablePhotosCount, 1);
      expect(result.photoWarning, contains('1'));
      expect((await db.query('players')).single['avatar_url'], isNull);
    });
  }
  test('image budget rejects a large collection before SQL changes', () async {
    final bytes = Uint8List(2 * 1024 * 1024)..setAll(0, base64Decode(tinyPng));
    final photo = 'data:image/png;base64,${base64Encode(bytes)}';
    final original = payload(photo);
    final large = BackupPayload(
      version: 2,
      exportedAt: original.exportedAt,
      team: original.team,
      players: List.generate(17, (i) => player(photo, id: 'p$i')),
      sessions: const [],
      participations: const [],
    );
    await expectLater(
      service.restoreBackup(large, merge: false),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'budget',
          contains('32 Mio'),
        ),
      ),
    );
    expect(await db.query('players'), isEmpty);
  });
  test(
    'merge does not warn about a discarded photo of a reused player',
    () async {
      await db.insert(
        'players',
        player('https://example.invalid/existing.jpg'),
      );
      final result = await service.restoreBackup(
        payload('/old/device/photo.png'),
        merge: true,
      );
      expect(result.unavailablePhotosCount, 0);
      expect(result.photoWarning, isEmpty);
    },
  );
  test('merge inserts a new player with embedded photo', () async {
    await db.insert('players', player(null, id: 'existing'));
    final result = await service.restoreBackup(
      payload('data:image/png;base64,$tinyPng'),
      merge: true,
    );
    expect(result.importedPlayersCount, 1);
    expect(await db.query('players'), hasLength(2));
    expect(
      (await db.query(
        'players',
        where: 'id = ?',
        whereArgs: ['p'],
      )).single['avatar_url'],
      'data:image/png;base64,$tinyPng',
    );
  });
  test('merge keeps the existing photo of a reused player', () async {
    await db.insert('players', player('https://example.invalid/existing.jpg'));
    await service.restoreBackup(
      payload('data:image/png;base64,$tinyPng'),
      merge: true,
    );
    expect(
      (await db.query('players')).single['avatar_url'],
      'https://example.invalid/existing.jpg',
    );
  });
}
