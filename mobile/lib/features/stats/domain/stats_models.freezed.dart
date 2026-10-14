// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'stats_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PlayerStats {

 String get playerId; int get matchesPlayed; int get wins; int get draws; int get losses; int get goals; int get assists; int get yellowCards; int get redCards; int get totalPoints;
/// Create a copy of PlayerStats
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlayerStatsCopyWith<PlayerStats> get copyWith => _$PlayerStatsCopyWithImpl<PlayerStats>(this as PlayerStats, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PlayerStats;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlayerStats&&(identical(other.playerId, _this.playerId) || other.playerId == _this.playerId)&&(identical(other.matchesPlayed, _this.matchesPlayed) || other.matchesPlayed == _this.matchesPlayed)&&(identical(other.wins, _this.wins) || other.wins == _this.wins)&&(identical(other.draws, _this.draws) || other.draws == _this.draws)&&(identical(other.losses, _this.losses) || other.losses == _this.losses)&&(identical(other.goals, _this.goals) || other.goals == _this.goals)&&(identical(other.assists, _this.assists) || other.assists == _this.assists)&&(identical(other.yellowCards, _this.yellowCards) || other.yellowCards == _this.yellowCards)&&(identical(other.redCards, _this.redCards) || other.redCards == _this.redCards)&&(identical(other.totalPoints, _this.totalPoints) || other.totalPoints == _this.totalPoints));
}


@override
int get hashCode {
  final _this = this as PlayerStats;
  return Object.hash(runtimeType,_this.playerId,_this.matchesPlayed,_this.wins,_this.draws,_this.losses,_this.goals,_this.assists,_this.yellowCards,_this.redCards,_this.totalPoints);
}

@override
String toString() {
  final _this = this as PlayerStats;
  return 'PlayerStats(playerId: ${_this.playerId}, matchesPlayed: ${_this.matchesPlayed}, wins: ${_this.wins}, draws: ${_this.draws}, losses: ${_this.losses}, goals: ${_this.goals}, assists: ${_this.assists}, yellowCards: ${_this.yellowCards}, redCards: ${_this.redCards}, totalPoints: ${_this.totalPoints})';
}


}

/// @nodoc
abstract mixin class $PlayerStatsCopyWith<$Res>  {
  factory $PlayerStatsCopyWith(PlayerStats value, $Res Function(PlayerStats) _then) = _$PlayerStatsCopyWithImpl;
@useResult
$Res call({
 String playerId, int matchesPlayed, int wins, int draws, int losses, int goals, int assists, int yellowCards, int redCards, int totalPoints
});




}
/// @nodoc
class _$PlayerStatsCopyWithImpl<$Res>
    implements $PlayerStatsCopyWith<$Res> {
  _$PlayerStatsCopyWithImpl(this._self, this._then);

  final PlayerStats _self;
  final $Res Function(PlayerStats) _then;

/// Create a copy of PlayerStats
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? playerId = null,Object? matchesPlayed = null,Object? wins = null,Object? draws = null,Object? losses = null,Object? goals = null,Object? assists = null,Object? yellowCards = null,Object? redCards = null,Object? totalPoints = null,}) {
  return _then(PlayerStats(
playerId: null == playerId ? _self.playerId : playerId // ignore: cast_nullable_to_non_nullable
as String,matchesPlayed: null == matchesPlayed ? _self.matchesPlayed : matchesPlayed // ignore: cast_nullable_to_non_nullable
as int,wins: null == wins ? _self.wins : wins // ignore: cast_nullable_to_non_nullable
as int,draws: null == draws ? _self.draws : draws // ignore: cast_nullable_to_non_nullable
as int,losses: null == losses ? _self.losses : losses // ignore: cast_nullable_to_non_nullable
as int,goals: null == goals ? _self.goals : goals // ignore: cast_nullable_to_non_nullable
as int,assists: null == assists ? _self.assists : assists // ignore: cast_nullable_to_non_nullable
as int,yellowCards: null == yellowCards ? _self.yellowCards : yellowCards // ignore: cast_nullable_to_non_nullable
as int,redCards: null == redCards ? _self.redCards : redCards // ignore: cast_nullable_to_non_nullable
as int,totalPoints: null == totalPoints ? _self.totalPoints : totalPoints // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [PlayerStats].
extension PlayerStatsPatterns on PlayerStats {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlayerStats value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlayerStats() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlayerStats value)  $default,){
final _that = this;
switch (_that) {
case _PlayerStats():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlayerStats value)?  $default,){
final _that = this;
switch (_that) {
case _PlayerStats() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String playerId,  int matchesPlayed,  int wins,  int draws,  int losses,  int goals,  int assists,  int yellowCards,  int redCards,  int totalPoints)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlayerStats() when $default != null:
return $default(_that.playerId,_that.matchesPlayed,_that.wins,_that.draws,_that.losses,_that.goals,_that.assists,_that.yellowCards,_that.redCards,_that.totalPoints);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String playerId,  int matchesPlayed,  int wins,  int draws,  int losses,  int goals,  int assists,  int yellowCards,  int redCards,  int totalPoints)  $default,) {final _that = this;
switch (_that) {
case _PlayerStats():
return $default(_that.playerId,_that.matchesPlayed,_that.wins,_that.draws,_that.losses,_that.goals,_that.assists,_that.yellowCards,_that.redCards,_that.totalPoints);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String playerId,  int matchesPlayed,  int wins,  int draws,  int losses,  int goals,  int assists,  int yellowCards,  int redCards,  int totalPoints)?  $default,) {final _that = this;
switch (_that) {
case _PlayerStats() when $default != null:
return $default(_that.playerId,_that.matchesPlayed,_that.wins,_that.draws,_that.losses,_that.goals,_that.assists,_that.yellowCards,_that.redCards,_that.totalPoints);case _:
  return null;

}
}

}

/// @nodoc


class _PlayerStats extends PlayerStats {
  const _PlayerStats({required this.playerId, this.matchesPlayed = 0, this.wins = 0, this.draws = 0, this.losses = 0, this.goals = 0, this.assists = 0, this.yellowCards = 0, this.redCards = 0, this.totalPoints = 0}): super._();
  

@override final  String playerId;
@override@JsonKey() final  int matchesPlayed;
@override@JsonKey() final  int wins;
@override@JsonKey() final  int draws;
@override@JsonKey() final  int losses;
@override@JsonKey() final  int goals;
@override@JsonKey() final  int assists;
@override@JsonKey() final  int yellowCards;
@override@JsonKey() final  int redCards;
@override@JsonKey() final  int totalPoints;

/// Create a copy of PlayerStats
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlayerStatsCopyWith<_PlayerStats> get copyWith => __$PlayerStatsCopyWithImpl<_PlayerStats>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlayerStats&&(identical(other.playerId, playerId) || other.playerId == playerId)&&(identical(other.matchesPlayed, matchesPlayed) || other.matchesPlayed == matchesPlayed)&&(identical(other.wins, wins) || other.wins == wins)&&(identical(other.draws, draws) || other.draws == draws)&&(identical(other.losses, losses) || other.losses == losses)&&(identical(other.goals, goals) || other.goals == goals)&&(identical(other.assists, assists) || other.assists == assists)&&(identical(other.yellowCards, yellowCards) || other.yellowCards == yellowCards)&&(identical(other.redCards, redCards) || other.redCards == redCards)&&(identical(other.totalPoints, totalPoints) || other.totalPoints == totalPoints));
}


@override
int get hashCode {
    return Object.hash(runtimeType,playerId,matchesPlayed,wins,draws,losses,goals,assists,yellowCards,redCards,totalPoints);
}

@override
String toString() {
    return 'PlayerStats(playerId: $playerId, matchesPlayed: $matchesPlayed, wins: $wins, draws: $draws, losses: $losses, goals: $goals, assists: $assists, yellowCards: $yellowCards, redCards: $redCards, totalPoints: $totalPoints)';
}


}

/// @nodoc
abstract mixin class _$PlayerStatsCopyWith<$Res> implements $PlayerStatsCopyWith<$Res> {
  factory _$PlayerStatsCopyWith(_PlayerStats value, $Res Function(_PlayerStats) _then) = __$PlayerStatsCopyWithImpl;
@override @useResult
$Res call({
 String playerId, int matchesPlayed, int wins, int draws, int losses, int goals, int assists, int yellowCards, int redCards, int totalPoints
});




}
/// @nodoc
class __$PlayerStatsCopyWithImpl<$Res>
    implements _$PlayerStatsCopyWith<$Res> {
  __$PlayerStatsCopyWithImpl(this._self, this._then);

  final _PlayerStats _self;
  final $Res Function(_PlayerStats) _then;

/// Create a copy of PlayerStats
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? playerId = null,Object? matchesPlayed = null,Object? wins = null,Object? draws = null,Object? losses = null,Object? goals = null,Object? assists = null,Object? yellowCards = null,Object? redCards = null,Object? totalPoints = null,}) {
  return _then(_PlayerStats(
playerId: null == playerId ? _self.playerId : playerId // ignore: cast_nullable_to_non_nullable
as String,matchesPlayed: null == matchesPlayed ? _self.matchesPlayed : matchesPlayed // ignore: cast_nullable_to_non_nullable
as int,wins: null == wins ? _self.wins : wins // ignore: cast_nullable_to_non_nullable
as int,draws: null == draws ? _self.draws : draws // ignore: cast_nullable_to_non_nullable
as int,losses: null == losses ? _self.losses : losses // ignore: cast_nullable_to_non_nullable
as int,goals: null == goals ? _self.goals : goals // ignore: cast_nullable_to_non_nullable
as int,assists: null == assists ? _self.assists : assists // ignore: cast_nullable_to_non_nullable
as int,yellowCards: null == yellowCards ? _self.yellowCards : yellowCards // ignore: cast_nullable_to_non_nullable
as int,redCards: null == redCards ? _self.redCards : redCards // ignore: cast_nullable_to_non_nullable
as int,totalPoints: null == totalPoints ? _self.totalPoints : totalPoints // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
