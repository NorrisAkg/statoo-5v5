import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/data/app_database.dart';
import '../data/ranking_repository.dart';
import '../domain/assist_entry.dart';
import '../domain/scorer_entry.dart';
import '../domain/standing_entry.dart';
import '../domain/standing_per_match_entry.dart';

final rankingRepositoryProvider = Provider<RankingRepository>((ref) {
  return SqliteRankingRepository(AppDatabase.instance);
});

final standingsProvider = FutureProvider<List<StandingEntry>>((ref) {
  final repo = ref.watch(rankingRepositoryProvider);
  return repo.getStandings();
});

final standingsPerMatchProvider = FutureProvider<List<StandingPerMatchEntry>>((ref) {
  final repo = ref.watch(rankingRepositoryProvider);
  return repo.getStandingsPerMatch();
});

final topScorersProvider = FutureProvider<List<ScorerEntry>>((ref) {
  final repo = ref.watch(rankingRepositoryProvider);
  return repo.getTopScorers();
});

final topAssistsProvider = FutureProvider<List<AssistEntry>>((ref) {
  final repo = ref.watch(rankingRepositoryProvider);
  return repo.getTopAssists();
});
