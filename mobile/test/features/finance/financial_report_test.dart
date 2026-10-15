import 'package:flutter_test/flutter_test.dart';
import 'package:statoo/features/finance/domain/financial_point.dart';
import 'package:statoo/features/finance/domain/financial_report.dart';

void main() {
  final today = DateTime(2026, 10, 14);
  test('expected includes five contributions and assessed penalties', () {
    final report = FinancialReport.calculate([
      for (var i = 0; i < 5; i++)
        FinancialPoint(
          playedAt: today.subtract(Duration(days: i)),
          rate: 100,
          lines: [
            FinancialLine(
              memberId: 'a',
              contribution: i == 0 ? 500 : 0,
              penaltyDue: i == 0 ? 300 : 0,
            ),
          ],
        ),
    ], asOf: today);
    final member = report.members['a']!;
    expect(member.paid, 500);
    expect(member.expected, 800);
    expect(member.difference, -300);
    expect(member.amountToSettle, 300);
  });
  for (final advance in [100, 300]) {
    test(
      'advance $advance never settles penalty even with nonnegative net',
      () {
        final member = MemberFinancialPosition(
          contributionsPaid: 100 + advance,
          contributionsExpected: 100,
          penaltiesExpected: 100,
        );
        expect(member.difference, advance - 100);
        expect(member.isUpToDate, false);
        expect(member.amountToSettle, 100);
      },
    );
  }
  test('frozen rates, roster and end-of-day cutoff are respected', () {
    final report = FinancialReport.calculate([
      FinancialPoint(
        playedAt: today.subtract(const Duration(days: 7)),
        rate: 100,
        lines: const [FinancialLine(memberId: 'a')],
      ),
      FinancialPoint(
        playedAt: DateTime(2026, 10, 14, 20),
        rate: 200,
        lines: const [
          FinancialLine(memberId: 'a'),
          FinancialLine(memberId: 'b'),
        ],
      ),
      FinancialPoint(
        playedAt: DateTime(2026, 10, 15),
        rate: 900,
        lines: const [FinancialLine(memberId: 'a')],
      ),
    ], asOf: today);
    expect(report.members['a']!.expected, 300);
    expect(report.members['b']!.expected, 200);
  });
  test(
    'cancelled period carries dues without cash and opening is separate',
    () {
      final report = FinancialReport.calculate(
        [
          FinancialPoint(
            playedAt: today,
            rate: 100,
            cancelled: true,
            lines: const [FinancialLine(memberId: 'a')],
          ),
        ],
        asOf: today,
        openingCash: 1000,
        openingMembers: const {
          'a': MemberBalance(contributionBalance: 500, penaltyDebt: 200),
        },
      );
      expect(report.cash, 1000);
      expect(report.members['a']!.advance, 400);
      expect(report.members['a']!.amountToSettle, 200);
      expect(report.members['a']!.difference, 200);
    },
  );
  test('donations and expenses change cash but not member balances', () {
    final report = FinancialReport.calculate([
      FinancialPoint(
        playedAt: today,
        rate: 100,
        lines: const [FinancialLine(memberId: 'a', contribution: 100)],
        donations: const [
          FinancialMovement(id: 'd', label: 'Don', amount: 500),
        ],
        expenses: const [FinancialMovement(id: 'e', label: 'Eau', amount: 200)],
      ),
    ], asOf: today);
    expect(report.cash, 400);
    expect(report.members['a']!.paid, 100);
    expect(report.members['a']!.isUpToDate, true);
  });
  test('opening date excludes prior periods and future opening balances', () {
    final report = FinancialReport.calculate(
      [
        FinancialPoint(
          playedAt: today.subtract(const Duration(days: 1)),
          rate: 100,
          lines: const [FinancialLine(memberId: 'a', contribution: 100)],
        ),
      ],
      asOf: today,
      openingDate: today.add(const Duration(days: 1)),
      openingCash: 500,
      openingMembers: const {'a': MemberBalance(contributionBalance: 200)},
    );
    expect(report.cash, 0);
    expect(report.members, isEmpty);
  });
}
