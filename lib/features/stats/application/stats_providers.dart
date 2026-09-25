import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/data/app_database.dart';
import '../../team/application/team_provider.dart';
import '../data/stats_repository.dart';
import '../domain/group_totals.dart';

final statsRepositoryProvider = Provider<StatsRepository>((ref) {
  return SqliteStatsRepository(AppDatabase.instance);
});

final groupTotalsProvider = FutureProvider<GroupTotals>((ref) {
  final repo = ref.watch(statsRepositoryProvider);
  final activeTeam = ref.watch(activeTeamProvider).value;
  return repo.getGroupTotals(teamId: activeTeam?.id);
});
