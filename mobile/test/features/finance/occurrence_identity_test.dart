import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/features/finance/data/finance_repository.dart';
import 'package:statoo/features/finance/domain/financial_point.dart';
import 'package:statoo/features/sessions/data/sessions_repository.dart';
import 'package:statoo/features/sessions/domain/session.dart';
import 'package:statoo/features/shared/data/shared_service.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  late Database db;
  late FinanceRepository finance;
  late SqliteSessionsRepository sessions;
  final date = DateTime(2026, 10, 14, 18);
  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    final app = AppDatabase.forTesting(db);
    await app.initSchemaForTest(db);
    finance = FinanceRepository(app, SharedService(app));
    sessions = SqliteSessionsRepository(app);
    for (final g in ['g', 'h']) {
      await db.insert('teams', {
        'id': g,
        'name': g,
        'created_at': date.toIso8601String(),
      });
      await db.insert('players', {
        'id': 'p$g',
        'team_id': g,
        'name': g,
        'created_at': date.toIso8601String(),
        'updated_at': date.toIso8601String(),
      });
    }
  });
  tearDown(() => db.close());
  Future<String> reference(String id) async =>
      (await db.query(
            'meta',
            where: 'key = ?',
            whereArgs: ['shared_occurrence_$id'],
          )).single['value']!
          as String;
  Future<void> save(String id, {String group = 'g'}) => sessions.saveSession(
    Session(id: id, playedAt: date),
    [],
    teamId: group,
  );

  test(
    'UX03-01/02/04 references reserved at creation, stable on reverse reads',
    () async {
      for (final id in ['s1', 's2', 's3']) {
        await save(id);
      }
      expect(await reference('s1'), '2026-10-14-1');
      expect(await reference('s2'), '2026-10-14-2');
      expect(await reference('s3'), '2026-10-14-3');
      expect(await finance.canonical('g', 's3'), 's3');
      expect(await finance.canonical('g', 's1'), 's1');
      await save('s1');
      expect(await reference('s1'), '2026-10-14-1');
    },
  );
  test('UX03-05 concurrent creations reserve different references', () async {
    await Future.wait([save('s1'), save('s2'), save('s3')]);
    expect(
      {
        await reference('s1'),
        await reference('s2'),
        await reference('s3'),
      }.length,
      3,
    );
  });
  test('UX03-07 group sequences are isolated', () async {
    await save('s1');
    await save('s2', group: 'h');
    expect(await reference('s1'), '2026-10-14-1');
    expect(await reference('s2'), '2026-10-14-1');
    expect(await finance.canonical('h', 's2'), 's2');
  });
  test('UX03-11/13 existing explicit shared aliases are preserved', () async {
    for (final id in ['s1', 's2']) {
      await db.insert('meta', {
        'key': 'shared_occurrence_$id',
        'value': 'custom',
      });
      await save(id);
    }
    expect(await finance.canonical('g', 's2'), 's1');
    expect(await reference('s2'), 'custom');
  });
  test('UX03-14/16 legacy sessions without reference stay distinct in pending list', () async {
    for (final id in ['s1', 's2']) {
      await db.insert('sessions', {
        'id': id,
        'team_id': 'g',
        'played_at': date.toIso8601String(),
        'status': 'DRAFT',
      });
    }
    final pending = await finance.pendingPeriods('g', asOf: date);
    expect(pending.map((p) => p.sessionId).toSet(), {'s1', 's2'});
    final ids = await Future.wait([
      finance.canonical('g', 's1'),
      finance.canonical('g', 's2'),
    ]);
    expect(ids.toSet(), {'s1', 's2'});
  });
  test('UX03-15 separate payments never overwrite first point', () async {
    await save('s1');
    await save('s2');
    for (final entry in {'s1': 100, 's2': 50}.entries) {
      await finance.savePoint(
        'g',
        entry.key,
        FinancialPoint(
          playedAt: date,
          rate: 100,
          lines: [FinancialLine(memberId: 'pg', contribution: entry.value)],
        ),
      );
    }
    expect((await finance.getPoint('g', 's1'))!.contributions, 100);
    expect((await finance.getPoint('g', 's2'))!.contributions, 50);
    final totals = FinancialTotals.calculate(await finance.allPoints('g'));
    expect(totals.cash, 150);
    expect(totals.members['pg']!.contributionBalance, -50);
  });
  test(
    'UX03-03 allocator uses first hole without overwriting explicit references',
    () async {
      for (final n in [1, 3]) {
        await db.insert('meta', {
          'key': 'shared_occurrence_s$n',
          'value': '2026-10-14-$n',
        });
        await save('s$n');
      }
      await save('next');
      expect(await reference('next'), '2026-10-14-2');
    },
  );
  test('UX03-17/20 concurrent manual periods with same reference create exactly one point', () async {
    Future<bool> attempt() async {
      try {
        await finance.createPeriod('g', date, 'weekly');
        return true;
      } on FormatException {
        return false;
      }
    }

    final results = await Future.wait([attempt(), attempt()]);
    expect(results.where((r) => r).length, 1);
    expect((await finance.periods('g')).length, 1);
    expect(
      (await db.query(
        'meta',
        where: 'key LIKE ?',
        whereArgs: ['shared_occurrence_period_%'],
      )).length,
      1,
    );
  });
}
