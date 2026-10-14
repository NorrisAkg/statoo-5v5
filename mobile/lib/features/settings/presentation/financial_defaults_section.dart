import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_form_dialog.dart';
import '../../finance/application/finance_providers.dart';
import '../../finance/domain/financial_defaults.dart';
import '../../shared/application/shared_providers.dart';
import '../../team/application/team_provider.dart';

class FinancialDefaultsSection extends ConsumerWidget {
  const FinancialDefaultsSection({super.key});

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    FinancialDefaults value, {
    required bool contribution,
  }) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final group = ref.read(activeTeamIdProvider);
    if (group == null) return;
    final controller = TextEditingController(
      text: '${contribution ? value.contribution : value.latePenalty}',
    );
    final formKey = GlobalKey<FormState>();
    final accepted = await showAppFormDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          contribution ? 'Cotisation par séance' : 'Pénalité de retard',
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                contribution
                    ? 'Montant dû par chaque membre pour les nouvelles séances.'
                    : 'Montant suggéré pour un retard.',
                style: TextStyle(color: ctx.colors.foreground400, fontSize: 13),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(13),
                ],
                style: TextStyle(
                  color: ctx.colors.foreground50,
                  fontWeight: FontWeight.w600,
                ),
                decoration: const InputDecoration(
                  labelText: 'Montant',
                  suffixText: 'F',
                  border: OutlineInputBorder(),
                ),
                validator: (text) {
                  final amount = int.tryParse(text ?? '');
                  if (amount == null) return 'Renseignez un montant.';
                  if (amount > 1000000000000)
                    return 'Le montant est trop élevé.';
                  return null;
                },
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
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    final amount = int.tryParse(controller.text);
    controller.dispose();
    if (accepted != true || !context.mounted) return;
    try {
      if (group != ref.read(activeTeamIdProvider)) {
        throw StateError('Le groupe actif a changé.');
      }
      if (amount == null) return;
      final repo = ref.read(financeRepositoryProvider);
      final current = await repo.getDefaults(group);
      await repo.saveDefaults(
        group,
        FinancialDefaults(
          contribution: contribution ? amount : current.contribution,
          latePenalty: contribution ? current.latePenalty : amount,
        ),
      );
      container.invalidate(financialDefaultsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Montant du groupe enregistré.')),
        );
      }
    } on Object catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Widget _row(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required int amount,
    VoidCallback? onTap,
  }) => ListTile(
    contentPadding: EdgeInsets.zero,
    minLeadingWidth: 22,
    horizontalTitleGap: 12,
    leading: Icon(icon, color: context.colors.primary500, size: 22),
    title: Text(
      title,
      style: TextStyle(
        color: context.colors.foreground50,
        fontWeight: FontWeight.w600,
        fontSize: 15,
      ),
    ),
    subtitle: Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        subtitle,
        style: TextStyle(color: context.colors.foreground400, fontSize: 12),
      ),
    ),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$amount F',
          style: TextStyle(
            color: context.colors.foreground200,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        if (onTap != null) ...[
          const SizedBox(width: 8),
          Icon(
            Remix.arrow_right_s_line,
            color: context.colors.foreground500,
            size: 18,
          ),
        ],
      ],
    ),
    onTap: onTap,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final defaults = ref.watch(financialDefaultsProvider);
    ref.watch(sharedStatusProvider);
    final editable = ref
        .watch(sharedServiceProvider)
        .canWrite(ref.watch(activeTeamIdProvider), 'finance_settings');
    return defaults.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('$e'),
      data: (value) => Column(
        children: [
          _row(
            context,
            icon: Remix.wallet_line,
            title: 'Cotisation par séance',
            subtitle: 'Due par chaque membre',
            amount: value.contribution,
            onTap: editable
                ? () => _edit(context, ref, value, contribution: true)
                : null,
          ),
          Divider(color: context.colors.background700, height: 1),
          _row(
            context,
            icon: Remix.time_line,
            title: 'Pénalité de retard',
            subtitle: 'Montant en cas de retard',
            amount: value.latePenalty,
            onTap: editable
                ? () => _edit(context, ref, value, contribution: false)
                : null,
          ),
        ],
      ),
    );
  }
}
