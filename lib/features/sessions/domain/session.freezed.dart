// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Session {

 String get id; DateTime get playedAt; SessionStatus get status; SplitMode get splitMode; bool get allowUnevenTeams; bool get isRanked; int? get scoreA; int? get scoreB; MatchResult? get result; int get unassignedGoalsA; int get unassignedGoalsB; String? get notes;
/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionCopyWith<Session> get copyWith => _$SessionCopyWithImpl<Session>(this as Session, _$identity);

  /// Serializes this Session to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Session;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Session&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.playedAt, _this.playedAt) || other.playedAt == _this.playedAt)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.splitMode, _this.splitMode) || other.splitMode == _this.splitMode)&&(identical(other.allowUnevenTeams, _this.allowUnevenTeams) || other.allowUnevenTeams == _this.allowUnevenTeams)&&(identical(other.isRanked, _this.isRanked) || other.isRanked == _this.isRanked)&&(identical(other.scoreA, _this.scoreA) || other.scoreA == _this.scoreA)&&(identical(other.scoreB, _this.scoreB) || other.scoreB == _this.scoreB)&&(identical(other.result, _this.result) || other.result == _this.result)&&(identical(other.unassignedGoalsA, _this.unassignedGoalsA) || other.unassignedGoalsA == _this.unassignedGoalsA)&&(identical(other.unassignedGoalsB, _this.unassignedGoalsB) || other.unassignedGoalsB == _this.unassignedGoalsB)&&(identical(other.notes, _this.notes) || other.notes == _this.notes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Session;
  return Object.hash(runtimeType,_this.id,_this.playedAt,_this.status,_this.splitMode,_this.allowUnevenTeams,_this.isRanked,_this.scoreA,_this.scoreB,_this.result,_this.unassignedGoalsA,_this.unassignedGoalsB,_this.notes);
}

@override
String toString() {
  final _this = this as Session;
  return 'Session(id: ${_this.id}, playedAt: ${_this.playedAt}, status: ${_this.status}, splitMode: ${_this.splitMode}, allowUnevenTeams: ${_this.allowUnevenTeams}, isRanked: ${_this.isRanked}, scoreA: ${_this.scoreA}, scoreB: ${_this.scoreB}, result: ${_this.result}, unassignedGoalsA: ${_this.unassignedGoalsA}, unassignedGoalsB: ${_this.unassignedGoalsB}, notes: ${_this.notes})';
}


}

/// @nodoc
abstract mixin class $SessionCopyWith<$Res>  {
  factory $SessionCopyWith(Session value, $Res Function(Session) _then) = _$SessionCopyWithImpl;
@useResult
$Res call({
 String id, DateTime playedAt, SessionStatus status, SplitMode splitMode, bool allowUnevenTeams, bool isRanked, int? scoreA, int? scoreB, MatchResult? result, int unassignedGoalsA, int unassignedGoalsB, String? notes
});




}
/// @nodoc
class _$SessionCopyWithImpl<$Res>
    implements $SessionCopyWith<$Res> {
  _$SessionCopyWithImpl(this._self, this._then);

  final Session _self;
  final $Res Function(Session) _then;

/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? playedAt = null,Object? status = null,Object? splitMode = null,Object? allowUnevenTeams = null,Object? isRanked = null,Object? scoreA = freezed,Object? scoreB = freezed,Object? result = freezed,Object? unassignedGoalsA = null,Object? unassignedGoalsB = null,Object? notes = freezed,}) {
  return _then(Session(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,playedAt: null == playedAt ? _self.playedAt : playedAt // ignore: cast_nullable_to_non_nullable
as DateTime,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SessionStatus,splitMode: null == splitMode ? _self.splitMode : splitMode // ignore: cast_nullable_to_non_nullable
as SplitMode,allowUnevenTeams: null == allowUnevenTeams ? _self.allowUnevenTeams : allowUnevenTeams // ignore: cast_nullable_to_non_nullable
as bool,isRanked: null == isRanked ? _self.isRanked : isRanked // ignore: cast_nullable_to_non_nullable
as bool,scoreA: freezed == scoreA ? _self.scoreA : scoreA // ignore: cast_nullable_to_non_nullable
as int?,scoreB: freezed == scoreB ? _self.scoreB : scoreB // ignore: cast_nullable_to_non_nullable
as int?,result: freezed == result ? _self.result : result // ignore: cast_nullable_to_non_nullable
as MatchResult?,unassignedGoalsA: null == unassignedGoalsA ? _self.unassignedGoalsA : unassignedGoalsA // ignore: cast_nullable_to_non_nullable
as int,unassignedGoalsB: null == unassignedGoalsB ? _self.unassignedGoalsB : unassignedGoalsB // ignore: cast_nullable_to_non_nullable
as int,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Session].
extension SessionPatterns on Session {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Session value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Session() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Session value)  $default,){
final _that = this;
switch (_that) {
case _Session():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Session value)?  $default,){
final _that = this;
switch (_that) {
case _Session() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  DateTime playedAt,  SessionStatus status,  SplitMode splitMode,  bool allowUnevenTeams,  bool isRanked,  int? scoreA,  int? scoreB,  MatchResult? result,  int unassignedGoalsA,  int unassignedGoalsB,  String? notes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Session() when $default != null:
return $default(_that.id,_that.playedAt,_that.status,_that.splitMode,_that.allowUnevenTeams,_that.isRanked,_that.scoreA,_that.scoreB,_that.result,_that.unassignedGoalsA,_that.unassignedGoalsB,_that.notes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  DateTime playedAt,  SessionStatus status,  SplitMode splitMode,  bool allowUnevenTeams,  bool isRanked,  int? scoreA,  int? scoreB,  MatchResult? result,  int unassignedGoalsA,  int unassignedGoalsB,  String? notes)  $default,) {final _that = this;
switch (_that) {
case _Session():
return $default(_that.id,_that.playedAt,_that.status,_that.splitMode,_that.allowUnevenTeams,_that.isRanked,_that.scoreA,_that.scoreB,_that.result,_that.unassignedGoalsA,_that.unassignedGoalsB,_that.notes);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  DateTime playedAt,  SessionStatus status,  SplitMode splitMode,  bool allowUnevenTeams,  bool isRanked,  int? scoreA,  int? scoreB,  MatchResult? result,  int unassignedGoalsA,  int unassignedGoalsB,  String? notes)?  $default,) {final _that = this;
switch (_that) {
case _Session() when $default != null:
return $default(_that.id,_that.playedAt,_that.status,_that.splitMode,_that.allowUnevenTeams,_that.isRanked,_that.scoreA,_that.scoreB,_that.result,_that.unassignedGoalsA,_that.unassignedGoalsB,_that.notes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Session implements Session {
  const _Session({required this.id, required this.playedAt, this.status = SessionStatus.draft, this.splitMode = SplitMode.random, this.allowUnevenTeams = false, this.isRanked = false, this.scoreA, this.scoreB, this.result, this.unassignedGoalsA = 0, this.unassignedGoalsB = 0, this.notes});
  factory _Session.fromJson(Map<String, dynamic> json) => _$SessionFromJson(json);

@override final  String id;
@override final  DateTime playedAt;
@override@JsonKey() final  SessionStatus status;
@override@JsonKey() final  SplitMode splitMode;
@override@JsonKey() final  bool allowUnevenTeams;
@override@JsonKey() final  bool isRanked;
@override final  int? scoreA;
@override final  int? scoreB;
@override final  MatchResult? result;
@override@JsonKey() final  int unassignedGoalsA;
@override@JsonKey() final  int unassignedGoalsB;
@override final  String? notes;

/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionCopyWith<_Session> get copyWith => __$SessionCopyWithImpl<_Session>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Session&&(identical(other.id, id) || other.id == id)&&(identical(other.playedAt, playedAt) || other.playedAt == playedAt)&&(identical(other.status, status) || other.status == status)&&(identical(other.splitMode, splitMode) || other.splitMode == splitMode)&&(identical(other.allowUnevenTeams, allowUnevenTeams) || other.allowUnevenTeams == allowUnevenTeams)&&(identical(other.isRanked, isRanked) || other.isRanked == isRanked)&&(identical(other.scoreA, scoreA) || other.scoreA == scoreA)&&(identical(other.scoreB, scoreB) || other.scoreB == scoreB)&&(identical(other.result, result) || other.result == result)&&(identical(other.unassignedGoalsA, unassignedGoalsA) || other.unassignedGoalsA == unassignedGoalsA)&&(identical(other.unassignedGoalsB, unassignedGoalsB) || other.unassignedGoalsB == unassignedGoalsB)&&(identical(other.notes, notes) || other.notes == notes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,playedAt,status,splitMode,allowUnevenTeams,isRanked,scoreA,scoreB,result,unassignedGoalsA,unassignedGoalsB,notes);
}

@override
String toString() {
    return 'Session(id: $id, playedAt: $playedAt, status: $status, splitMode: $splitMode, allowUnevenTeams: $allowUnevenTeams, isRanked: $isRanked, scoreA: $scoreA, scoreB: $scoreB, result: $result, unassignedGoalsA: $unassignedGoalsA, unassignedGoalsB: $unassignedGoalsB, notes: $notes)';
}


}

/// @nodoc
abstract mixin class _$SessionCopyWith<$Res> implements $SessionCopyWith<$Res> {
  factory _$SessionCopyWith(_Session value, $Res Function(_Session) _then) = __$SessionCopyWithImpl;
@override @useResult
$Res call({
 String id, DateTime playedAt, SessionStatus status, SplitMode splitMode, bool allowUnevenTeams, bool isRanked, int? scoreA, int? scoreB, MatchResult? result, int unassignedGoalsA, int unassignedGoalsB, String? notes
});




}
/// @nodoc
class __$SessionCopyWithImpl<$Res>
    implements _$SessionCopyWith<$Res> {
  __$SessionCopyWithImpl(this._self, this._then);

  final _Session _self;
  final $Res Function(_Session) _then;

/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? playedAt = null,Object? status = null,Object? splitMode = null,Object? allowUnevenTeams = null,Object? isRanked = null,Object? scoreA = freezed,Object? scoreB = freezed,Object? result = freezed,Object? unassignedGoalsA = null,Object? unassignedGoalsB = null,Object? notes = freezed,}) {
  return _then(_Session(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,playedAt: null == playedAt ? _self.playedAt : playedAt // ignore: cast_nullable_to_non_nullable
as DateTime,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SessionStatus,splitMode: null == splitMode ? _self.splitMode : splitMode // ignore: cast_nullable_to_non_nullable
as SplitMode,allowUnevenTeams: null == allowUnevenTeams ? _self.allowUnevenTeams : allowUnevenTeams // ignore: cast_nullable_to_non_nullable
as bool,isRanked: null == isRanked ? _self.isRanked : isRanked // ignore: cast_nullable_to_non_nullable
as bool,scoreA: freezed == scoreA ? _self.scoreA : scoreA // ignore: cast_nullable_to_non_nullable
as int?,scoreB: freezed == scoreB ? _self.scoreB : scoreB // ignore: cast_nullable_to_non_nullable
as int?,result: freezed == result ? _self.result : result // ignore: cast_nullable_to_non_nullable
as MatchResult?,unassignedGoalsA: null == unassignedGoalsA ? _self.unassignedGoalsA : unassignedGoalsA // ignore: cast_nullable_to_non_nullable
as int,unassignedGoalsB: null == unassignedGoalsB ? _self.unassignedGoalsB : unassignedGoalsB // ignore: cast_nullable_to_non_nullable
as int,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
