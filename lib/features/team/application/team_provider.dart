import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/data/app_database.dart';
import '../data/team_repository.dart';
import '../domain/team_info.dart';

final teamRepositoryProvider = Provider<TeamRepository>((ref) {
  return SqliteTeamRepository(AppDatabase.instance);
});

class TeamInfoNotifier extends AsyncNotifier<TeamInfo?> {
  @override
  Future<TeamInfo?> build() => ref.watch(teamRepositoryProvider).getTeamInfo();

  Future<void> saveTeam(TeamInfo team) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(teamRepositoryProvider).saveTeamInfo(team);
      return team;
    });
  }
}

final teamInfoProvider = AsyncNotifierProvider<TeamInfoNotifier, TeamInfo?>(
  TeamInfoNotifier.new,
);
