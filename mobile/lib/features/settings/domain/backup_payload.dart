class BackupPayload {
  const BackupPayload({
    required this.version,
    required this.exportedAt,
    required this.team,
    required this.players,
    required this.sessions,
    required this.participations,
    this.teams = const [],
    this.meta = const {},
    this.minPlayersPerSession,
  });

  factory BackupPayload.fromJson(Map<String, dynamic> json) {
    if (json.isEmpty) {
      throw const FormatException("Ce fichier n'est pas une sauvegarde Statoo valide (fichier vide).");
    }

    final rawVersion = json.containsKey('version') ? json['version'] : 1;
    if (rawVersion is! int) {
      throw const FormatException('La version de cette sauvegarde est invalide.');
    }
    validateVersion(rawVersion);
    final version = rawVersion;

    final app = json['app'] as String?;
    if (app != null && app != 'statoo_5v5') {
      throw FormatException("Ce fichier provient d'une autre application ($app).");
    }

    final rawExportedAt = json['exported_at'] as String?;
    final exportedAt = rawExportedAt != null
        ? DateTime.tryParse(rawExportedAt) ?? DateTime.now()
        : DateTime.now();

    final rawTeams = json['teams'] as List<dynamic>?;
    final parsedTeams = rawTeams
            ?.whereType<Map<String, dynamic>>()
            .where((t) => t['id'] != null)
            .toList() ??
        [];

    final rawTeam = json['team'] as Map<String, dynamic>?;
    final List<Map<String, dynamic>> teams;
    if (parsedTeams.isNotEmpty) {
      teams = parsedTeams;
    } else if (rawTeam != null && rawTeam['id'] != null) {
      teams = [rawTeam];
    } else {
      throw const FormatException(
        "Ce fichier n'est pas une sauvegarde Statoo valide (aucune équipe trouvée).",
      );
    }

    final team = teams.first;

    final rawPlayers = json['players'] as List<dynamic>? ?? [];
    final players = rawPlayers
        .whereType<Map<String, dynamic>>()
        .toList();

    final rawSessions = json['sessions'] as List<dynamic>? ?? [];
    final sessions = rawSessions
        .whereType<Map<String, dynamic>>()
        .toList();

    final rawParticipations = json['participations'] as List<dynamic>? ?? [];
    final participations = rawParticipations
        .whereType<Map<String, dynamic>>()
        .toList();

    final rawMeta = json['meta'] as Map<String, dynamic>? ?? {};

    final settings = json['settings'] as Map<String, dynamic>?;
    final minPlayers = settings?['min_players_per_session'] as int?;

    return BackupPayload(
      version: version,
      exportedAt: exportedAt,
      team: team,
      teams: teams,
      players: players,
      sessions: sessions,
      participations: participations,
      meta: rawMeta,
      minPlayersPerSession: minPlayers,
    );
  }

  static const currentVersion = 2;

  static void validateVersion(int version) {
    if (version > currentVersion) {
      throw FormatException(
        'Cette sauvegarde utilise une version plus récente ($version). '
        'Mettez Statoo à jour avant de la restaurer.',
      );
    }
    if (version < 1) {
      throw const FormatException('La version de cette sauvegarde est invalide.');
    }
  }

  final int version;
  final DateTime exportedAt;
  final Map<String, dynamic>? team;
  final List<Map<String, dynamic>> teams;
  final List<Map<String, dynamic>> players;
  final List<Map<String, dynamic>> sessions;
  final List<Map<String, dynamic>> participations;
  final Map<String, dynamic> meta;
  final int? minPlayersPerSession;

  Map<String, dynamic> toJson() {
    validateVersion(version);
    return {
      'version': currentVersion,
      'app': 'statoo_5v5',
      'exported_at': exportedAt.toIso8601String(),
      'team': team,
      'teams': teams.isNotEmpty ? teams : (team != null ? [team!] : <Map<String, dynamic>>[]),
      'players': players,
      'sessions': sessions,
      'participations': participations,
      'meta': meta,
      'settings': {
        if (minPlayersPerSession != null)
          'min_players_per_session': minPlayersPerSession,
      },
    };
  }
}

class RestoreResult {
  const RestoreResult({
    required this.isMerge,
    required this.teamName,
    required this.importedPlayersCount,
    required this.importedSessionsCount,
    required this.importedParticipationsCount,
    this.reusedPlayersCount = 0,
    this.skippedSessionsCount = 0,
    this.normalizedSessionsCount = 0,
    this.unavailablePhotosCount = 0,
  });

  final int unavailablePhotosCount;
  String get photoWarning => unavailablePhotosCount == 0 ? ''
      : '\n$unavailablePhotosCount photo(s) indisponible(s) : la sauvegarde contenait des chemins locaux. Ajoutez de nouveau ces photos.';

  final bool isMerge;
  final String teamName;
  final int importedPlayersCount;
  final int importedSessionsCount;
  final int importedParticipationsCount;
  final int reusedPlayersCount;
  final int skippedSessionsCount;
  /// Séances récupérées en brouillon car leur résultat clôturé est incomplet.
  final int normalizedSessionsCount;
}
