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
  sessionType:
      $enumDecodeNullable(_$SessionTypeEnumMap, json['sessionType']) ??
      SessionType.classic2,
  allowUnevenTeams: json['allowUnevenTeams'] as bool? ?? false,
  isRanked: json['isRanked'] as bool? ?? false,
  scoreA: (json['scoreA'] as num?)?.toInt(),
  scoreB: (json['scoreB'] as num?)?.toInt(),
  scoreC: (json['scoreC'] as num?)?.toInt(),
  winsA: (json['winsA'] as num?)?.toInt() ?? 0,
  winsB: (json['winsB'] as num?)?.toInt() ?? 0,
  winsC: (json['winsC'] as num?)?.toInt() ?? 0,
  drawPoints: (json['drawPoints'] as num?)?.toInt() ?? 1,
  result: $enumDecodeNullable(_$MatchResultEnumMap, json['result']),
  unassignedGoalsA: (json['unassignedGoalsA'] as num?)?.toInt() ?? 0,
  unassignedGoalsB: (json['unassignedGoalsB'] as num?)?.toInt() ?? 0,
  unassignedGoalsC: (json['unassignedGoalsC'] as num?)?.toInt() ?? 0,
  notes: json['notes'] as String?,
  teamNames:
      (json['teamNames'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ) ??
      const <String, String>{},
  teamColors:
      (json['teamColors'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, (e as num).toInt()),
      ) ??
      const <String, int>{},
);

Map<String, dynamic> _$SessionToJson(_Session instance) => <String, dynamic>{
  'id': instance.id,
  'playedAt': instance.playedAt.toIso8601String(),
  'status': _$SessionStatusEnumMap[instance.status]!,
  'splitMode': _$SplitModeEnumMap[instance.splitMode]!,
  'sessionType': _$SessionTypeEnumMap[instance.sessionType]!,
  'allowUnevenTeams': instance.allowUnevenTeams,
  'isRanked': instance.isRanked,
  'scoreA': instance.scoreA,
  'scoreB': instance.scoreB,
  'scoreC': instance.scoreC,
  'winsA': instance.winsA,
  'winsB': instance.winsB,
  'winsC': instance.winsC,
  'drawPoints': instance.drawPoints,
  'result': _$MatchResultEnumMap[instance.result],
  'unassignedGoalsA': instance.unassignedGoalsA,
  'unassignedGoalsB': instance.unassignedGoalsB,
  'unassignedGoalsC': instance.unassignedGoalsC,
  'notes': instance.notes,
  'teamNames': instance.teamNames,
  'teamColors': instance.teamColors,
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

const _$SessionTypeEnumMap = {
  SessionType.classic2: 'classic2',
  SessionType.tournament3: 'tournament3',
};

const _$MatchResultEnumMap = {
  MatchResult.teamA: 'teamA',
  MatchResult.teamB: 'teamB',
  MatchResult.teamC: 'teamC',
  MatchResult.draw: 'draw',
  MatchResult.drawAB: 'drawAB',
  MatchResult.drawBC: 'drawBC',
  MatchResult.drawAC: 'drawAC',
  MatchResult.drawAll: 'drawAll',
};
