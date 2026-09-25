import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/data/app_database.dart';
import '../../team/application/team_provider.dart';
import '../data/ranking_repository.dart';
import '../domain/assist_entry.dart';
import '../domain/card_entry.dart';
import '../domain/scorer_entry.dart';
import '../domain/standing_entry.dart';
import '../domain/standing_per_match_entry.dart';

final rankingRepositoryProvider = Provider<RankingRepository>((ref) {
  return SqliteRankingRepository(AppDatabase.instance);
});

final standingsProvider = FutureProvider<List<StandingEntry>>((ref) {
  final repo = ref.watch(rankingRepositoryProvider);
  final activeTeam = ref.watch(activeTeamProvider).value;
  return repo.getStandings(teamId: activeTeam?.id);
});

final standingsPerMatchProvider = FutureProvider<List<StandingPerMatchEntry>>((ref) {
  final repo = ref.watch(rankingRepositoryProvider);
  final activeTeam = ref.watch(activeTeamProvider).value;
  return repo.getStandingsPerMatch(teamId: activeTeam?.id);
});

final topScorersProvider = FutureProvider<List<ScorerEntry>>((ref) {
  final repo = ref.watch(rankingRepositoryProvider);
  final activeTeam = ref.watch(activeTeamProvider).value;
  return repo.getTopScorers(teamId: activeTeam?.id);
});

final topAssistsProvider = FutureProvider<List<AssistEntry>>((ref) {
  final repo = ref.watch(rankingRepositoryProvider);
  final activeTeam = ref.watch(activeTeamProvider).value;
  return repo.getTopAssists(teamId: activeTeam?.id);
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
  final activeTeam = ref.watch(activeTeamProvider).value;
  return repo.getTopCards(teamId: activeTeam?.id, sortBy: filter);
});
