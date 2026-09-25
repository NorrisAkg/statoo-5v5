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

    final teams = await db.query('teams', limit: 1);
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
      version: 1,
      exportedAt: DateTime.now(),
      team: team,
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

    try {
      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Format de sauvegarde invalide.');
      }
      return BackupPayload.fromJson(decoded);
    } on Object {
      throw const FormatException(
        "Le fichier sélectionné n'est pas une sauvegarde Statoo valide.",
      );
    }
  }

  /// Restaure les données :
  /// - Si `merge == false` : Écrasement total de la base et remplacement par la sauvegarde.
  /// - Si `merge == true` : Fusion intelligente sans écraser les données locales.
  Future<RestoreResult> restoreBackup(
    BackupPayload payload, {
    required bool merge,
  }) async {
    final db = await _appDatabase.database;

    return await db.transaction((txn) async {
      if (!merge) {
        // --- MODE ÉCRASEMENT ---
        await txn.execute('PRAGMA foreign_keys = OFF;');
        await txn.delete('participations');
        await txn.delete('sessions');
        await txn.delete('players');
        await txn.delete('teams');
        await txn.delete('meta');
        await txn.execute('PRAGMA foreign_keys = ON;');

        if (payload.team != null) {
          await txn.insert('teams', payload.team!);
        }

        for (final p in payload.players) {
          await txn.insert('players', p);
        }

        for (final s in payload.sessions) {
          await txn.insert('sessions', s);
        }

        for (final pt in payload.participations) {
          await txn.insert('participations', pt);
        }

        for (final entry in payload.meta.entries) {
          await txn.insert('meta', {
            'key': entry.key,
            'value': entry.value?.toString(),
          });
        }

        if (payload.minPlayersPerSession != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('min_players_per_session', payload.minPlayersPerSession!);
        }

        return RestoreResult(
          isMerge: false,
          teamName: payload.team?['name'] as String? ?? 'Équipe',
          importedPlayersCount: payload.players.length,
          importedSessionsCount: payload.sessions.length,
          importedParticipationsCount: payload.participations.length,
        );
      } else {
        // --- MODE FUSION INTELLIGENTE ---
        final localTeams = await txn.query('teams', limit: 1);
        String localTeamId;
        String localTeamName;

        if (localTeams.isEmpty) {
          if (payload.team != null) {
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
          localTeamId = localTeams.first['id']! as String;
          localTeamName = localTeams.first['name'] as String? ?? 'Équipe';
        }

        // 1. Réconciliation des Joueurs
        final localPlayers = await txn.query('players');
        final localPlayersByName = <String, String>{};
        final localPlayerIds = <String>{};

        for (final lp in localPlayers) {
          final name = (lp['name'] as String?)?.trim().toLowerCase();
          final id = lp['id']! as String;
          if (name != null && name.isNotEmpty) {
            localPlayersByName[name] = id;
          }
          localPlayerIds.add(id);
        }

        final playerMapping = <String, String>{};
        var importedPlayersCount = 0;
        var reusedPlayersCount = 0;

        for (final bp in payload.players) {
          final bpId = bp['id']! as String;
          final bpName = (bp['name'] as String?)?.trim() ?? '';
          final normalizedName = bpName.toLowerCase();

          if (localPlayersByName.containsKey(normalizedName)) {
            // Le joueur existe déjà sous le même nom
            final matchedId = localPlayersByName[normalizedName]!;
            playerMapping[bpId] = matchedId;
            reusedPlayersCount++;
          } else {
            // Nouveau joueur à insérer
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

        // 2. Réconciliation des Séances
        final localSessions = await txn.query('sessions');
        final existingSessionIds = localSessions.map((s) => s['id']! as String).toSet();
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

          // Si la séance existe déjà (par ID ou par date exacte), on la saute
          if (existingSessionIds.contains(bsId) ||
              (bsPlayedAt != null && existingPlayedAt.contains(bsPlayedAt))) {
            skippedSessionsCount++;
            continue;
          }

          // Insérer la séance
          await txn.insert('sessions', bs);
          existingSessionIds.add(bsId);
          if (bsPlayedAt != null) existingPlayedAt.add(bsPlayedAt);
          importedSessionsCount++;

          // Insérer les participations correspondantes en utilisant le mapping des joueurs
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
                newPt,
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
}
