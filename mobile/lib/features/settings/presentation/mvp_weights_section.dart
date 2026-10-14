import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../ranking/application/ranking_providers.dart';
import '../../ranking/domain/mvp_weights.dart';
import '../../ranking/presentation/mvp_rules_bottom_sheet.dart';
import '../../team/application/team_provider.dart';

const double _kStep = 0.5;
const double _kMax = 50;

/// Réglage des pondérations du joueur du mois pour le groupe actif.
class MvpWeightsSection extends ConsumerWidget {
  const MvpWeightsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final hasTeam = ref.watch(activeTeamIdProvider) != null;
    final weights = ref.watch(mvpWeightsProvider).value ?? MvpWeights.defaults;
    final controller = ref.read(mvpWeightsProvider.notifier);

    void update(MvpWeights next) => unawaited(controller.save(next));

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Points attribués par match, moyennés sur le mois.',
                  style: TextStyle(color: colors.foreground400, fontSize: 12),
                ),
              ),
              const MvpHelpButton(),
            ],
          ),
          if (!hasTeam)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Sélectionnez un groupe pour régler les pondérations.',
                style: TextStyle(color: colors.foreground400, fontSize: 13),
              ),
            )
          else ...[
            _row(context, 'Victoire', weights.win, (v) => update(weights.copyWith(win: v))),
            _row(context, 'Match nul', weights.draw, (v) => update(weights.copyWith(draw: v))),
            _row(context, 'Défaite', weights.loss, (v) => update(weights.copyWith(loss: v))),
            _row(context, 'But', weights.goal, (v) => update(weights.copyWith(goal: v))),
            _row(context, 'Passe décisive', weights.assist, (v) => update(weights.copyWith(assist: v))),
            _row(
              context,
              'Carton jaune (malus)',
              weights.yellowCard,
              (v) => update(weights.copyWith(yellowCard: v)),
            ),
            _row(
              context,
              'Carton rouge (malus)',
              weights.redCard,
              (v) => update(weights.copyWith(redCard: v)),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Remix.restart_line, size: 16),
                label: const Text('Réinitialiser par défaut'),
                style: TextButton.styleFrom(foregroundColor: colors.primary400),
                onPressed: weights.isDefault ? null : () => unawaited(controller.reset()),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, double value, ValueChanged<double> onChanged) {
    final colors = context.colors;
    final canDecrease = value > 0;
    final canIncrease = value < _kMax;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: colors.foreground50,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Remix.subtract_line, size: 18),
            color: canDecrease ? colors.foreground200 : colors.foreground600,
            onPressed: canDecrease ? () => onChanged((value - _kStep).clamp(0, _kMax)) : null,
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 44),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colors.background800,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.background700),
            ),
            child: Text(
              formatMvpPoints(value),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.primary500,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Remix.add_line, size: 18),
            color: canIncrease ? colors.primary500 : colors.foreground600,
            onPressed: canIncrease ? () => onChanged((value + _kStep).clamp(0, _kMax)) : null,
          ),
        ],
      ),
    );
  }
}
