import 'package:freezed_annotation/freezed_annotation.dart';

part 'session.freezed.dart';
part 'session.g.dart';

enum SessionStatus { draft, closed }
enum SplitMode { random, randomAdjusted, manual }
enum SessionType { classic2, tournament3 }
enum MatchResult { teamA, teamB, teamC, draw, drawAB, drawBC, drawAC, drawAll }

@freezed
sealed class Session with _$Session {
  const factory Session({
    required String id,
    required DateTime playedAt,
    @Default(SessionStatus.draft) SessionStatus status,
    @Default(SplitMode.random) SplitMode splitMode,
    @Default(SessionType.classic2) SessionType sessionType,
    @Default(false) bool allowUnevenTeams,
    @Default(false) bool isRanked,
    int? scoreA,
    int? scoreB,
    int? scoreC,
    @Default(0) int winsA,
    @Default(0) int winsB,
    @Default(0) int winsC,
    @Default(1) int drawPoints,
    MatchResult? result,
    @Default(0) int unassignedGoalsA,
    @Default(0) int unassignedGoalsB,
    @Default(0) int unassignedGoalsC,
    String? notes,
  }) = _Session;

  factory Session.fromJson(Map<String, dynamic> json) => _$SessionFromJson(json);
}
