class FinancialLine {
  const FinancialLine({
    required this.memberId,
    this.contribution = 0,
    this.penaltyPaid = 0,
    this.penaltyDue = 0,
    this.reason = '',
  });
  factory FinancialLine.fromJson(Map<String, dynamic> json) => FinancialLine(
    memberId: json['member_id'] as String,
    contribution: json['contribution'] as int? ?? 0,
    penaltyPaid: json['penalty_paid'] as int? ?? 0,
    penaltyDue: json['penalty_due'] as int? ?? 0,
    reason: json['reason'] as String? ?? '',
  );
  final String memberId;
  final int contribution;
  final int penaltyPaid;
  final int penaltyDue;
  final String reason;
  Map<String, dynamic> toJson() => {
    'member_id': memberId,
    'contribution': contribution,
    'penalty_paid': penaltyPaid,
    'penalty_due': penaltyDue,
    'reason': reason,
  };
}

class FinancialMovement {
  const FinancialMovement({
    required this.id,
    required this.label,
    required this.amount,
  });
  factory FinancialMovement.fromJson(Map<String, dynamic> json) =>
      FinancialMovement(
        id: json['id'] as String,
        label: json['label'] as String,
        amount: json['amount'] as int,
      );
  final String id;
  final String label;
  final int amount;
  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'amount': amount};
}

class FinancialPoint {
  const FinancialPoint({
    required this.playedAt,
    required this.rate,
    required this.lines,
    this.cancelled = false,
    this.expenses = const [],
    this.donations = const [],
  });
  factory FinancialPoint.fromJson(Map<String, dynamic> json) => FinancialPoint(
    playedAt: DateTime.parse(json['played_at'] as String),
    rate: json['rate'] as int,
    cancelled: json['cancelled'] as bool? ?? false,
    lines: (json['lines'] as List<dynamic>)
        .map((v) => FinancialLine.fromJson(Map<String, dynamic>.from(v as Map)))
        .toList(),
    expenses: (json['expenses'] as List<dynamic>? ?? [])
        .map(
          (v) =>
              FinancialMovement.fromJson(Map<String, dynamic>.from(v as Map)),
        )
        .toList(),
    donations: (json['donations'] as List<dynamic>? ?? [])
        .map(
          (v) =>
              FinancialMovement.fromJson(Map<String, dynamic>.from(v as Map)),
        )
        .toList(),
  );
  final DateTime playedAt;
  final int rate;
  final bool cancelled;
  final List<FinancialLine> lines;
  final List<FinancialMovement> expenses;
  final List<FinancialMovement> donations;
  int get contributions =>
      lines.fold(0, (sum, line) => sum + line.contribution);
  int get penaltiesReceived =>
      lines.fold(0, (sum, line) => sum + line.penaltyPaid);
  int get donationsReceived => donations.fold(0, (sum, v) => sum + v.amount);
  int get received => contributions + penaltiesReceived + donationsReceived;
  int get spent => expenses.fold(0, (sum, v) => sum + v.amount);
  int get cashChange => received - spent;
  void validate() {
    if (rate < 0 ||
        lines.map((l) => l.memberId).toSet().length != lines.length) {
      throw const FormatException('Cotisation ou liste des membres invalide.');
    }
    for (final line in lines) {
      if (line.contribution < 0 ||
          line.penaltyDue < 0 ||
          line.penaltyPaid < 0) {
        throw const FormatException(
          'Les montants doivent être positifs ou nuls.',
        );
      }
    }
    final movements = [...expenses, ...donations];
    if (movements.map((m) => m.id).toSet().length != movements.length ||
        movements.any((m) => m.amount < 0 || m.label.trim().isEmpty)) {
      throw const FormatException('Mouvement invalide.');
    }
    if (cancelled &&
        (received != 0 ||
            expenses.isNotEmpty ||
            donations.isNotEmpty ||
            lines.any((l) => l.penaltyDue != 0))) {
      throw const FormatException(
        'Une séance annulée conserve les cotisations dues, sans mouvement ni pénalité.',
      );
    }
  }

  Map<String, dynamic> toJson() => {
    'played_at': playedAt.toIso8601String(),
    'rate': rate,
    'cancelled': cancelled,
    'lines': lines.map((l) => l.toJson()).toList(),
    'expenses': expenses.map((m) => m.toJson()).toList(),
    'donations': donations.map((m) => m.toJson()).toList(),
  };
}

class MemberBalance {
  const MemberBalance({this.contributionBalance = 0, this.penaltyDebt = 0});
  final int contributionBalance;
  final int penaltyDebt;
  int get advance => contributionBalance > 0 ? contributionBalance : 0;
  int get contributionDebt =>
      contributionBalance < 0 ? -contributionBalance : 0;
}

class FinancialTotals {
  FinancialTotals({required this.cash, required this.members});
  factory FinancialTotals.calculate(
    Iterable<FinancialPoint> points, {
    int openingCash = 0,
    Map<String, MemberBalance> openingMembers = const {},
    DateTime? openingDate,
  }) {
    var cash = openingCash;
    final members = Map<String, MemberBalance>.from(openingMembers);
    for (final point in points) {
      if (openingDate != null && point.playedAt.isBefore(openingDate)) continue;
      cash += point.cashChange;
      for (final line in point.lines) {
        final previous = members[line.memberId] ?? const MemberBalance();
        members[line.memberId] = MemberBalance(
          contributionBalance:
              previous.contributionBalance + line.contribution - point.rate,
          penaltyDebt:
              previous.penaltyDebt + line.penaltyDue - line.penaltyPaid,
        );
      }
    }
    return FinancialTotals(cash: cash, members: members);
  }
  final int cash;
  final Map<String, MemberBalance> members;
}
