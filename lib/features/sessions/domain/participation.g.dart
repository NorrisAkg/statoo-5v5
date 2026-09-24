// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'participation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Participation _$ParticipationFromJson(Map<String, dynamic> json) =>
    _Participation(
      id: json['id'] as String,
      sessionId: json['sessionId'] as String,
      playerId: json['playerId'] as String,
      team: $enumDecode(_$TeamEnumMap, json['team']),
      goals: (json['goals'] as num?)?.toInt() ?? 0,
      assists: (json['assists'] as num?)?.toInt() ?? 0,
      yellowCards: (json['yellowCards'] as num?)?.toInt() ?? 0,
      redCards: (json['redCards'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$ParticipationToJson(_Participation instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sessionId': instance.sessionId,
      'playerId': instance.playerId,
      'team': _$TeamEnumMap[instance.team]!,
      'goals': instance.goals,
      'assists': instance.assists,
      'yellowCards': instance.yellowCards,
      'redCards': instance.redCards,
    };

const _$TeamEnumMap = {Team.a: 'a', Team.b: 'b'};
