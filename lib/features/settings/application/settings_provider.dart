import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kMinPlayersKey = 'min_players_per_session';
const int kDefaultMinPlayers = 6;

class MinPlayersNotifier extends Notifier<int> {
  MinPlayersNotifier({this.initialValue});

  final int? initialValue;

  @override
  int build() {
    if (initialValue != null) return initialValue!;

    unawaited(
      SharedPreferences.getInstance().then((prefs) {
        final saved = prefs.getInt(kMinPlayersKey);
        if (saved != null && saved != state) {
          state = saved;
        }
      }),
    );

    return kDefaultMinPlayers;
  }

  Future<void> setMinPlayers(int count) async {
    if (count < 2) return;
    state = count;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kMinPlayersKey, count);
  }
}

final NotifierProvider<MinPlayersNotifier, int> minPlayersPerSessionProvider =
    NotifierProvider<MinPlayersNotifier, int>(
  MinPlayersNotifier.new,
);

const String kTournamentDrawPointsKey = 'tournament_draw_points';
const int kDefaultTournamentDrawPoints = 1;

class TournamentDrawPointsNotifier extends Notifier<int> {
  TournamentDrawPointsNotifier({this.initialValue});

  final int? initialValue;

  @override
  int build() {
    if (initialValue != null) return initialValue!;

    unawaited(
      SharedPreferences.getInstance().then((prefs) {
        final saved = prefs.getInt(kTournamentDrawPointsKey);
        if (saved != null && saved != state) {
          state = saved;
        }
      }),
    );

    return kDefaultTournamentDrawPoints;
  }

  Future<void> setDrawPoints(int points) async {
    if (points != 1 && points != 2) return;
    state = points;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kTournamentDrawPointsKey, points);
  }
}

final NotifierProvider<TournamentDrawPointsNotifier, int> tournamentDrawPointsProvider =
    NotifierProvider<TournamentDrawPointsNotifier, int>(
  TournamentDrawPointsNotifier.new,
);
