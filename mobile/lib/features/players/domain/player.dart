import 'package:freezed_annotation/freezed_annotation.dart';

part 'player.freezed.dart';
part 'player.g.dart';

@freezed
sealed class Player with _$Player {
  const factory Player({
    required String id,
    required String teamId,
    required String name,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? nickname,
    String? avatarUrl,
    @Default(true) bool isActive,
  }) = _Player;

  factory Player.fromJson(Map<String, dynamic> json) => _$PlayerFromJson(json);
}
