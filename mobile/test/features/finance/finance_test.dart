import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/features/finance/data/finance_repository.dart';
import 'package:statoo/features/finance/domain/financial_point.dart';
import 'package:statoo/features/finance/domain/financial_defaults.dart';
import 'package:statoo/features/shared/data/shared_service.dart';

void main() {
  final date = DateTime(2026, 10, 10, 20);
  test(
    'cash, arrears and prepaid contributions remain separate from penalties',
    () {
      final p = FinancialPoint(
        playedAt: date,
        rate: 100,
        lines: const [
          FinancialLine(memberId: 'absent', contribution: 500, penaltyDue: 100),
          FinancialLine(
            memberId: 'present',
            contribution: 100,
            penaltyPaid: 50,
            penaltyDue: 50,
          ),
        ],
        donations: const [
          FinancialMovement(id: 'd', label: 'Don', amount: 200),
        ],
        expenses: const [FinancialMovement(id: 'e', label: 'Eau', amount: 300)],
      );
      p.validate();
      final result = FinancialTotals.calculate([p]);
      expect(result.cash, 550);
      expect(result.members['absent']!.advance, 400);
      expect(result.members['absent']!.penaltyDebt, 100);
      expect(result.members['present']!.penaltyDebt, 0);
    },
  );
  test('cancelled period consumes contribution advance, not cash', () {
    final point = FinancialPoint(
      playedAt: date,
      rate: 100,
      cancelled: true,
      lines: const [FinancialLine(memberId: 'a')],
    );
    point.validate();
    final totals = FinancialTotals.calculate(
      [point],
      openingCash: 1000,
      openingMembers: const {
        'a': MemberBalance(contributionBalance: 500, penaltyDebt: 200),
      },
    );
    expect(totals.cash, 1000);
    expect(totals.members['a']!.advance, 400);
    expect(totals.members['a']!.penaltyDebt, 200);
    expect(
      () => FinancialPoint(
        playedAt: date,
        rate: 100,
        cancelled: true,
        lines: const [FinancialLine(memberId: 'a', contribution: 100)],
      ).validate(),
      throwsFormatException,
    );
  });
  test('serialization retains distinct receipts, penalty obligations and expense IDs', () {
    final point = FinancialPoint(
      playedAt: date,
      rate: 100,
      lines: const [
        FinancialLine(
          memberId: 'a',
          contribution: 500,
          penaltyDue: 100,
          reason: 'Retard',
        ),
      ],
      expenses: const [
        FinancialMovement(id: 'water', label: 'Eau', amount: 300),
      ],
    );
    final restored = FinancialPoint.fromJson(point.toJson());
    expect(restored.toJson(), point.toJson());
  });

  group('SQLite corrections and local history', () {
    late Database db;
    late FinanceRepository repo;
    setUp(() async {
      sqfliteFfiInit();
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      final app = AppDatabase.forTesting(db);
      await app.initSchemaForTest(db);
      repo = FinanceRepository(app, SharedService(app));
      await db.insert('teams', {
        'id': 'g',
        'name': 'Groupe',
        'created_at': date.toIso8601String(),
      });
      await db.insert('players', {
        'id': 'a',
        'team_id': 'g',
        'name': 'Alice',
        'created_at': date.toIso8601String(),
        'updated_at': date.toIso8601String(),
      });
    });
    tearDown(() async {
      await db.close();
    });
    test(
      'group defaults are isolated and only new periods use the new rate',
      () async {
        await repo.savePoint(
          'g',
          'old',
          FinancialPoint(
            playedAt: date,
            rate: 100,
            lines: const [FinancialLine(memberId: 'a')],
          ),
        );
        await repo.saveDefaults(
          'g',
          const FinancialDefaults(contribution: 200, latePenalty: 50),
        );
        expect((await repo.getDefaults('g')).latePenalty, 50);
        expect((await repo.getDefaults('other')).contribution, 100);
        expect((await repo.prepare('g', 'old', date)).rate, 100);
        final future = await repo.prepare(
          'g',
          'future',
          date.add(const Duration(days: 7)),
        );
        expect(future.rate, 200);
        expect(future.received, 0);
        expect(future.lines.single.penaltyDue, 0);
        await expectLater(
          repo.saveDefaults('g', const FinancialDefaults(contribution: -1)),
          throwsFormatException,
        );
      },
    );
    test(
      'correction replaces totals once and preserves an audit trail',
      () async {
        await repo.savePoint(
          'g',
          's',
          FinancialPoint(
            playedAt: date,
            rate: 100,
            lines: const [FinancialLine(memberId: 'a', contribution: 500)],
          ),
        );
        await expectLater(
          repo.savePoint(
            'g',
            's',
            FinancialPoint(
              playedAt: date,
              rate: 100,
              lines: const [FinancialLine(memberId: 'a', contribution: 600)],
            ),
          ),
          throwsFormatException,
        );
        await repo.savePoint(
          'g',
          's',
          FinancialPoint(
            playedAt: date,
            rate: 100,
            lines: const [FinancialLine(memberId: 'a', contribution: 600)],
          ),
          reason: 'Montant corrigé',
        );
        expect(FinancialTotals.calculate(await repo.allPoints('g')).cash, 600);
        expect(
          (await db.query(
            'meta',
            where: 'substr(key,1,16) = ?',
            whereArgs: ['finance_history_'],
          )).length,
          2,
        );
        expect(await repo.allPoints('other'), isEmpty);
      },
    );
  });
}
