import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/data/app_database.dart';
import '../data/team_repository.dart';
import '../domain/team_info.dart';

final teamRepositoryProvider = Provider<TeamRepository>((ref) {
  return SqliteTeamRepository(AppDatabase.instance);
});

class HasTeamNotifier extends Notifier<bool> {
  HasTeamNotifier({this.initialValue});
  final bool? initialValue;

  @override
  bool build() => initialValue ?? false;

  // Un setter sans getter est intentionnel ici car `state` est la source de vérité Riverpod.
  // ignore: avoid_setters_without_getters
  set hasTeam(bool value) {
    state = value;
  }

  Future<void> reloadFromDb() async {
    final all = await ref.read(teamRepositoryProvider).getAllTeams();
    state = all.isNotEmpty;
  }
}

final hasTeamProvider = NotifierProvider<HasTeamNotifier, bool>(
  HasTeamNotifier.new,
);

class ActiveTeamIdNotifier extends Notifier<String?> {
  ActiveTeamIdNotifier({this.initialValue});
  final String? initialValue;

  @override
  String? build() => initialValue;

  Future<void> selectTeam(String teamId) async {
    state = teamId;
    await ref.read(teamRepositoryProvider).setActiveTeamId(teamId);
  }

  Future<void> reloadFromDb() async {
    final active = await ref.read(teamRepositoryProvider).getActiveTeam();
    state = active?.id;
  }
}

final activeTeamIdProvider = NotifierProvider<ActiveTeamIdNotifier, String?>(
  ActiveTeamIdNotifier.new,
);

final allTeamsProvider = FutureProvider<List<TeamInfo>>((ref) {
  return ref.watch(teamRepositoryProvider).getAllTeams();
});

class TeamInfoNotifier extends AsyncNotifier<TeamInfo?> {
  @override
  Future<TeamInfo?> build() async {
    final activeId = ref.watch(activeTeamIdProvider);
    final repo = ref.watch(teamRepositoryProvider);
    if (activeId != null) {
      return await repo.getTeamById(activeId);
    }
    final activeTeam = await repo.getActiveTeam();
    if (activeTeam != null && ref.read(activeTeamIdProvider) != activeTeam.id) {
      // Synchroniser activeTeamId (fire-and-forget intentionnel)
      unawaited(Future.microtask(
        () => ref.read(activeTeamIdProvider.notifier).selectTeam(activeTeam.id),
      ));
    }
    return activeTeam;
  }

  Future<void> saveTeam(TeamInfo team) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(teamRepositoryProvider).saveTeamInfo(team);
      ref.read(hasTeamProvider.notifier).hasTeam = true;
      ref.invalidate(allTeamsProvider);
      await ref.read(activeTeamIdProvider.notifier).selectTeam(team.id);
      return team;
    });
  }

  Future<void> switchTeam(String teamId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(activeTeamIdProvider.notifier).selectTeam(teamId);
      final team = await ref.read(teamRepositoryProvider).getTeamById(teamId);
      ref.invalidate(allTeamsProvider);
      return team;
    });
  }

  Future<void> deleteTeam(String teamId) async {
    await ref.read(teamRepositoryProvider).deleteTeam(teamId);
    ref.invalidate(allTeamsProvider);
    final all = await ref.read(teamRepositoryProvider).getAllTeams();
    if (all.isEmpty) {
      ref.read(hasTeamProvider.notifier).hasTeam = false;
      ref.read(activeTeamIdProvider.notifier).state = null;
      state = const AsyncData(null);
    } else {
      await switchTeam(all.first.id);
    }
  }
}

final AsyncNotifierProvider<TeamInfoNotifier, TeamInfo?> teamInfoProvider =
    AsyncNotifierProvider<TeamInfoNotifier, TeamInfo?>(
  TeamInfoNotifier.new,
);

final AsyncNotifierProvider<TeamInfoNotifier, TeamInfo?> activeTeamProvider = teamInfoProvider;

final FutureProvider<Map<String, int>> Function(String) teamCountsProvider =
    FutureProvider.family<Map<String, int>, String>((ref, teamId) {
  return ref.watch(teamRepositoryProvider).getTeamCounts(teamId);
});
