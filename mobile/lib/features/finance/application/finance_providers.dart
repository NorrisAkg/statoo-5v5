import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/app_database.dart';
import '../../shared/application/shared_providers.dart';
import '../../team/application/team_provider.dart';
import '../data/finance_repository.dart';
import '../domain/financial_defaults.dart';
import '../domain/financial_point.dart';
import '../domain/financial_report.dart';

final financialDefaultsProvider = FutureProvider<FinancialDefaults>((
  ref,
) async {
  ref.watch(sharedStatusProvider);
  final group = ref.watch(activeTeamIdProvider);
  if (group == null) return const FinancialDefaults();
  return await ref.watch(financeRepositoryProvider).getDefaults(group);
});

final financeRepositoryProvider = Provider<FinanceRepository>(
  (ref) =>
      FinanceRepository(AppDatabase.instance, ref.watch(sharedServiceProvider)),
);

final financialPointsProvider = FutureProvider<List<FinancialPoint>>((
  ref,
) async {
  final group = ref.watch(activeTeamIdProvider);
  if (group == null) return [];
  return await ref.watch(financeRepositoryProvider).allPoints(group);
});

final financialTotalsProvider = FutureProvider<FinancialTotals>((ref) async {
  final points = await ref.watch(financialPointsProvider.future);
  final shared = ref.watch(sharedServiceProvider);
  final opening = ref.watch(activeTeamIdProvider) == shared.groupId
      ? (shared.snapshot?['opening'] as Map?)
      : null;
  return FinancialTotals.calculate(
    points,
    openingCash: opening?['cash'] as int? ?? 0,
    openingDate: DateTime.tryParse(opening?['start_date'] as String? ?? ''),
    openingMembers: {
      for (final entry in (opening?['members'] as Map? ?? {}).entries)
        entry.key as String: MemberBalance(
          contributionBalance:
              (entry.value as Map)['contribution_balance'] as int,
          penaltyDebt: (entry.value as Map)['penalty_debt'] as int,
        ),
    },
  );
});

final financialReportProvider = FutureProvider<FinancialReport>((ref) async {
  ref.watch(sharedStatusProvider);
  final group = ref.watch(activeTeamIdProvider);
  final shared = ref.watch(sharedServiceProvider);
  final opening = group != null && group == shared.groupId
      ? (shared.snapshot?['opening'] as Map?)
      : null;
  final asOf = DateTime.now();
  final start = DateTime.tryParse(opening?['start_date'] as String? ?? '');
  final points = await ref.watch(financialPointsProvider.future);
  final pending = group == null
      ? <PendingFinancialPeriod>[]
      : await ref
            .watch(financeRepositoryProvider)
            .pendingPeriods(group, asOf: asOf, since: start);
  return FinancialReport.calculate(
    points,
    asOf: asOf,
    openingCash: opening?['cash'] as int? ?? 0,
    openingDate: start,
    openingMembers: {
      for (final entry in (opening?['members'] as Map? ?? {}).entries)
        entry.key as String: MemberBalance(
          contributionBalance:
              (entry.value as Map)['contribution_balance'] as int,
          penaltyDebt: (entry.value as Map)['penalty_debt'] as int,
        ),
    },
    pendingPeriods: pending,
  );
});
