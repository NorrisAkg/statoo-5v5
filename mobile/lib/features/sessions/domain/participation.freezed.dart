// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'participation.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Participation {

 String get id; String get sessionId; String get playerId; Team get team; int get goals; int get assists; int get yellowCards; int get redCards;
/// Create a copy of Participation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ParticipationCopyWith<Participation> get copyWith => _$ParticipationCopyWithImpl<Participation>(this as Participation, _$identity);

  /// Serializes this Participation to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Participation;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Participation&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.sessionId, _this.sessionId) || other.sessionId == _this.sessionId)&&(identical(other.playerId, _this.playerId) || other.playerId == _this.playerId)&&(identical(other.team, _this.team) || other.team == _this.team)&&(identical(other.goals, _this.goals) || other.goals == _this.goals)&&(identical(other.assists, _this.assists) || other.assists == _this.assists)&&(identical(other.yellowCards, _this.yellowCards) || other.yellowCards == _this.yellowCards)&&(identical(other.redCards, _this.redCards) || other.redCards == _this.redCards));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Participation;
  return Object.hash(runtimeType,_this.id,_this.sessionId,_this.playerId,_this.team,_this.goals,_this.assists,_this.yellowCards,_this.redCards);
}

@override
String toString() {
  final _this = this as Participation;
  return 'Participation(id: ${_this.id}, sessionId: ${_this.sessionId}, playerId: ${_this.playerId}, team: ${_this.team}, goals: ${_this.goals}, assists: ${_this.assists}, yellowCards: ${_this.yellowCards}, redCards: ${_this.redCards})';
}


}

/// @nodoc
abstract mixin class $ParticipationCopyWith<$Res>  {
  factory $ParticipationCopyWith(Participation value, $Res Function(Participation) _then) = _$ParticipationCopyWithImpl;
@useResult
$Res call({
 String id, String sessionId, String playerId, Team team, int goals, int assists, int yellowCards, int redCards
});




}
/// @nodoc
class _$ParticipationCopyWithImpl<$Res>
    implements $ParticipationCopyWith<$Res> {
  _$ParticipationCopyWithImpl(this._self, this._then);

  final Participation _self;
  final $Res Function(Participation) _then;

/// Create a copy of Participation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? sessionId = null,Object? playerId = null,Object? team = null,Object? goals = null,Object? assists = null,Object? yellowCards = null,Object? redCards = null,}) {
  return _then(Participation(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,playerId: null == playerId ? _self.playerId : playerId // ignore: cast_nullable_to_non_nullable
as String,team: null == team ? _self.team : team // ignore: cast_nullable_to_non_nullable
as Team,goals: null == goals ? _self.goals : goals // ignore: cast_nullable_to_non_nullable
as int,assists: null == assists ? _self.assists : assists // ignore: cast_nullable_to_non_nullable
as int,yellowCards: null == yellowCards ? _self.yellowCards : yellowCards // ignore: cast_nullable_to_non_nullable
as int,redCards: null == redCards ? _self.redCards : redCards // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [Participation].
extension ParticipationPatterns on Participation {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Participation value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Participation() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Participation value)  $default,){
final _that = this;
switch (_that) {
case _Participation():
return $default(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Participation value)?  $default,){
final _that = this;
switch (_that) {
case _Participation() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String sessionId,  String playerId,  Team team,  int goals,  int assists,  int yellowCards,  int redCards)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Participation() when $default != null:
return $default(_that.id,_that.sessionId,_that.playerId,_that.team,_that.goals,_that.assists,_that.yellowCards,_that.redCards);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String sessionId,  String playerId,  Team team,  int goals,  int assists,  int yellowCards,  int redCards)  $default,) {final _that = this;
switch (_that) {
case _Participation():
return $default(_that.id,_that.sessionId,_that.playerId,_that.team,_that.goals,_that.assists,_that.yellowCards,_that.redCards);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String sessionId,  String playerId,  Team team,  int goals,  int assists,  int yellowCards,  int redCards)?  $default,) {final _that = this;
switch (_that) {
case _Participation() when $default != null:
return $default(_that.id,_that.sessionId,_that.playerId,_that.team,_that.goals,_that.assists,_that.yellowCards,_that.redCards);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Participation implements Participation {
  const _Participation({required this.id, required this.sessionId, required this.playerId, required this.team, this.goals = 0, this.assists = 0, this.yellowCards = 0, this.redCards = 0});
  factory _Participation.fromJson(Map<String, dynamic> json) => _$ParticipationFromJson(json);

@override final  String id;
@override final  String sessionId;
@override final  String playerId;
@override final  Team team;
@override@JsonKey() final  int goals;
@override@JsonKey() final  int assists;
@override@JsonKey() final  int yellowCards;
@override@JsonKey() final  int redCards;

/// Create a copy of Participation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ParticipationCopyWith<_Participation> get copyWith => __$ParticipationCopyWithImpl<_Participation>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ParticipationToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Participation&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.playerId, playerId) || other.playerId == playerId)&&(identical(other.team, team) || other.team == team)&&(identical(other.goals, goals) || other.goals == goals)&&(identical(other.assists, assists) || other.assists == assists)&&(identical(other.yellowCards, yellowCards) || other.yellowCards == yellowCards)&&(identical(other.redCards, redCards) || other.redCards == redCards));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,sessionId,playerId,team,goals,assists,yellowCards,redCards);
}

@override
String toString() {
    return 'Participation(id: $id, sessionId: $sessionId, playerId: $playerId, team: $team, goals: $goals, assists: $assists, yellowCards: $yellowCards, redCards: $redCards)';
}


}

/// @nodoc
abstract mixin class _$ParticipationCopyWith<$Res> implements $ParticipationCopyWith<$Res> {
  factory _$ParticipationCopyWith(_Participation value, $Res Function(_Participation) _then) = __$ParticipationCopyWithImpl;
@override @useResult
$Res call({
 String id, String sessionId, String playerId, Team team, int goals, int assists, int yellowCards, int redCards
});




}
/// @nodoc
class __$ParticipationCopyWithImpl<$Res>
    implements _$ParticipationCopyWith<$Res> {
  __$ParticipationCopyWithImpl(this._self, this._then);

  final _Participation _self;
  final $Res Function(_Participation) _then;

/// Create a copy of Participation
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionId = null,Object? playerId = null,Object? team = null,Object? goals = null,Object? assists = null,Object? yellowCards = null,Object? redCards = null,}) {
  return _then(_Participation(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,playerId: null == playerId ? _self.playerId : playerId // ignore: cast_nullable_to_non_nullable
as String,team: null == team ? _self.team : team // ignore: cast_nullable_to_non_nullable
as Team,goals: null == goals ? _self.goals : goals // ignore: cast_nullable_to_non_nullable
as int,assists: null == assists ? _self.assists : assists // ignore: cast_nullable_to_non_nullable
as int,yellowCards: null == yellowCards ? _self.yellowCards : yellowCards // ignore: cast_nullable_to_non_nullable
as int,redCards: null == redCards ? _self.redCards : redCards // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
