import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/participation.dart';

class PlayerDisciplineSheet extends StatelessWidget {
  const PlayerDisciplineSheet({
    required this.playerName,
    required this.playerId,
    required this.team,
    this.yellowCards = 0,
    this.redCards = 0,
    super.key,
  });

  final String playerName;
  final String playerId;
  final Team team;
  final int yellowCards;
  final int redCards;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colors.background700,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Discipline · $playerName',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                side: BorderSide(color: colors.background700),
              ),
              onPressed: () => Navigator.pop(context, {
                'type': 'yellow',
                'team': team.name.toUpperCase(),
                'player': playerId,
                'delta': 1,
              }),
              icon: Icon(
                Remix.rectangle_fill,
                size: 20,
                color: colors.card,
              ),
              label: const Text('Carton jaune'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                side: BorderSide(color: colors.background700),
              ),
              onPressed: () => Navigator.pop(context, {
                'type': 'red',
                'team': team.name.toUpperCase(),
                'player': playerId,
                'delta': 1,
              }),
              icon: Icon(
                Remix.rectangle_fill,
                size: 20,
                color: colors.danger,
              ),
              label: const Text('Carton rouge'),
            ),
            if (yellowCards > 0) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  side: BorderSide(color: colors.background700),
                ),
                onPressed: () => Navigator.pop(context, {
                  'type': 'yellow',
                  'team': team.name.toUpperCase(),
                  'player': playerId,
                  'delta': -1,
                }),
                icon: Icon(
                  Remix.arrow_go_back_line,
                  size: 20,
                  color: colors.foreground300,
                ),
                label: Text(
                  'Retirer le carton jaune (-1)',
                  style: TextStyle(color: colors.foreground300),
                ),
              ),
            ],
            if (redCards > 0) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  side: BorderSide(color: colors.background700),
                ),
                onPressed: () => Navigator.pop(context, {
                  'type': 'red',
                  'team': team.name.toUpperCase(),
                  'player': playerId,
                  'delta': -1,
                }),
                icon: Icon(
                  Remix.arrow_go_back_line,
                  size: 20,
                  color: colors.danger,
                ),
                label: Text(
                  'Retirer le carton rouge (-1)',
                  style: TextStyle(color: colors.danger),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
