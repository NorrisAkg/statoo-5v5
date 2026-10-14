import 'package:freezed_annotation/freezed_annotation.dart';

part 'stats_models.freezed.dart';

@freezed
abstract class PlayerStats with _$PlayerStats {
  const factory PlayerStats({
    required String playerId,
    @Default(0) int matchesPlayed,
    @Default(0) int wins,
    @Default(0) int draws,
    @Default(0) int losses,
    @Default(0) int goals,
    @Default(0) int assists,
    @Default(0) int yellowCards,
    @Default(0) int redCards,
    @Default(0) int totalPoints,
  }) = _PlayerStats;

  const PlayerStats._();

  double get pointsPerMatch => matchesPlayed == 0 ? 0 : totalPoints / matchesPlayed;
  double get winRate => matchesPlayed == 0 ? 0 : wins / matchesPlayed;
}
