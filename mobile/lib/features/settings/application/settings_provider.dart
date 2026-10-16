import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/data/app_database.dart';
import '../../shared/application/shared_providers.dart';
import '../../team/application/team_provider.dart';
import '../data/group_settings_repository.dart';

final Provider<GroupSettingsRepository> groupSettingsRepositoryProvider =
    Provider<GroupSettingsRepository>((ref) {
  return SqliteGroupSettingsRepository(AppDatabase.instance);
});

const String kMinPlayersKey = 'min_players_per_session';
const int kDefaultMinPlayers = 6;

const String kTournamentDrawPointsKey = 'tournament_draw_points';
const int kDefaultTournamentDrawPoints = 1;

/// Réglage entier propre au groupe actif. Une valeur absente retombe sur
/// l'ancien réglage global (SharedPreferences), puis sur le défaut.
abstract class GroupIntSettingNotifier extends Notifier<int> {
  GroupIntSettingNotifier({this.initialValue});

  /// Valeur imposée (tests) : neutralise le chargement depuis la base.
  final int? initialValue;

  String get key;
  int get defaultValue;

  @override
  int build() {
    final teamId = ref.watch(activeTeamIdProvider);
    if (initialValue != null) return initialValue!;
    if (teamId != null) unawaited(_load(teamId));
    return defaultValue;
  }

  Future<int> _read(String teamId) async {
    final stored = await ref.read(groupSettingsRepositoryProvider).getInt(teamId, key);
    if (stored != null) return stored;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(key) ?? defaultValue;
  }

  Future<void> _load(String teamId) async {
    final value = await _read(teamId);
    // The group may have changed while reading: never apply another group's value.
    if (!ref.mounted) return;
    if (ref.read(activeTeamIdProvider) == teamId && value != state) {
      state = value;
    }
  }

  Future<void> reload() async {
    final teamId = ref.read(activeTeamIdProvider);
    if (teamId == null) {
      state = defaultValue;
      return;
    }
    await _load(teamId);
  }

  Future<void> _save(int value) async {
    final teamId = ref.read(activeTeamIdProvider);
    if (teamId == null) return;
    state = value;
    await ref.read(groupSettingsRepositoryProvider).setInt(teamId, key, value);
  }
}

class MinPlayersNotifier extends GroupIntSettingNotifier {
  MinPlayersNotifier({super.initialValue});

  @override
  String get key => kMinPlayersKey;

  @override
  int get defaultValue => kDefaultMinPlayers;

  @override
  int build() {
    ref.watch(sharedStatusProvider);
    final group = ref.watch(activeTeamIdProvider);
    final service = ref.watch(sharedServiceProvider);
    if (initialValue == null && group != null && group == service.groupId) {
      final settings = service.snapshot?['sport_settings'] as Map?;
      final minimum = settings?['min_players_per_session'];
      return minimum is int && minimum >= 2 && minimum <= 30
          ? minimum : kDefaultMinPlayers;
    }
    return super.build();
  }

  Future<void> setMinPlayers(int count) async {
    if (count < 2 || count > 30) return;
    final group = ref.read(activeTeamIdProvider);
    final service = ref.read(sharedServiceProvider);
    if (group == service.groupId || service.protectedGroups.contains(group)) return;
    await _save(count);
  }
}

final NotifierProvider<MinPlayersNotifier, int> minPlayersPerSessionProvider =
    NotifierProvider<MinPlayersNotifier, int>(
  MinPlayersNotifier.new,
);

class TournamentDrawPointsNotifier extends GroupIntSettingNotifier {
  TournamentDrawPointsNotifier({super.initialValue});

  @override
  String get key => kTournamentDrawPointsKey;

  @override
  int get defaultValue => kDefaultTournamentDrawPoints;

  Future<void> setDrawPoints(int points) async {
    if (points != 1 && points != 2) return;
    await _save(points);
  }
}

final NotifierProvider<TournamentDrawPointsNotifier, int> tournamentDrawPointsProvider =
    NotifierProvider<TournamentDrawPointsNotifier, int>(
  TournamentDrawPointsNotifier.new,
);
