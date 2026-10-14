import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/widgets/app_form_dialog.dart';

import '../../players/application/players_provider.dart';
import '../../shared/application/shared_providers.dart';
import '../../team/application/team_provider.dart';
import '../application/finance_providers.dart';
import '../domain/financial_point.dart';

final financialPeriodsProvider = FutureProvider<Map<String, FinancialPoint>>((
  ref,
) async {
  ref.watch(financialPointsProvider);
  final group = ref.watch(activeTeamIdProvider);
  if (group == null) return {};
  return await ref.watch(financeRepositoryProvider).periods(group);
});

class FinancesScreen extends ConsumerWidget {
  const FinancesScreen({super.key});
  Future<void> _createPeriod(BuildContext context, WidgetRef ref) async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: DateTime.now(),
    );
    if (date == null || !context.mounted) return;
    final reference = TextEditingController(
      text: '${date.toIso8601String().substring(0, 10)}-1',
    );
    final accepted = await showAppFormDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ajouter une échéance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'La cotisation concerne tous les membres, même si le match est annulé. Utilisez la même référence que la séance sportive.',
            ),
            TextField(
              controller: reference,
              decoration: const InputDecoration(labelText: 'Référence commune'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Créer'),
          ),
        ],
      ),
    );
    final value = reference.text.trim();
    reference.dispose();
    if (accepted != true || value.isEmpty || !context.mounted) return;
    try {
      final group = ref.read(activeTeamIdProvider);
      if (group == null) throw StateError('Aucun groupe.');
      final id = await ref
          .read(financeRepositoryProvider)
          .createPeriod(
            group,
            DateTime(date.year, date.month, date.day, 20),
            value,
          );
      ref.invalidate(financialPointsProvider);
      ref.invalidate(financialTotalsProvider);
      if (context.mounted) unawaited(context.push('/seances/$id/finances'));
    } on Object catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(sharedStatusProvider);
    final totals = ref.watch(financialTotalsProvider);
    final players = ref.watch(playersListProvider).value ?? [];
    final periods = ref.watch(financialPeriodsProvider).value ?? {};
    final group = ref.watch(activeTeamIdProvider);
    final writable = ref
        .watch(sharedServiceProvider)
        .canWrite(group, 'finance');
    return Scaffold(
      appBar: AppBar(title: const Text('Finances du groupe')),
      floatingActionButton: writable
          ? FloatingActionButton.extended(
              onPressed: () => unawaited(_createPeriod(context, ref)),
              icon: const Icon(Remix.add_line),
              label: const Text('Échéance'),
            )
          : null,
      body: totals.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (value) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            Card(
              child: ListTile(
                title: const Text('Caisse disponible'),
                subtitle: Text(
                  '${value.cash} F',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const Text(
              'Les cotisations dues sont distinctes des encaissements. Une avance ne paie pas les pénalités.',
            ),
            const SizedBox(height: 16),
            const Text(
              'Situation des membres',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            for (final player in players)
              ListTile(
                title: Text(player.name),
                subtitle: Text(
                  'Cotisations : ${value.members[player.id]?.contributionDebt ?? 0} F dus · ${value.members[player.id]?.advance ?? 0} F d’avance\n'
                  'Pénalités : ${value.members[player.id]?.penaltyDebt ?? 0} F dues',
                ),
              ),
            const Divider(),
            const Text(
              'Échéances et points par séance',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            for (final entry in periods.entries)
              ListTile(
                title: Text(
                  '${entry.value.playedAt.day}/${entry.value.playedAt.month}/${entry.value.playedAt.year}',
                ),
                subtitle: Text(
                  entry.value.cancelled
                      ? 'Annulée · Cotisations dues'
                      : 'Encaissé ${entry.value.received} F · Dépensé ${entry.value.spent} F',
                ),
                trailing: const Icon(Remix.arrow_right_s_line),
                onTap: () => context.push('/seances/${entry.key}/finances'),
              ),
          ],
        ),
      ),
    );
  }
}
