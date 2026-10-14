// Tous les champs sont final : l'égalité par valeur est sûre.
// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

import 'dart:convert';

/// Pondérations du score « Joueur du mois ». Les malus sont des valeurs
/// positives, soustraites au score.
class MvpWeights {
  const MvpWeights({
    this.win = 10,
    this.draw = 3,
    this.loss = 0,
    this.goal = 2,
    this.assist = 1,
    this.yellowCard = 0.5,
    this.redCard = 1,
  });

  factory MvpWeights.fromJson(Map<String, dynamic> json) {
    double read(String key, double fallback) {
      final value = json[key];
      if (value is num && value.isFinite) return value.toDouble();
      return fallback;
    }

    const d = MvpWeights.defaults;
    return MvpWeights(
      win: read('win', d.win),
      draw: read('draw', d.draw),
      loss: read('loss', d.loss),
      goal: read('goal', d.goal),
      assist: read('assist', d.assist),
      yellowCard: read('yellowCard', d.yellowCard),
      redCard: read('redCard', d.redCard),
    );
  }

  /// Décode une valeur stockée ; toute valeur illisible donne les défauts.
  factory MvpWeights.decode(String? raw) {
    if (raw == null || raw.isEmpty) return defaults;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return MvpWeights.fromJson(decoded);
    } on FormatException {
      // Valeur corrompue : retour aux pondérations par défaut.
    }
    return defaults;
  }

  static const MvpWeights defaults = MvpWeights();

  final double win;
  final double draw;
  final double loss;
  final double goal;
  final double assist;
  final double yellowCard;
  final double redCard;

  bool get isDefault => this == defaults;

  Map<String, dynamic> toJson() => {
        'win': win,
        'draw': draw,
        'loss': loss,
        'goal': goal,
        'assist': assist,
        'yellowCard': yellowCard,
        'redCard': redCard,
      };

  String encode() => jsonEncode(toJson());

  MvpWeights copyWith({
    double? win,
    double? draw,
    double? loss,
    double? goal,
    double? assist,
    double? yellowCard,
    double? redCard,
  }) {
    return MvpWeights(
      win: win ?? this.win,
      draw: draw ?? this.draw,
      loss: loss ?? this.loss,
      goal: goal ?? this.goal,
      assist: assist ?? this.assist,
      yellowCard: yellowCard ?? this.yellowCard,
      redCard: redCard ?? this.redCard,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MvpWeights &&
      other.win == win &&
      other.draw == draw &&
      other.loss == loss &&
      other.goal == goal &&
      other.assist == assist &&
      other.yellowCard == yellowCard &&
      other.redCard == redCard;

  @override
  int get hashCode => Object.hash(win, draw, loss, goal, assist, yellowCard, redCard);
}
