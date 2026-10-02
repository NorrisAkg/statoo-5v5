import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statoo/features/ranking/application/ranking_providers.dart';
import 'package:statoo/features/ranking/data/ranking_repository.dart';
import 'package:statoo/features/ranking/domain/assist_entry.dart';
import 'package:statoo/features/ranking/domain/card_entry.dart';
import 'package:statoo/features/ranking/domain/mvp_entry.dart';
import 'package:statoo/features/ranking/domain/mvp_weights.dart';
import 'package:statoo/features/ranking/domain/scorer_entry.dart';
import 'package:statoo/features/ranking/domain/standing_entry.dart';
import 'package:statoo/features/ranking/domain/standing_per_match_entry.dart';
import 'package:statoo/features/team/application/team_provider.dart';

class FakeRankingRepository implements RankingRepository {
  String? lastStandingsMonth;
  String? lastMvpMonth;

  @override
  Future<List<String>> getAvailableMonths({String? teamId}) async {
    if (teamId == 'team_1') {
      return ['2026-10', '2026-09'];
    }
    return [];
  }

  @override
  Future<List<StandingEntry>> getStandings({String? teamId, String? month}) async {
    lastStandingsMonth = month;
    if (month == '2026-10') {
      return [
        const StandingEntry(
          rank: 1,
          playerId: 'p1',
          name: 'Lucas',
          isActive: true,
          matchesPlayed: 4,
          wins: 3,
          draws: 1,
          losses: 0,
          points: 10,
          goals: 6,
          assists: 4,
        ),
      ];
    }
    return [
      const StandingEntry(
        rank: 1,
        playerId: 'p1',
        name: 'Lucas',
        isActive: true,
        matchesPlayed: 14,
        wins: 10,
        draws: 2,
        losses: 2,
        points: 32,
        goals: 15,
        assists: 10,
      ),
    ];
  }

  @override
  Future<MvpWeights> getMvpWeights({String? teamId}) async => MvpWeights.defaults;

  @override
  Future<void> saveMvpWeights({required String teamId, required MvpWeights weights}) async {}

  @override
  Future<List<MvpEntry>> getMvpRanking({required String month, String? teamId}) async {
    lastMvpMonth = month;
    return [
      const MvpEntry(
        rank: 1,
        playerId: 'p2',
        name: 'Karim',
        matchesPlayed: 3,
        totalSessions: 4,
        wins: 2,
        draws: 1,
        losses: 0,
        goals: 5,
        assists: 1,
        yellowCards: 0,
        redCards: 0,
        score: 11.33,
        isEligible: true,
        missingMatches: 0,
      ),
    ];
  }

  @override
  Future<MvpEntry?> getPlayerOfTheMonth({String? teamId, String? month}) async {
    final list = await getMvpRanking(month: month ?? '2026-10', teamId: teamId);
    return list.firstOrNull;
  }

  @override
  Future<List<StandingPerMatchEntry>> getStandingsPerMatch({String? teamId}) async => [];

  @override
  Future<List<ScorerEntry>> getTopScorers({String? teamId, String? month}) async => [];

  @override
  Future<List<AssistEntry>> getTopAssists({String? teamId, String? month}) async => [];

  @override
  Future<List<CardEntry>> getTopCards({String? teamId, String sortBy = 'all', String? month}) async => [];
}

void main() {
  group('Monthly ranking and MVP providers', () {
    late FakeRankingRepository fakeRepo;

    setUp(() {
      fakeRepo = FakeRankingRepository();
    });

    test('selectedRankingMonthProvider changes state correctly', () {
      final container = ProviderContainer(
        overrides: [
          rankingRepositoryProvider.overrideWithValue(fakeRepo),
          activeTeamIdProvider.overrideWith(() => ActiveTeamIdNotifier(initialValue: 'team_1')),
        ],
      );

      expect(container.read(selectedRankingMonthProvider), isNull);

      container.read(selectedRankingMonthProvider.notifier).selectMonth('2026-10');
      expect(container.read(selectedRankingMonthProvider), '2026-10');

      container.read(selectedRankingMonthProvider.notifier).selectMonth(null);
      expect(container.read(selectedRankingMonthProvider), isNull);
    });

    test('standingsProvider reflects month filter when selectedRankingMonthProvider updates', () async {
      final container = ProviderContainer(
        overrides: [
          rankingRepositoryProvider.overrideWithValue(fakeRepo),
          activeTeamIdProvider.overrideWith(() => ActiveTeamIdNotifier(initialValue: 'team_1')),
        ],
      );

      // Initially All-time (null month)
      final allTime = await container.read(standingsProvider.future);
      expect(allTime.first.matchesPlayed, 14);
      expect(fakeRepo.lastStandingsMonth, isNull);

      // Select October
      container.read(selectedRankingMonthProvider.notifier).selectMonth('2026-10');
      final octStandings = await container.read(standingsProvider.future);
      expect(octStandings.first.matchesPlayed, 4);
      expect(fakeRepo.lastStandingsMonth, '2026-10');
    });

    test('monthlyMvpRankingProvider resolves month and returns MVP ranking', () async {
      final container = ProviderContainer(
        overrides: [
          rankingRepositoryProvider.overrideWithValue(fakeRepo),
          activeTeamIdProvider.overrideWith(() => ActiveTeamIdNotifier(initialValue: 'team_1')),
        ],
      );

      // When selectedRankingMonth is null, it defaults to latest available month ('2026-10')
      final mvpList = await container.read(monthlyMvpRankingProvider.future);
      expect(mvpList.length, 1);
      expect(mvpList.first.name, 'Karim');
      expect(fakeRepo.lastMvpMonth, '2026-10');
    });

    test('playerOfTheMonthProvider returns the MVP player', () async {
      final container = ProviderContainer(
        overrides: [
          rankingRepositoryProvider.overrideWithValue(fakeRepo),
          activeTeamIdProvider.overrideWith(() => ActiveTeamIdNotifier(initialValue: 'team_1')),
        ],
      );

      final potm = await container.read(playerOfTheMonthProvider.future);
      expect(potm, isNotNull);
      expect(potm!.playerId, 'p2');
      expect(potm.name, 'Karim');
    });
  });
}
