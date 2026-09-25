class BackupPayload {
  const BackupPayload({
    required this.version,
    required this.exportedAt,
    required this.team,
    required this.players,
    required this.sessions,
    required this.participations,
    this.meta = const {},
    this.minPlayersPerSession,
  });

  factory BackupPayload.fromJson(Map<String, dynamic> json) {
    final rawVersion = json['version'];
    final version = rawVersion is int ? rawVersion : 1;

    final rawExportedAt = json['exported_at'] as String?;
    final exportedAt = rawExportedAt != null
        ? DateTime.tryParse(rawExportedAt) ?? DateTime.now()
        : DateTime.now();

    final rawTeam = json['team'] as Map<String, dynamic>?;

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
      team: rawTeam,
      players: players,
      sessions: sessions,
      participations: participations,
      meta: rawMeta,
      minPlayersPerSession: minPlayers,
    );
  }

  final int version;
  final DateTime exportedAt;
  final Map<String, dynamic>? team;
  final List<Map<String, dynamic>> players;
  final List<Map<String, dynamic>> sessions;
  final List<Map<String, dynamic>> participations;
  final Map<String, dynamic> meta;
  final int? minPlayersPerSession;

  Map<String, dynamic> toJson() => {
        'version': version,
        'app': 'statoo_5v5',
        'exported_at': exportedAt.toIso8601String(),
        'team': team,
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

class RestoreResult {
  const RestoreResult({
    required this.isMerge,
    required this.teamName,
    required this.importedPlayersCount,
    required this.importedSessionsCount,
    required this.importedParticipationsCount,
    this.reusedPlayersCount = 0,
    this.skippedSessionsCount = 0,
  });

  final bool isMerge;
  final String teamName;
  final int importedPlayersCount;
  final int importedSessionsCount;
  final int importedParticipationsCount;
  final int reusedPlayersCount;
  final int skippedSessionsCount;
}
