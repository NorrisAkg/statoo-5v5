// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Session _$SessionFromJson(Map<String, dynamic> json) => _Session(
  id: json['id'] as String,
  playedAt: DateTime.parse(json['playedAt'] as String),
  status:
      $enumDecodeNullable(_$SessionStatusEnumMap, json['status']) ??
      SessionStatus.draft,
  splitMode:
      $enumDecodeNullable(_$SplitModeEnumMap, json['splitMode']) ??
      SplitMode.random,
  allowUnevenTeams: json['allowUnevenTeams'] as bool? ?? false,
  isRanked: json['isRanked'] as bool? ?? false,
  scoreA: (json['scoreA'] as num?)?.toInt(),
  scoreB: (json['scoreB'] as num?)?.toInt(),
  result: $enumDecodeNullable(_$MatchResultEnumMap, json['result']),
  unassignedGoalsA: (json['unassignedGoalsA'] as num?)?.toInt() ?? 0,
  unassignedGoalsB: (json['unassignedGoalsB'] as num?)?.toInt() ?? 0,
  notes: json['notes'] as String?,
);

Map<String, dynamic> _$SessionToJson(_Session instance) => <String, dynamic>{
  'id': instance.id,
  'playedAt': instance.playedAt.toIso8601String(),
  'status': _$SessionStatusEnumMap[instance.status]!,
  'splitMode': _$SplitModeEnumMap[instance.splitMode]!,
  'allowUnevenTeams': instance.allowUnevenTeams,
  'isRanked': instance.isRanked,
  'scoreA': instance.scoreA,
  'scoreB': instance.scoreB,
  'result': _$MatchResultEnumMap[instance.result],
  'unassignedGoalsA': instance.unassignedGoalsA,
  'unassignedGoalsB': instance.unassignedGoalsB,
  'notes': instance.notes,
};

const _$SessionStatusEnumMap = {
  SessionStatus.draft: 'draft',
  SessionStatus.closed: 'closed',
};

const _$SplitModeEnumMap = {
  SplitMode.random: 'random',
  SplitMode.randomAdjusted: 'randomAdjusted',
  SplitMode.manual: 'manual',
};

const _$MatchResultEnumMap = {
  MatchResult.teamA: 'teamA',
  MatchResult.teamB: 'teamB',
  MatchResult.draw: 'draw',
};
