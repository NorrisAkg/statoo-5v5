import 'package:flutter_test/flutter_test.dart';
import 'package:statoo/features/ranking/application/file_export_platform.dart';
import 'package:statoo/features/ranking/application/stats_export_service.dart';
import 'package:statoo/features/ranking/data/ranking_repository.dart';
import 'package:statoo/features/ranking/domain/assist_entry.dart';
import 'package:statoo/features/ranking/domain/card_entry.dart';
import 'package:statoo/features/ranking/domain/mvp_entry.dart';
import 'package:statoo/features/ranking/domain/mvp_weights.dart';
import 'package:statoo/features/ranking/domain/scorer_entry.dart';
import 'package:statoo/features/ranking/domain/standing_entry.dart';
import 'package:statoo/features/ranking/domain/standing_per_match_entry.dart';

class FakeRankingRepository implements RankingRepository {
  String? lastQueriedTeamId;
  String? lastQueriedMonth;
  List<StandingEntry> stubbedStandings = <StandingEntry>[];

  @override
  Future<List<StandingEntry>> getStandings({String? teamId, String? month}) async {
    lastQueriedTeamId = teamId;
    lastQueriedMonth = month;
    return stubbedStandings;
  }

  @override
  Future<List<String>> getAvailableMonths({String? teamId}) async => <String>[];

  @override
  Future<List<StandingPerMatchEntry>> getStandingsPerMatch({String? teamId}) async => <StandingPerMatchEntry>[];

  @override
  Future<List<ScorerEntry>> getTopScorers({String? teamId, String? month}) async => <ScorerEntry>[];

  @override
  Future<List<AssistEntry>> getTopAssists({String? teamId, String? month}) async => <AssistEntry>[];

  @override
  Future<List<CardEntry>> getTopCards({String? teamId, String sortBy = 'all', String? month}) async => <CardEntry>[];

  @override
  Future<List<MvpEntry>> getMvpRanking({required String month, String? teamId}) async => <MvpEntry>[];

  @override
  Future<MvpEntry?> getPlayerOfTheMonth({String? teamId, String? month}) async => null;

  @override
  Future<MvpWeights> getMvpWeights({String? teamId}) async => MvpWeights.defaults;

  @override
  Future<void> saveMvpWeights({required String teamId, required MvpWeights weights}) async {}
}

class FakeFileExportPlatform implements FileExportPlatform {
  String? lastFileName;
  String? lastContent;
  String? lastMimeType;
  int exportCallCount = 0;

  @override
  Future<void> exportFile({
    required String fileName,
    required String content,
    required String mimeType,
  }) async {
    exportCallCount++;
    lastFileName = fileName;
    lastContent = content;
    lastMimeType = mimeType;
  }
}

void main() {
  late FakeRankingRepository fakeRepo;
  late FakeFileExportPlatform fakePlatform;
  late StatsExportService service;
  final fixedDate = DateTime(2026, 10, 30, 14, 45, 10);

  const sampleStandings = [
    StandingEntry(
      rank: 1,
      playerId: 'p1',
      name: 'Yanis',
      nickname: 'El Mago',
      isActive: true,
      matchesPlayed: 12,
      wins: 10,
      draws: 1,
      losses: 1,
      points: 31,
      goals: 18,
      assists: 9,
    ),
    StandingEntry(
      rank: 2,
      playerId: 'p2',
      name: 'Sami',
      isActive: true,
      matchesPlayed: 11,
      wins: 7,
      draws: 2,
      losses: 2,
      points: 23,
      goals: 8,
      assists: 4,
    ),
  ];

  setUp(() {
    fakeRepo = FakeRankingRepository();
    fakePlatform = FakeFileExportPlatform();
    service = StatsExportService(
      rankingRepository: fakeRepo,
      fileExportPlatform: fakePlatform,
      clock: () => fixedDate,
    );
  });

  group('StatsExportService', () {
    test('export nominal saison complète génère le bon nom et transmet le CSV', () async {
      fakeRepo.stubbedStandings = sampleStandings;

      final result = await service.exportStandings(teamId: 'team_alpha');

      expect(result.isEmpty, isFalse);
      expect(result.rowCount, 2);
      expect(result.fileName, 'classement_team_alpha_saison_20261030_144510.csv');

      expect(fakePlatform.exportCallCount, 1);
      expect(fakePlatform.lastFileName, 'classement_team_alpha_saison_20261030_144510.csv');
      expect(fakePlatform.lastMimeType, 'text/csv');
      expect(fakePlatform.lastContent, startsWith('\uFEFFRang;Nom;'));
      expect(fakePlatform.lastContent, contains('Yanis;El Mago;31;'));
    });

    test('export filtré par mois génère le format classement_<team>_<mois>_<timestamp>.csv', () async {
      fakeRepo.stubbedStandings = sampleStandings;

      final result = await service.exportStandings(
        teamId: 'team_alpha',
        month: '2026-10',
      );

      expect(result.isEmpty, isFalse);
      expect(result.fileName, 'classement_team_alpha_2026-10_20261030_144510.csv');
      expect(fakeRepo.lastQueriedMonth, '2026-10');
      expect(fakePlatform.lastFileName, 'classement_team_alpha_2026-10_20261030_144510.csv');
    });

    test("gestion du cas vide (aucun joueur classé) : StatsExportResult.empty() et pas d'export", () async {
      fakeRepo.stubbedStandings = <StandingEntry>[];

      final result = await service.exportStandings(teamId: 'team_alpha');

      expect(result.isEmpty, isTrue);
      expect(result.rowCount, 0);
      expect(result.fileName, isNull);
      expect(fakePlatform.exportCallCount, 0);
    });

    test('isolation multi-tenant : vérifie que le repository est interrogé avec le teamId exact', () async {
      fakeRepo.stubbedStandings = sampleStandings;

      await service.exportStandings(teamId: 'team_tenant_99');

      expect(fakeRepo.lastQueriedTeamId, 'team_tenant_99');
    });

    test('lève une StateError si teamId est null ou vide', () async {
      expect(
        service.exportStandings,
        throwsA(isA<StateError>()),
      );

      expect(
        () => service.exportStandings(teamId: ''),
        throwsA(isA<StateError>()),
      );

      expect(
        () => service.exportStandings(teamId: '   '),
        throwsA(isA<StateError>()),
      );

      expect(fakePlatform.exportCallCount, 0);
    });
  });
}
