import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/theme/app_colors.dart';
import '../application/ranking_providers.dart';
import '../domain/mvp_calculator.dart';
import '../domain/mvp_weights.dart';

/// Formate un nombre de points : `10`, `0,5`, `-1`.
String formatMvpPoints(double value) {
  final text = value == value.roundToDouble() ? value.toInt().toString() : value.toString();
  return text.replaceAll('.', ',');
}

Future<void> showMvpRulesSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: context.colors.background900,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const MvpRulesBottomSheet(),
  );
}

/// Icône d'aide ouvrant les règles détaillées du joueur du mois.
class MvpHelpButton extends StatelessWidget {
  const MvpHelpButton({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Règles du joueur du mois',
      visualDensity: VisualDensity.compact,
      icon: Icon(Remix.question_line, size: size, color: context.colors.foreground400),
      onPressed: () => unawaited(showMvpRulesSheet(context)),
    );
  }
}

class MvpRulesBottomSheet extends ConsumerWidget {
  const MvpRulesBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final weights = ref.watch(mvpWeightsProvider).value ?? MvpWeights.defaults;

    // Exemple : victoire, 2 buts, 1 passe, 1 jaune.
    final example = MvpCalculator.calculateMatchScore(
      isWin: true,
      isDraw: false,
      goals: 2,
      assists: 1,
      yellowCards: 1,
      redCards: 0,
      weights: weights,
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.background700,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Remix.trophy_line, color: colors.primary500, size: 22),
                const SizedBox(width: 10),
                Text(
                  'Règles du joueur du mois',
                  style: TextStyle(
                    color: colors.foreground50,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              weights.isDefault
                  ? 'Pondérations par défaut.'
                  : 'Pondérations personnalisées pour ce groupe (réglables dans Réglages).',
              style: TextStyle(color: colors.foreground400, fontSize: 12),
            ),
            const SizedBox(height: 16),
            _section(context, "Score d'un match"),
            _line(context, 'Victoire', weights.win),
            _line(context, 'Match nul', weights.draw),
            _line(context, 'Défaite', weights.loss),
            _line(context, 'But marqué', weights.goal),
            _line(context, 'Passe décisive', weights.assist),
            _line(context, 'Carton jaune', -weights.yellowCard),
            _line(context, 'Carton rouge', -weights.redCard),
            const SizedBox(height: 16),
            _section(context, 'Score du mois'),
            _paragraph(
              context,
              "C'est la moyenne des scores de chaque match joué dans le mois, "
              'arrondie à 2 décimales. Seules les séances clôturées et comptant '
              'pour le classement sont prises en compte.',
            ),
            const SizedBox(height: 16),
            _section(context, 'Éligibilité'),
            _paragraph(
              context,
              "Un joueur est éligible s'il a participé à toutes les séances du mois, "
              'à une près (au plus 1 séance manquée). Les joueurs non éligibles '
              'apparaissent après les éligibles.',
            ),
            const SizedBox(height: 16),
            _section(context, 'Départage'),
            _paragraph(
              context,
              "En cas d'égalité de score : plus de matchs joués, puis plus de buts, "
              'puis plus de passes, puis ordre alphabétique.',
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.primary500.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Exemple : victoire, 2 buts, 1 passe et 1 carton jaune = '
                '${formatMvpPoints(example)} pts pour ce match.',
                style: TextStyle(color: colors.primary400, fontSize: 13, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: context.colors.foreground400,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _paragraph(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(color: context.colors.foreground200, fontSize: 13, height: 1.4),
    );
  }

  Widget _line(BuildContext context, String label, double value) {
    final colors = context.colors;
    final signed = value > 0 ? '+${formatMvpPoints(value)}' : formatMvpPoints(value);
    final color = value > 0
        ? colors.primary400
        : value < 0
            ? colors.danger
            : colors.foreground400;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: colors.foreground200, fontSize: 14)),
          ),
          Text(
            '$signed pt${value.abs() > 1 ? 's' : ''}',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
