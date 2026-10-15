import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/features/shared/data/shared_service.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  late Database db;
  late SharedService service;
  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    final app = AppDatabase.forTesting(db);
    await app.initSchemaForTest(db);
    service = SharedService(app)..protectedGroups.add('g');
  });
  tearDown(() async {
    service.dispose();
    await db.close();
  });
  void identity(List<String> roles, {String expiry = '2099-01-01T00:00:00Z'}) {
    service.identity = {
      'group_id': 'g',
      'expires_at': expiry,
      'account': {'id': 'me', 'roles': roles, 'shared': false},
    };
  }

  const allowed = {
    'MEMBER': <String>[],
    'CENSOR': <String>[],
    'PDT': <String>[],
    'VP': <String>[],
    'ADMIN': ['members', 'finance_settings'],
    'SG': ['sport'],
    'SGA': ['sport'],
    'TR': ['finance', 'finance_settings'],
    'TGA': ['finance', 'finance_settings'],
  };
  for (final role in allowed.entries) {
    test(
      'UX06-01 role ${role.key} same UI and execution capabilities',
      () async {
        identity([role.key]);
        for (final domain in [
          'members',
          'sport',
          'finance',
          'finance_settings',
        ]) {
          final yes = role.value.contains(domain);
          expect(service.canWrite('g', domain), yes);
          if (yes) {
            await service.requireWrite('g', domain);
          } else {
            await expectLater(
              service.requireWrite('g', domain),
              throwsStateError,
            );
          }
        }
      },
    );
  }
  test('UX06-11 expired or malformed identity never grants UI write', () async {
    for (final expiry in ['2000-01-01T00:00:00Z', 'invalid']) {
      identity(['ADMIN', 'SG'], expiry: expiry);
      expect(service.canWrite('g', 'sport'), isFalse);
      await expectLater(service.requireWrite('g', 'sport'), throwsStateError);
    }
  });
  test(
    'UX06-12/13 unrelated local group remains writable with remote identity',
    () async {
      await db.insert('teams', {
        'id': 'local',
        'name': 'Local autonome',
        'created_at': '2026-10-14',
      });
      identity(['MEMBER']);
      expect(service.canWrite('local', 'sport'), isTrue);
      await service.requireWrite('local', 'sport');
    },
  );
  test(
    'UX06-14 protected group with identity for another group remains readonly',
    () async {
      identity(['ADMIN', 'SG']);
      service.protectedGroups.add('other');
      expect(service.canWrite('other', 'sport'), isFalse);
      await expectLater(
        service.requireWrite('other', 'sport'),
        throwsStateError,
      );
    },
  );
  test('UX06-16 restored marker prevents disconnected write', () async {
    await db.insert('meta', {'key': 'shared_group_restored', 'value': '1'});
    await expectLater(
      service.requireWrite('restored', 'sport'),
      throwsStateError,
    );
    expect(service.canWrite('restored', 'sport'), isFalse);
  });
}
