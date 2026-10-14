import 'package:freezed_annotation/freezed_annotation.dart';

part 'participation.freezed.dart';
part 'participation.g.dart';

enum Team { a, b, c }

@freezed
sealed class Participation with _$Participation {
  const factory Participation({
    required String id,
    required String sessionId,
    required String playerId,
    required Team team,
    @Default(0) int goals,
    @Default(0) int assists,
    @Default(0) int yellowCards,
    @Default(0) int redCards,
  }) = _Participation;

  factory Participation.fromJson(Map<String, dynamic> json) => _$ParticipationFromJson(json);
}
