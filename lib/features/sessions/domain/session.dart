import 'package:freezed_annotation/freezed_annotation.dart';

part 'session.freezed.dart';
part 'session.g.dart';

enum SessionStatus { draft, closed }
enum SplitMode { random, randomAdjusted, manual }
enum MatchResult { teamA, teamB, draw }

@freezed
sealed class Session with _$Session {
  const factory Session({
    required String id,
    required DateTime playedAt,
    @Default(SessionStatus.draft) SessionStatus status,
    @Default(SplitMode.random) SplitMode splitMode,
    @Default(false) bool allowUnevenTeams,
    @Default(false) bool isRanked,
    int? scoreA,
    int? scoreB,
    MatchResult? result,
    @Default(0) int unassignedGoalsA,
    @Default(0) int unassignedGoalsB,
    String? notes,
  }) = _Session;

  factory Session.fromJson(Map<String, dynamic> json) => _$SessionFromJson(json);
}
