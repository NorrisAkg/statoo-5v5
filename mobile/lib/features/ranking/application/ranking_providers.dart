import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/data/app_database.dart';
import '../../team/application/team_provider.dart';
import '../data/ranking_repository.dart';
import '../domain/assist_entry.dart';
import '../domain/card_entry.dart';
import '../domain/mvp_entry.dart';
import '../domain/mvp_weights.dart';
import '../domain/scorer_entry.dart';
import '../domain/standing_entry.dart';
import '../domain/standing_per_match_entry.dart';

final rankingRepositoryProvider = Provider<RankingRepository>((ref) {
  return SqliteRankingRepository(AppDatabase.instance);
});

class RankingMonthNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  // Riverpod notifiers idiomatically expose methods for actions.
  // ignore: use_setters_to_change_properties
  void selectMonth(String? month) => state = month;
}

final selectedRankingMonthProvider = NotifierProvider<RankingMonthNotifier, String?>(
  RankingMonthNotifier.new,
);

final availableRankingMonthsProvider = FutureProvider<List<String>>((ref) {
  final repo = ref.watch(rankingRepositoryProvider);
  final activeTeamId = ref.watch(activeTeamIdProvider);
  if (activeTeamId == null) return Future.value(const []);
  return repo.getAvailableMonths(teamId: activeTeamId);
});

final standingsProvider = FutureProvider<List<StandingEntry>>((ref) {
  final repo = ref.watch(rankingRepositoryProvider);
  final activeTeamId = ref.watch(activeTeamIdProvider);
  final selectedMonth = ref.watch(selectedRankingMonthProvider);
  if (activeTeamId == null) return Future.value(const []);
  return repo.getStandings(teamId: activeTeamId, month: selectedMonth);
});

final standingsPerMatchProvider = FutureProvider<List<StandingPerMatchEntry>>((ref) {
  final repo = ref.watch(rankingRepositoryProvider);
  final activeTeamId = ref.watch(activeTeamIdProvider);
  if (activeTeamId == null) return Future.value(const []);
  return repo.getStandingsPerMatch(teamId: activeTeamId);
});

final topScorersProvider = FutureProvider<List<ScorerEntry>>((ref) {
  final repo = ref.watch(rankingRepositoryProvider);
  final activeTeamId = ref.watch(activeTeamIdProvider);
  final selectedMonth = ref.watch(selectedRankingMonthProvider);
  if (activeTeamId == null) return Future.value(const []);
  return repo.getTopScorers(teamId: activeTeamId, month: selectedMonth);
});

final topAssistsProvider = FutureProvider<List<AssistEntry>>((ref) {
  final repo = ref.watch(rankingRepositoryProvider);
  final activeTeamId = ref.watch(activeTeamIdProvider);
  final selectedMonth = ref.watch(selectedRankingMonthProvider);
  if (activeTeamId == null) return Future.value(const []);
  return repo.getTopAssists(teamId: activeTeamId, month: selectedMonth);
});

class CardsFilterNotifier extends Notifier<String> {
  @override
  String build() => 'all';

  String get filter => state;
  set filter(String value) => state = value;
}

final cardsFilterProvider = NotifierProvider<CardsFilterNotifier, String>(
  CardsFilterNotifier.new,
);

final topCardsProvider = FutureProvider<List<CardEntry>>((ref) {
  final repo = ref.watch(rankingRepositoryProvider);
  final filter = ref.watch(cardsFilterProvider);
  final activeTeamId = ref.watch(activeTeamIdProvider);
  final selectedMonth = ref.watch(selectedRankingMonthProvider);
  if (activeTeamId == null) return Future.value(const []);
  return repo.getTopCards(teamId: activeTeamId, sortBy: filter, month: selectedMonth);
});

final selectedMvpMonthProvider = NotifierProvider<RankingMonthNotifier, String?>(
  RankingMonthNotifier.new,
);

class MvpWeightsController extends AsyncNotifier<MvpWeights> {
  @override
  Future<MvpWeights> build() {
    final activeTeamId = ref.watch(activeTeamIdProvider);
    if (activeTeamId == null) return Future.value(MvpWeights.defaults);
    return ref.watch(rankingRepositoryProvider).getMvpWeights(teamId: activeTeamId);
  }

  Future<void> save(MvpWeights weights) async {
    final activeTeamId = ref.read(activeTeamIdProvider);
    if (activeTeamId == null) throw StateError('No active team selected');
    await ref.read(rankingRepositoryProvider).saveMvpWeights(teamId: activeTeamId, weights: weights);
    state = AsyncData(weights);
    ref
      ..invalidate(monthlyMvpRankingProvider)
      ..invalidate(playerOfTheMonthProvider);
  }

  Future<void> reset() => save(MvpWeights.defaults);
}

final AsyncNotifierProvider<MvpWeightsController, MvpWeights> mvpWeightsProvider =
    AsyncNotifierProvider<MvpWeightsController, MvpWeights>(MvpWeightsController.new);

final monthlyMvpRankingProvider = FutureProvider<List<MvpEntry>>((ref) async {
  final repo = ref.watch(rankingRepositoryProvider);
  final activeTeamId = ref.watch(activeTeamIdProvider);
  final selectedMonth = ref.watch(selectedMvpMonthProvider);
  if (activeTeamId == null) return const [];

  String? targetMonth = selectedMonth;
  if (targetMonth == null || targetMonth.isEmpty) {
    final available = await ref.watch(availableRankingMonthsProvider.future);
    if (available.isEmpty) return const [];
    targetMonth = available.first;
  }

  return await repo.getMvpRanking(month: targetMonth, teamId: activeTeamId);
});

final playerOfTheMonthProvider = FutureProvider<MvpEntry?>((ref) async {
  final repo = ref.watch(rankingRepositoryProvider);
  final activeTeamId = ref.watch(activeTeamIdProvider);
  if (activeTeamId == null) return null;
  return await repo.getPlayerOfTheMonth(teamId: activeTeamId);
});

enum StandingsViewMode {
  championship,
  mvp,
}

class StandingsViewModeNotifier extends Notifier<StandingsViewMode> {
  @override
  StandingsViewMode build() => StandingsViewMode.championship;

  void selectMode(StandingsViewMode mode) {
    if (state != mode) {
      state = mode;
    }
  }
}

final standingsViewModeProvider = NotifierProvider<StandingsViewModeNotifier, StandingsViewMode>(
  StandingsViewModeNotifier.new,
);
