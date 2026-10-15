import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/data/app_database.dart';
import '../domain/backup_payload.dart';

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(AppDatabase.instance);
});

class BackupService {
  BackupService(this._appDatabase);

  final AppDatabase _appDatabase;

  /// Exporte l'intégralité des données en un fichier JSON et ouvre la feuille de partage native.
  Future<BackupPayload> exportAndShareBackup() async {
    final payload = await createBackupPayload();

    final jsonString = const JsonEncoder.withIndent('  ').convert(payload.toJson());
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final file = File('${tempDir.path}/statoo_backup_$timestamp.json');
    await file.writeAsString(jsonString);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: 'Sauvegarde Statoo 5v5',
        text: 'Sauvegarde des données Statoo du ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
      ),
    );

    return payload;
  }

  /// Construit l'objet BackupPayload à partir de la base SQLite et des SharedPreferences.
  Future<BackupPayload> createBackupPayload() async {
    final db = await _appDatabase.database;

    final teams = await db.query('teams');
    final team = teams.isNotEmpty ? teams.first : null;

    final players = await db.query('players');
    final sessions = await db.query('sessions');
    final participations = await db.query('participations');
    final metaRows = await db.query('meta');

    final meta = <String, dynamic>{};
    for (final row in metaRows) {
      final key = row['key'] as String?;
      if (key != null) {
        meta[key] = row['value'];
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final minPlayers = prefs.getInt('min_players_per_session');

    return BackupPayload(
      version: 2,
      exportedAt: DateTime.now(),
      team: team,
      teams: teams,
      players: players,
      sessions: sessions,
      participations: participations,
      meta: meta,
      minPlayersPerSession: minPlayers,
    );
  }

  /// Ouvre le sélecteur de fichier et parse le fichier JSON sélectionné.
  Future<BackupPayload?> pickBackupFile() async {
    final files = await FilePicker.pickFiles();

    if (files.isEmpty) {
      return null;
    }

    final file = files.first;
    final String content;

    try {
      content = await file.xFile.readAsString();
    } on Object {
      throw const FormatException('Impossible de lire le fichier sélectionné.');
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(content);
    } on Object {
      throw const FormatException('Le fichier sélectionné ne contient pas de JSON valide.');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException("Le fichier sélectionné n'est pas une sauvegarde Statoo valide.");
    }

    return BackupPayload.fromJson(decoded);
  }

  /// Restaure les données :
  /// - Si `merge == false` : Écrasement total de la base et remplacement par la sauvegarde.
  /// - Si `merge == true` : Fusion intelligente sans écraser les données locales.
  Future<RestoreResult> restoreBackup(
    BackupPayload payload, {
    required bool merge,
    String? targetTeamId,
  }) async {
    if (merge && payload.meta.keys.any((key) => key.startsWith('finance_') || key.startsWith('shared_') || key.startsWith('outbox_'))) {
      throw const FormatException('Cette sauvegarde contient des finances ou un groupe partagé. Utilisez la restauration complète pour conserver leurs identifiants et leur historique.');
    }
    final db = await _appDatabase.database;

    return await db.transaction((txn) async {
      if (!merge) {
        // --- MODE ÉCRASEMENT ---
        // 1. Suppression dans l'ordre strict des clés étrangères (enfants d'abord)
        await txn.delete('participations');
        await txn.delete('sessions');
        await txn.delete('players');
        await txn.delete('meta');
        await txn.delete('teams');

        // 2. Insertion dans l'ordre strict des clés étrangères (parents d'abord)
        final teamsToInsert = payload.teams.isNotEmpty
            ? payload.teams
            : (payload.team != null ? [payload.team!] : <Map<String, dynamic>>[]);

        for (final t in teamsToInsert) {
          await txn.insert('teams', t, conflictAlgorithm: ConflictAlgorithm.replace);
        }

        final defaultTeamId = teamsToInsert.isNotEmpty ? teamsToInsert.first['id'] as String : 'team_1';
        final validTeamIds = teamsToInsert.map((t) => t['id'] as String).toSet();

        for (final p in payload.players) {
          final rawTeamId = p['team_id'] as String?;
          final effectiveTeamId = (rawTeamId != null && validTeamIds.contains(rawTeamId))
              ? rawTeamId
              : defaultTeamId;
          final playerRow = {...p, 'team_id': effectiveTeamId};
          await txn.insert('players', playerRow, conflictAlgorithm: ConflictAlgorithm.replace);
        }

        for (final s in payload.sessions) {
          final rawTeamId = s['team_id'] as String?;
          final effectiveTeamId = (rawTeamId != null && validTeamIds.contains(rawTeamId))
              ? rawTeamId
              : defaultTeamId;
          final sessionRow = {..._withValidStatus(s), 'team_id': effectiveTeamId};
          await txn.insert('sessions', sessionRow, conflictAlgorithm: ConflictAlgorithm.replace);
        }

        for (final pt in payload.participations) {
          await txn.insert('participations', _withValidParticipation(pt), conflictAlgorithm: ConflictAlgorithm.replace);
        }

        for (final entry in payload.meta.entries) {
          await txn.insert('meta', {
            'key': entry.key,
            'value': entry.value?.toString(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }

        final prefs = await SharedPreferences.getInstance();
        if (payload.minPlayersPerSession != null) {
          await prefs.setInt('min_players_per_session', payload.minPlayersPerSession!);
        }

        if (teamsToInsert.isNotEmpty) {
          final firstTeam = teamsToInsert.first;
          final teamId = firstTeam['id'] as String;
          final teamName = firstTeam['name'] as String? ?? 'Équipe';
          await prefs.setString('active_team_id', teamId);
          await prefs.setString('team_name', teamName);
        }

        return RestoreResult(
          isMerge: false,
          teamName: teamsToInsert.isNotEmpty ? (teamsToInsert.first['name'] as String? ?? 'Équipe') : 'Équipe',
          importedPlayersCount: payload.players.length,
          importedSessionsCount: payload.sessions.length,
          importedParticipationsCount: payload.participations.length,
        );
      } else {
        // --- MODE FUSION INTELLIGENTE ---
        final localTeams = await txn.query('teams');
        String localTeamId;
        String localTeamName;

        if (localTeams.isEmpty) {
          if (payload.teams.isNotEmpty) {
            for (final t in payload.teams) {
              await txn.insert('teams', t, conflictAlgorithm: ConflictAlgorithm.replace);
            }
            localTeamId = payload.teams.first['id']! as String;
            localTeamName = payload.teams.first['name'] as String? ?? 'Équipe';
          } else if (payload.team != null) {
            await txn.insert('teams', payload.team!);
            localTeamId = payload.team!['id']! as String;
            localTeamName = payload.team!['name'] as String? ?? 'Équipe';
          } else {
            localTeamId = 'team_1';
            localTeamName = 'Mon Équipe';
            await txn.insert('teams', {
              'id': localTeamId,
              'name': localTeamName,
              'format': '5v5',
              'created_at': DateTime.now().toIso8601String(),
            });
          }
        } else {
          final matched = targetTeamId != null
              ? localTeams.where((t) => t['id'] == targetTeamId).firstOrNull
              : null;
          if (matched != null) {
            localTeamId = matched['id']! as String;
            localTeamName = matched['name'] as String? ?? 'Équipe';
          } else {
            localTeamId = localTeams.first['id']! as String;
            localTeamName = localTeams.first['name'] as String? ?? 'Équipe';
          }
        }

        // 1. Réconciliation des Joueurs
        final localPlayers = await txn.query('players', where: 'team_id = ?', whereArgs: [localTeamId]);
        final localPlayersByName = <String, String>{};
        final localPlayerIds = (await txn.query('players')).map((p) => p['id']! as String).toSet();

        for (final lp in localPlayers) {
          final name = (lp['name'] as String?)?.trim().toLowerCase();
          final id = lp['id']! as String;
          if (name != null && name.isNotEmpty) {
            localPlayersByName[name] = id;
          }
        }

        final playerMapping = <String, String>{};
        var importedPlayersCount = 0;
        var reusedPlayersCount = 0;

        for (final bp in payload.players) {
          final bpId = bp['id']! as String;
          final bpName = (bp['name'] as String?)?.trim() ?? '';
          final normalizedName = bpName.toLowerCase();

          if (localPlayersByName.containsKey(normalizedName)) {
            final matchedId = localPlayersByName[normalizedName]!;
            playerMapping[bpId] = matchedId;
            reusedPlayersCount++;
          } else {
            var targetId = bpId;
            if (localPlayerIds.contains(targetId)) {
              targetId = 'p_${DateTime.now().millisecondsSinceEpoch}_$importedPlayersCount';
            }

            final newPlayer = Map<String, dynamic>.from(bp);
            newPlayer['id'] = targetId;
            newPlayer['team_id'] = localTeamId;

            await txn.insert('players', newPlayer);
            localPlayerIds.add(targetId);
            localPlayersByName[normalizedName] = targetId;
            playerMapping[bpId] = targetId;
            importedPlayersCount++;
          }
        }

        // 2. Réconciliation des Séances (remapées vers localTeamId pour garantir l'intégrité référentielle)
        final localSessions = await txn.query('sessions', where: 'team_id = ?', whereArgs: [localTeamId]);
        final existingSessionIds = (await txn.query('sessions')).map((s) => s['id']! as String).toSet();
        final existingPlayedAt = localSessions
            .map((s) => s['played_at'] as String?)
            .whereType<String>()
            .toSet();

        var importedSessionsCount = 0;
        var skippedSessionsCount = 0;
        var importedParticipationsCount = 0;

        for (final bs in payload.sessions) {
          final bsId = bs['id']! as String;
          final bsPlayedAt = bs['played_at'] as String?;

          if (existingSessionIds.contains(bsId) ||
              (bsPlayedAt != null && existingPlayedAt.contains(bsPlayedAt))) {
            skippedSessionsCount++;
            continue;
          }

          final newSession = Map<String, dynamic>.from(_withValidStatus(bs));
          newSession['team_id'] = localTeamId;

          await txn.insert('sessions', newSession);
          existingSessionIds.add(bsId);
          if (bsPlayedAt != null) existingPlayedAt.add(bsPlayedAt);
          importedSessionsCount++;

          final relatedParticipations = payload.participations
              .where((pt) => pt['session_id'] == bsId);

          for (final pt in relatedParticipations) {
            final originalPlayerId = pt['player_id'] as String?;
            if (originalPlayerId == null) continue;

            final mappedPlayerId = playerMapping[originalPlayerId];
            if (mappedPlayerId != null) {
              final newPt = Map<String, dynamic>.from(pt);
              newPt['player_id'] = mappedPlayerId;

              await txn.insert(
                'participations',
                _withValidParticipation(newPt),
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
              importedParticipationsCount++;
            }
          }
        }

        return RestoreResult(
          isMerge: true,
          teamName: localTeamName,
          importedPlayersCount: importedPlayersCount,
          importedSessionsCount: importedSessionsCount,
          importedParticipationsCount: importedParticipationsCount,
          reusedPlayersCount: reusedPlayersCount,
          skippedSessionsCount: skippedSessionsCount,
        );
      }
    });
  }

  Map<String, dynamic> _withValidParticipation(Map<String, dynamic> pt) {
    var team = pt['team'];
    if (team == 'a') team = 'A';
    if (team == 'b') team = 'B';
    return team != null ? {...pt, 'team': team} : pt;
  }

  /// Same rule as the v5 migration: a backup taken before it may still hold CLOSED
  /// sessions without score, which would count as played matches worth 0 pts (CDC §4.2).
  Map<String, dynamic> _withValidStatus(Map<String, dynamic> session) {
    var res = session['result'];
    if (res == 'team_a') res = 'A';
    if (res == 'team_b') res = 'B';
    if (res == 'draw') res = 'DRAW';

    final normalized = Map<String, dynamic>.from(session);
    if (res != null) {
      normalized['result'] = res;
    }
    final unscored = normalized['score_a'] == null || normalized['score_b'] == null || normalized['result'] == null;
    return normalized['status'] == 'CLOSED' && unscored ? {...normalized, 'status': 'DRAFT'} : normalized;
  }
}
