import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/features/shared/data/shared_service.dart';

void main() {
  late Database db;
  late SharedService shared;
  setUp(() async {
    sqfliteFfiInit();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    final app = AppDatabase.forTesting(db);
    await app.initSchemaForTest(db);
    shared = SharedService(app)
      ..identity = {
        'group_id': 'g',
        'expires_at': DateTime.now()
            .toUtc()
            .add(const Duration(days: 30))
            .toIso8601String(),
        'account': {
          'id': 'writer',
          'roles': ['SG'],
          'shared': false,
        },
      };
  });
  tearDown(() async {
    shared.dispose();
    await db.close();
  });
  test('read-only collective and foreign group cannot write', () async {
    await expectLater(shared.requireWrite('other', 'sport'), throwsStateError);
    shared.identity!['account'] = {
      'id': 'shared',
      'roles': ['MEMBER'],
      'shared': true,
    };
    await expectLater(shared.requireWrite('g', 'sport'), throwsStateError);
    await expectLater(shared.requireWrite('g', 'finance'), throwsStateError);
    shared.identity = null;
    shared.protectedGroups.add('g');
    await expectLater(shared.requireWrite('g', 'sport'), throwsStateError);
  });
  test(
    'pending versions coalesce; attempted transmission is immutable for retry',
    () async {
      final payload = {
        'session': {'played_at': '2026-10-10T20:00:00'},
        'participations': <dynamic>[],
      };
      await db.transaction(
        (txn) => shared.enqueue(txn, 'g', 'sport', 's', payload),
      );
      await db.transaction(
        (txn) => shared.enqueue(txn, 'g', 'sport', 's', payload),
      );
      var rows = await db.query(
        'meta',
        where: 'substr(key,1,7) = ?',
        whereArgs: ['outbox_'],
      );
      expect(rows.length, 1);
      final previous =
          jsonDecode(rows.single['value']! as String) as Map<String, dynamic>
            ..['attempted'] = true;
      await db.update(
        'meta',
        {'value': jsonEncode(previous)},
        where: 'key = ?',
        whereArgs: [rows.single['key']],
      );
      await db.transaction(
        (txn) => shared.enqueue(txn, 'g', 'sport', 's', payload),
      );
      rows = await db.query(
        'meta',
        where: 'substr(key,1,7) = ?',
        whereArgs: ['outbox_'],
      );
      expect(rows.length, 2);
      await expectLater(
        shared.requireWrite('g', 'sport', sessionId: 's'),
        completes,
      );
      await db.update(
        'meta',
        {'value': 'other'},
        where: 'key = ?',
        whereArgs: ['shared_owner_sport_s'],
      );
      await expectLater(
        shared.requireWrite('g', 'sport', sessionId: 's'),
        throwsStateError,
      );
    },
  );
  test(
    'restored shared marker prevents writes before restarting the service',
    () async {
      shared.identity = null;
      await db.insert('meta', {'key': 'shared_group_g', 'value': '1'});
      await expectLater(shared.requireWrite('g', 'sport'), throwsStateError);
    },
  );
  test('obligations are imported for absent members without cross-group alias collisions', () async {
    final data = <String, dynamic>{
      'name': 'Groupe',
      'members': <dynamic>[],
      'documents': <String, dynamic>{},
      'obligations': {
        '2026-10-10-1': {
          'played_at': '2026-10-10T20:00:00',
          'rate': 100,
          'cancelled': false,
          'lines': [
            {
              'member_id': 'absent',
              'contribution': 0,
              'penalty_paid': 0,
              'penalty_due': 0,
              'reason': '',
            },
          ],
          'expenses': <dynamic>[],
          'donations': <dynamic>[],
        },
      },
    };
    await shared.importSnapshot(data);
    final first = await db.query(
      'meta',
      where: 'key = ?',
      whereArgs: ['shared_finance_alias_g_2026-10-10-1'],
    );
    shared.identity!['group_id'] = 'other';
    await shared.importSnapshot(data);
    final second = await db.query(
      'meta',
      where: 'key = ?',
      whereArgs: ['shared_finance_alias_other_2026-10-10-1'],
    );
    expect(first.single['value'], isNot(second.single['value']));
    final points = await db.query(
      'meta',
      where: 'key = ?',
      whereArgs: ['finance_point_g_${first.single['value']}'],
    );
    expect(
      (jsonDecode(points.single['value']! as String) as Map)['lines'],
      hasLength(1),
    );
  });
}
