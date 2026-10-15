import 'financial_point.dart';

class MemberFinancialPosition {
  const MemberFinancialPosition({
    this.contributionsPaid = 0,
    this.contributionsExpected = 0,
    this.penaltiesPaid = 0,
    this.penaltiesExpected = 0,
    this.openingContributionBalance = 0,
    this.openingPenaltyDebt = 0,
  });
  final int contributionsPaid;
  final int contributionsExpected;
  final int penaltiesPaid;
  final int penaltiesExpected;
  final int openingContributionBalance;
  final int openingPenaltyDebt;

  int get contributionBalance =>
      openingContributionBalance + contributionsPaid - contributionsExpected;
  int get contributionDebt =>
      contributionBalance < 0 ? -contributionBalance : 0;
  int get advance => contributionBalance > 0 ? contributionBalance : 0;
  int get penaltyDebt => openingPenaltyDebt + penaltiesExpected - penaltiesPaid;
  int get paid =>
      contributionsPaid +
      penaltiesPaid +
      (openingContributionBalance > 0 ? openingContributionBalance : 0);
  int get expected =>
      contributionsExpected +
      penaltiesExpected +
      openingPenaltyDebt +
      (openingContributionBalance < 0 ? -openingContributionBalance : 0);
  int get difference => paid - expected;
  int get amountToSettle =>
      contributionDebt + (penaltyDebt > 0 ? penaltyDebt : 0);
  bool get isUpToDate => contributionDebt == 0 && penaltyDebt == 0;
  bool get hasOpeningBalance =>
      openingContributionBalance != 0 || openingPenaltyDebt != 0;
}

class PendingFinancialPeriod {
  const PendingFinancialPeriod({required this.sessionId, required this.date});
  final String sessionId;
  final DateTime date;
}

class FinancialReport {
  const FinancialReport({
    required this.asOf,
    required this.cash,
    required this.members,
    this.openingDate,
    this.pendingPeriods = const [],
  });
  factory FinancialReport.calculate(
    Iterable<FinancialPoint> points, {
    required DateTime asOf,
    int openingCash = 0,
    Map<String, MemberBalance> openingMembers = const {},
    DateTime? openingDate,
    List<PendingFinancialPeriod> pendingPeriods = const [],
  }) {
    final day = DateTime(asOf.year, asOf.month, asOf.day);
    final end = DateTime(day.year, day.month, day.day + 1);
    final openingApplies = openingDate == null || openingDate.isBefore(end);
    var cash = openingApplies ? openingCash : 0;
    final members = <String, MemberFinancialPosition>{
      if (openingApplies)
        for (final entry in openingMembers.entries)
          entry.key: MemberFinancialPosition(
            openingContributionBalance: entry.value.contributionBalance,
            openingPenaltyDebt: entry.value.penaltyDebt,
          ),
    };
    for (final point in points) {
      if (!point.playedAt.isBefore(end) ||
          (openingDate != null && point.playedAt.isBefore(openingDate)))
        continue;
      cash += point.cashChange;
      for (final line in point.lines) {
        final previous =
            members[line.memberId] ?? const MemberFinancialPosition();
        members[line.memberId] = MemberFinancialPosition(
          contributionsPaid: previous.contributionsPaid + line.contribution,
          contributionsExpected: previous.contributionsExpected + point.rate,
          penaltiesPaid: previous.penaltiesPaid + line.penaltyPaid,
          penaltiesExpected: previous.penaltiesExpected + line.penaltyDue,
          openingContributionBalance: previous.openingContributionBalance,
          openingPenaltyDebt: previous.openingPenaltyDebt,
        );
      }
    }
    return FinancialReport(
      asOf: day,
      cash: cash,
      members: members,
      openingDate: openingDate,
      pendingPeriods: pendingPeriods,
    );
  }
  final DateTime asOf;
  final int cash;
  final Map<String, MemberFinancialPosition> members;
  final DateTime? openingDate;
  final List<PendingFinancialPeriod> pendingPeriods;
  bool get isComplete => pendingPeriods.isEmpty;
}
