import 'package:flutter/material.dart';

import '../../team/domain/team_info.dart';
import '../domain/backup_payload.dart';

/// La sélection d'un fichier ne constitue jamais un consentement à l'effacement.
Future<bool> confirmReplacement(
  BuildContext context,
  BackupPayload payload,
  List<TeamInfo> teams,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remplacer tous les groupes locaux ?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cette restauration supprime toutes les données de tous les groupes de cet appareil, y compris les finances et les saisies non synchronisées. Conservez une sauvegarde avant de continuer.',
              ),
              const SizedBox(height: 12),
              Text(
                teams.isEmpty
                    ? 'Aucun groupe local actuellement.'
                    : 'Groupes remplacés : ${teams.map((t) => t.name).join(', ')}',
              ),
              const SizedBox(height: 12),
              Text(
                'Groupes de la sauvegarde : ${(payload.teams.isEmpty ? [if (payload.team != null) payload.team!] : payload.teams).map((t) => t['name'] ?? t['id']).join(', ')}',
              ),
              Text(
                '${payload.players.length} joueurs · ${payload.sessions.length} séances',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remplacer toutes les données'),
          ),
        ],
      ),
    ) ??
    false;
