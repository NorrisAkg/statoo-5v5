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
  final activeTeamId = ref.watch(activeTeamIdProvider);
  if (activeTeamId == null) return Future.value(const []);
  return repo.getStandings(teamId: activeTeamId);
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
  if (activeTeamId == null) return Future.value(const []);
  return repo.getTopScorers(teamId: activeTeamId);
});

final topAssistsProvider = FutureProvider<List<AssistEntry>>((ref) {
  final repo = ref.watch(rankingRepositoryProvider);
  final activeTeamId = ref.watch(activeTeamIdProvider);
  if (activeTeamId == null) return Future.value(const []);
  return repo.getTopAssists(teamId: activeTeamId);
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
  if (activeTeamId == null) return Future.value(const []);
  return repo.getTopCards(teamId: activeTeamId, sortBy: filter);
});
