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

  Future<void> reloadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(kMinPlayersKey);
    if (saved != null) {
      state = saved;
    }
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
