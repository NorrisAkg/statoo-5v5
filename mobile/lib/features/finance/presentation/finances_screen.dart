import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_form_dialog.dart';
import '../../../core/widgets/primary_button.dart';
import '../../players/application/players_provider.dart';
import '../../players/domain/player.dart';
import '../../shared/application/shared_providers.dart';
import '../../team/application/team_provider.dart';
import '../application/finance_providers.dart';
import '../domain/financial_point.dart';
import '../domain/financial_report.dart';

final financialPeriodsProvider = FutureProvider<Map<String, FinancialPoint>>((
  ref,
) async {
  ref.watch(financialPointsProvider);
  final group = ref.watch(activeTeamIdProvider);
  if (group == null) return {};
  return await ref.watch(financeRepositoryProvider).periods(group);
});

String _nameKey(String value) {
  var key = value.trim().toLowerCase();
  const accents = {
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'î': 'i',
    'ï': 'i',
    'ô': 'o',
    'ö': 'o',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
    'œ': 'oe',
    'æ': 'ae',
  };
  for (final entry in accents.entries) {
    key = key.replaceAll(entry.key, entry.value);
  }
  return key;
}

String _money(int amount, {bool compact = false, bool signed = false}) {
  final value = compact && amount.abs() >= 10000
      ? NumberFormat.compact(locale: 'fr_FR').format(amount.abs())
      : NumberFormat.decimalPattern('fr_FR').format(amount.abs());
  if (amount < 0) return '−$value';
  if (signed && amount > 0) return '+$value';
  return value;
}

class FinancesScreen extends ConsumerStatefulWidget {
  const FinancesScreen({super.key});
  @override
  ConsumerState<FinancesScreen> createState() => _FinancesScreenState();
}

class _FinancesScreenState extends ConsumerState<FinancesScreen> {
  bool get _largeText => MediaQuery.textScalerOf(context).scale(14) > 20;
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _createPeriod() async {
    final container = ProviderScope.containerOf(context, listen: false);
    final group = container.read(activeTeamIdProvider);
    if (group == null) return;
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
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
            Text(
              'La cotisation concerne tous les membres, même si le match est annulé.',
              style: TextStyle(color: ctx.colors.foreground400, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reference,
              decoration: const InputDecoration(
                labelText: 'Référence commune',
                border: OutlineInputBorder(),
              ),
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
    if (accepted != true || value.isEmpty || !mounted) return;
    try {
      if (group != container.read(activeTeamIdProvider))
        throw StateError('Le groupe actif a changé.');
      final id = await container
          .read(financeRepositoryProvider)
          .createPeriod(
            group,
            DateTime(date.year, date.month, date.day, 20),
            value,
          );
      container.invalidate(financialPointsProvider);
      container.invalidate(financialTotalsProvider);
      if (mounted) unawaited(context.push('/seances/$id/finances'));
    } on Object catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Widget _detailRow(
    BuildContext context,
    String label,
    int value, {
    bool signed = false,
    Color? color,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: context.colors.foreground400, fontSize: 13),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            '${_money(value, signed: signed)} F',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: color ?? context.colors.foreground50,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  Future<void> _memberDetail(
    Player player,
    MemberFinancialPosition position,
    FinancialReport report,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.colors.background950,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                player.name,
                style: TextStyle(
                  color: ctx.colors.foreground50,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Situation au ${DateFormat('d MMM yyyy', 'fr_FR').format(report.asOf)}',
                style: TextStyle(color: ctx.colors.foreground400, fontSize: 12),
              ),
              const SizedBox(height: 20),
              AppCard(
                child: Column(
                  children: [
                    _detailRow(ctx, 'Payé / crédits reportés', position.paid),
                    _detailRow(ctx, 'Total attendu', position.expected),
                    Divider(color: ctx.colors.background700),
                    _detailRow(
                      ctx,
                      'Écart global',
                      position.difference,
                      signed: true,
                    ),
                    _detailRow(
                      ctx,
                      'Reste à régler',
                      position.amountToSettle,
                      color: position.amountToSettle > 0
                          ? ctx.colors.danger
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Cotisations',
                style: TextStyle(
                  color: ctx.colors.foreground50,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              AppCard(
                child: Column(
                  children: [
                    _detailRow(
                      ctx,
                      'Cotisations attendues',
                      position.contributionsExpected,
                    ),
                    _detailRow(
                      ctx,
                      'Cotisations versées',
                      position.contributionsPaid,
                    ),
                    if (position.openingContributionBalance != 0)
                      _detailRow(
                        ctx,
                        'Report initial',
                        position.openingContributionBalance,
                        signed: true,
                      ),
                    Divider(color: ctx.colors.background700),
                    _detailRow(
                      ctx,
                      position.contributionBalance >= 0
                          ? 'Avance disponible'
                          : 'Cotisations impayées',
                      position.contributionBalance >= 0
                          ? position.advance
                          : position.contributionDebt,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Pénalités',
                style: TextStyle(
                  color: ctx.colors.foreground50,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              AppCard(
                child: Column(
                  children: [
                    _detailRow(
                      ctx,
                      'Pénalités attribuées',
                      position.penaltiesExpected,
                    ),
                    if (position.openingPenaltyDebt != 0)
                      _detailRow(
                        ctx,
                        'Dette initiale',
                        position.openingPenaltyDebt,
                      ),
                    _detailRow(ctx, 'Pénalités payées', position.penaltiesPaid),
                    Divider(color: ctx.colors.background700),
                    _detailRow(
                      ctx,
                      'Pénalités impayées',
                      position.penaltyDebt,
                      color: position.penaltyDebt > 0
                          ? ctx.colors.danger
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'L’avance de cotisation ne règle pas les pénalités.',
                style: TextStyle(
                  color: ctx.colors.foreground400,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              if (position.hasOpeningBalance)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Les reports initiaux sont inclus dans Payé ou Attendu. Ils ne sont pas de nouveaux encaissements.',
                    style: TextStyle(
                      color: ctx.colors.foreground400,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              if (!report.isComplete)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Certaines échéances restent à renseigner : ces montants sont provisoires.',
                    style: TextStyle(
                      color: ctx.colors.warning,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _periods(FinancialReport? report) async {
    final group = ref.read(activeTeamIdProvider);
    final writable =
        group != null &&
        ref.read(sharedServiceProvider).canWrite(group, 'finance');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.colors.background950,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(ctx).height * 0.75,
          child: Consumer(
            builder: (sheetContext, sheetRef, _) {
              final periods = sheetRef.watch(financialPeriodsProvider);
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Échéances du groupe',
                            style: TextStyle(
                              color: ctx.colors.foreground50,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Fermer',
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Remix.close_line),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: periods.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, _) => Center(child: Text('$error')),
                      data: (data) {
                        final entries = data.entries.toList()
                          ..sort(
                            (a, b) =>
                                b.value.playedAt.compareTo(a.value.playedAt),
                          );
                        return ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            for (final pending
                                in report?.pendingPeriods ??
                                    <PendingFinancialPeriod>[])
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  DateFormat(
                                    'd MMM yyyy',
                                    'fr_FR',
                                  ).format(pending.date),
                                  style: TextStyle(
                                    color: ctx.colors.foreground50,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  'Point financier à renseigner',
                                  style: TextStyle(
                                    color: ctx.colors.warning,
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: const Icon(Remix.arrow_right_s_line),
                                onTap: () =>
                                    _openPeriod(ctx, pending.sessionId),
                              ),
                            for (final entry in entries)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  DateFormat(
                                    'd MMM yyyy',
                                    'fr_FR',
                                  ).format(entry.value.playedAt),
                                  style: TextStyle(
                                    color: ctx.colors.foreground50,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  entry.value.cancelled
                                      ? 'Annulée · Cotisations dues'
                                      : 'Encaissé ${_money(entry.value.received)} F · Dépensé ${_money(entry.value.spent)} F',
                                  style: TextStyle(
                                    color: ctx.colors.foreground400,
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: const Icon(Remix.arrow_right_s_line),
                                onTap: () => _openPeriod(ctx, entry.key),
                              ),
                            if (entries.isEmpty &&
                                (report?.pendingPeriods.isEmpty ?? true))
                              Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  'Aucune échéance enregistrée.',
                                  style: TextStyle(
                                    color: ctx.colors.foreground400,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  if (writable)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: PrimaryButton(
                        label: 'Nouvelle échéance',
                        icon: Remix.add_line,
                        onPressed: () {
                          Navigator.pop(ctx);
                          unawaited(_createPeriod());
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _openPeriod(BuildContext sheetContext, String id) {
    Navigator.pop(sheetContext);
    unawaited(context.push('/seances/$id/finances'));
  }

  Future<void> _refresh() async {
    final container = ProviderScope.containerOf(context, listen: false);
    final group = container.read(activeTeamIdProvider);
    final shared = container.read(sharedServiceProvider);
    try {
      if (shared.connected && shared.groupId == group)
        await shared.synchronize();
      container.invalidate(financialPointsProvider);
      container.invalidate(playersListProvider);
      container.invalidate(financialReportProvider);
      await container.read(financialReportProvider.future);
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Widget _amountCell(
    int amount,
    String label, {
    bool signed = false,
    Color? color,
  }) => Expanded(
    flex: 2,
    child: Tooltip(
      message: '$label : ${_money(amount, signed: signed)} F',
      child: Semantics(
        label: '$label : ${_money(amount, signed: signed)} F',
        child: Text(
          _money(amount, compact: true, signed: signed),
          textAlign: TextAlign.right,
          maxLines: 1,
          style: TextStyle(
            color: color ?? context.colors.foreground200,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );

  Widget _memberRow(Player player, FinancialReport report) {
    final position =
        report.members[player.id] ?? const MemberFinancialPosition();
    final status = position.penaltyDebt > 0
        ? 'Pénalités impayées : ${_money(position.penaltyDebt)} F'
        : position.contributionDebt > 0
        ? 'Cotisations impayées'
        : !report.isComplete
        ? 'À compléter'
        : position.advance > 0
        ? 'En avance'
        : 'À jour';
    final differenceColor = position.penaltyDebt > 0
        ? context.colors.warning
        : position.difference < 0
        ? context.colors.danger
        : position.difference > 0
        ? context.colors.primary400
        : context.colors.foreground400;
    return InkWell(
      onTap: () => unawaited(_memberDetail(player, position, report)),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        key: ValueKey('member-${player.id}'),
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: _largeText
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.name,
                    style: TextStyle(
                      color: context.colors.foreground50,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status,
                    style: TextStyle(
                      color: position.penaltyDebt > 0
                          ? context.colors.danger
                          : context.colors.foreground400,
                      fontSize: 12,
                    ),
                  ),
                  if (!player.isActive)
                    Text(
                      'Membre archivé',
                      style: TextStyle(
                        color: context.colors.foreground500,
                        fontSize: 12,
                      ),
                    ),
                  const SizedBox(height: 12),
                  _detailRow(context, 'Payé', position.paid),
                  _detailRow(context, 'Attendu', position.expected),
                  _detailRow(
                    context,
                    'Écart',
                    position.difference,
                    signed: true,
                    color: differenceColor,
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          player.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.colors.foreground50,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          status,
                          style: TextStyle(
                            color: position.penaltyDebt > 0
                                ? context.colors.danger
                                : context.colors.foreground400,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                        if (!player.isActive)
                          Text(
                            'Membre archivé',
                            style: TextStyle(
                              color: context.colors.foreground500,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _amountCell(position.paid, 'Payé'),
                  const SizedBox(width: 6),
                  _amountCell(position.expected, 'Attendu'),
                  const SizedBox(width: 6),
                  _amountCell(
                    position.difference,
                    'Écart',
                    signed: true,
                    color: differenceColor,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _content(FinancialReport report, List<Player> players) {
    final members =
        players
            .where(
              (p) =>
                  _nameKey('${p.name} ${p.nickname ?? ''}')
                      .contains(_nameKey(_query)),
            )
            .toList()
          ..sort((a, b) {
            final byName = _nameKey(a.name).compareTo(_nameKey(b.name));
            return byName != 0 ? byName : a.id.compareTo(b.id);
          });
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Remix.wallet_line,
                      color: context.colors.primary400,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Caisse du groupe',
                        style: TextStyle(
                          color: context.colors.foreground200,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${_money(report.cash)} F',
                  style: TextStyle(
                    color: context.colors.foreground50,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Au ${DateFormat('d MMM yyyy', 'fr_FR').format(report.asOf)}',
                  style: TextStyle(
                    color: context.colors.foreground400,
                    fontSize: 12,
                  ),
                ),
                if (report.openingDate != null)
                  Text(
                    'Depuis le ${DateFormat('d MMM yyyy', 'fr_FR').format(report.openingDate!)} · reports initiaux inclus',
                    style: TextStyle(
                      color: context.colors.foreground400,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          if (!report.isComplete) ...[
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bilan à compléter',
                    style: TextStyle(
                      color: context.colors.warning,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${report.pendingPeriods.length} échéance(s) sans point financier. Les montants et statuts affichés sont provisoires.',
                    style: TextStyle(
                      color: context.colors.foreground400,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  TextButton(
                    onPressed: () => unawaited(_periods(report)),
                    child: const Text('Voir les échéances'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Situation des membres',
                  style: TextStyle(
                    color: context.colors.foreground50,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${players.length} membres',
                style: TextStyle(
                  color: context.colors.foreground400,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            onChanged: (value) => setState(() => _query = value),
            style: TextStyle(color: context.colors.foreground50, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Rechercher un membre',
              hintStyle: TextStyle(
                color: context.colors.foreground400,
                fontSize: 13,
              ),
              prefixIcon: Icon(
                Remix.search_line,
                color: context.colors.foreground400,
                size: 20,
              ),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Effacer la recherche',
                      icon: const Icon(Remix.close_line),
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                    ),
              filled: true,
              fillColor: context.colors.background900,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: context.colors.background700),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: context.colors.background700),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: context.colors.primary500,
                  width: 2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Montants en F · touchez un membre pour le détail',
            style: TextStyle(color: context.colors.foreground400, fontSize: 11),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              children: [
                if (!_largeText) ...[
                  Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Text(
                          'Membre',
                          style: TextStyle(
                            color: context.colors.foreground400,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      for (final title in ['Payé', 'Attendu', 'Écart']) ...[
                        Expanded(
                          flex: 2,
                          child: Text(
                            title,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: context.colors.foreground400,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (title != 'Écart') const SizedBox(width: 6),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Divider(color: context.colors.background700, height: 1),
                ],
                if (members.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      players.isEmpty
                          ? 'Aucun membre dans ce groupe.'
                          : 'Aucun membre trouvé.',
                      style: TextStyle(
                        color: context.colors.foreground400,
                        fontSize: 13,
                      ),
                    ),
                  ),
                for (var i = 0; i < members.length; i++) ...[
                  _memberRow(members[i], report),
                  if (i < members.length - 1)
                    Divider(color: context.colors.background700, height: 1),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'L’écart ne compense pas les deux comptes : une avance peut coexister avec des pénalités impayées.',
            style: TextStyle(
              color: context.colors.foreground400,
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(sharedStatusProvider);
    final report = ref.watch(financialReportProvider);
    final players = ref.watch(playersListProvider);
    return Scaffold(
      backgroundColor: context.colors.background950,
      appBar: AppBar(
        title: const Text('Finances du groupe'),
        actions: [
          IconButton(
            tooltip: 'Échéances du groupe',
            icon: const Icon(Remix.calendar_line),
            onPressed: () => unawaited(_periods(report.value)),
          ),
        ],
      ),
      body: report.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (value) => players.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('$error')),
          data: (members) => _content(value, members),
        ),
      ),
    );
  }
}
