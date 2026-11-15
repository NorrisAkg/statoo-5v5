import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ranking_repository.dart';
import '../domain/standings_csv_formatter.dart';
import 'file_export_platform.dart';
import 'ranking_providers.dart';

/// Résultat d'une tentative d'exportation de statistiques.
class StatsExportResult {
  const StatsExportResult({
    required this.isEmpty,
    required this.rowCount,
    this.fileName,
  });

  const StatsExportResult.empty()
      : isEmpty = true,
        rowCount = 0,
        fileName = null;

  final bool isEmpty;
  final int rowCount;
  final String? fileName;
}

/// Service orchestrant l'extraction des données de classement,
/// leur conversion en CSV RFC 4180 et leur transmission à la plateforme d'export.
class StatsExportService {
  StatsExportService({
    required this.rankingRepository,
    required this.fileExportPlatform,
    this.csvFormatter = const StandingsCsvFormatter(),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final RankingRepository rankingRepository;
  final FileExportPlatform fileExportPlatform;
  final StandingsCsvFormatter csvFormatter;
  final DateTime Function() _clock;

  /// Exporte le classement complet ou filtré par mois.
  ///
  /// Lève une [StateError] si [teamId] est nul ou vide.
  /// Si aucun joueur n'est classé, retourne [StatsExportResult.empty] sans déclencher l'export.
  Future<StatsExportResult> exportStandings({
    String? teamId,
    String? month,
  }) async {
    if (teamId == null || teamId.trim().isEmpty) {
      throw StateError('Un teamId actif est requis pour exporter le classement.');
    }

    final effectiveTeamId = teamId.trim();
    final standings = await rankingRepository.getStandings(
      teamId: effectiveTeamId,
      month: month,
    );

    if (standings.isEmpty) {
      return const StatsExportResult.empty();
    }

    final now = _clock();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');
    final formattedTimestamp = '$y$m${d}_$hh$mm$ss';

    final String fileName;
    if (month != null && month.isNotEmpty) {
      fileName = 'classement_${effectiveTeamId}_${month}_$formattedTimestamp.csv';
    } else {
      fileName = 'classement_${effectiveTeamId}_saison_$formattedTimestamp.csv';
    }

    final csvContent = csvFormatter.format(standings);

    await fileExportPlatform.exportFile(
      fileName: fileName,
      content: csvContent,
      mimeType: 'text/csv',
    );

    return StatsExportResult(
      isEmpty: false,
      rowCount: standings.length,
      fileName: fileName,
    );
  }
}

final statsExportServiceProvider = Provider<StatsExportService>((ref) {
  final rankingRepository = ref.watch(rankingRepositoryProvider);
  final fileExportPlatform = ref.watch(fileExportPlatformProvider);
  return StatsExportService(
    rankingRepository: rankingRepository,
    fileExportPlatform: fileExportPlatform,
  );
});
