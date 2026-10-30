import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/core/data/occurrence_registry.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late Database db;
  final testDate = DateTime(2026, 10, 30, 14);

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    final app = AppDatabase.forTesting(db);
    await app.initSchemaForTest(db);

    // Setup teams for multi-tenant testing
    for (final teamId in ['team-A', 'team-B']) {
      await db.insert('teams', {
        'id': teamId,
        'name': 'Team $teamId',
        'created_at': testDate.toIso8601String(),
      });
    }
  });

  tearDown(() async {
    await db.close();
  });

  group('nextFreeOccurrenceReference', () {
    test('returns suffix 1 when no occurrences exist for group and date', () async {
      final ref = await nextFreeOccurrenceReference(db, 'team-A', testDate);
      expect(ref, '2026-10-30-1');
    });

    test('avoids collision with existing finance aliases', () async {
      await db.insert('meta', {
        'key': 'shared_finance_alias_team-A_2026-10-30-1',
        'value': 'p1',
      });

      final ref = await nextFreeOccurrenceReference(db, 'team-A', testDate);
      expect(ref, '2026-10-30-2');
    });

    test('avoids collision with existing session occurrences in meta', () async {
      await db.insert('sessions', {
        'id': 's1',
        'team_id': 'team-A',
        'played_at': testDate.toIso8601String(),
        'status': 'DRAFT',
      });
      await db.insert('meta', {
        'key': 'shared_occurrence_s1',
        'value': '2026-10-30-1',
      });

      final ref = await nextFreeOccurrenceReference(db, 'team-A', testDate);
      expect(ref, '2026-10-30-2');
    });

    test('avoids collision across multiple aliases and sessions', () async {
      // Alias 2026-10-30-1
      await db.insert('meta', {
        'key': 'shared_finance_alias_team-A_2026-10-30-1',
        'value': 'p1',
      });
      // Session 2026-10-30-2
      await db.insert('sessions', {
        'id': 's2',
        'team_id': 'team-A',
        'played_at': testDate.toIso8601String(),
        'status': 'DRAFT',
      });
      await db.insert('meta', {
        'key': 'shared_occurrence_s2',
        'value': '2026-10-30-2',
      });

      final ref = await nextFreeOccurrenceReference(db, 'team-A', testDate);
      expect(ref, '2026-10-30-3');
    });

    test('fills holes when numbers are non-contiguous', () async {
      // 1 and 3 are taken
      await db.insert('meta', {
        'key': 'shared_finance_alias_team-A_2026-10-30-1',
        'value': 'p1',
      });
      await db.insert('meta', {
        'key': 'shared_finance_alias_team-A_2026-10-30-3',
        'value': 'p3',
      });

      final ref = await nextFreeOccurrenceReference(db, 'team-A', testDate);
      expect(ref, '2026-10-30-2');
    });

    test('preserves multi-tenant isolation (does not collide across groups)', () async {
      await db.insert('meta', {
        'key': 'shared_finance_alias_team-A_2026-10-30-1',
        'value': 'p1',
      });

      final refTeamB = await nextFreeOccurrenceReference(db, 'team-B', testDate);
      expect(refTeamB, '2026-10-30-1');
    });

    test('isolates different dates', () async {
      await db.insert('meta', {
        'key': 'shared_finance_alias_team-A_2026-10-30-1',
        'value': 'p1',
      });

      final nextDay = DateTime(2026, 10, 31, 10);
      final ref = await nextFreeOccurrenceReference(db, 'team-A', nextDay);
      expect(ref, '2026-10-31-1');
    });
  });
}
