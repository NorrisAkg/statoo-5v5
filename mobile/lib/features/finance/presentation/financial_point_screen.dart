import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_form_dialog.dart';
import '../../../core/widgets/initial_avatar.dart';
import '../../../core/widgets/primary_button.dart';
import '../../players/application/players_provider.dart';
import '../../players/domain/player.dart';
import '../../sessions/application/sessions_provider.dart';
import '../../shared/application/shared_providers.dart';
import '../../team/application/team_provider.dart';
import '../application/finance_providers.dart';
import '../domain/financial_point.dart';

class FinancialPointScreen extends ConsumerStatefulWidget {
  const FinancialPointScreen({required this.sessionId, super.key});
  final String sessionId;
  @override
  ConsumerState<FinancialPointScreen> createState() =>
      _FinancialPointScreenState();
}

class _FinancialPointScreenState extends ConsumerState<FinancialPointScreen> {
  final Map<String, TextEditingController> _contributions = {};
  final Map<String, TextEditingController> _penalties = {};
  final Map<String, int> _due = {};
  final Map<String, String> _reasons = {};
  final List<FinancialMovement> _expenses = [];
  final List<FinancialMovement> _donations = [];
  final _search = TextEditingController();
  late FinancialPoint _point;
  String? _error;
  String? _group;
  bool _loaded = false;
  bool _savedBefore = false;
  bool _prefilled = false;
  final _untouchedPrefills = <String>{};
  bool _saving = false;
  bool _cancelled = false;
  String? _baseline;
  bool _allowExit = false;
  bool _exitDialog = false;
  bool get _largeText => MediaQuery.textScalerOf(context).scale(14) > 20;

  String _fingerprint() => jsonEncode({
    'point': _current().toJson(),
    'invalid': {
      for (final entry in {
        ..._contributions.map((k, v) => MapEntry('c$k', v)),
        ..._penalties.map((k, v) => MapEntry('p$k', v)),
      }.entries)
        if (entry.value.text.isNotEmpty &&
            int.tryParse(entry.value.text) == null)
          entry.key: entry.value.text,
    },
  });
  bool get _dirty => _loaded && _baseline != _fingerprint();

  Future<void> _confirmExit() async {
    if (_saving || _exitDialog) return;
    _exitDialog = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitter sans enregistrer ?'),
        content: const Text(
          'Les modifications de ce point ne sont pas enregistrées. Vous pouvez continuer la saisie ou les abandonner.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Continuer la saisie'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Abandonner les modifications'),
          ),
        ],
      ),
    );
    _exitDialog = false;
    if (discard != true || !mounted) return;
    setState(() => _allowExit = true);
    // Laisser PopScope publier la nouvelle autorisation avant le pop.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final group = ref.read(activeTeamIdProvider);
      if (group == null) throw StateError('Aucun groupe sélectionné.');
      _group = group;
      final session = await ref.read(
        sessionDetailProvider(widget.sessionId).future,
      );
      final repo = ref.read(financeRepositoryProvider);
      final storedPoint = await repo.getPoint(group, widget.sessionId);
      if (session == null && storedPoint == null) {
        throw StateError('Séance ou échéance introuvable.');
      }
      _savedBefore = await repo.isValidated(group, widget.sessionId);
      final point = await repo.prepare(
        group,
        widget.sessionId,
        session?.playedAt ?? storedPoint!.playedAt,
      );
      if (!mounted) return;
      _point = point;
      _cancelled = point.cancelled;
      for (final line in point.lines) {
        _contributions[line.memberId] = TextEditingController(
          text: line.contribution == 0 ? '' : '${line.contribution}',
        );
        _penalties[line.memberId] = TextEditingController(
          text: line.penaltyPaid == 0 ? '' : '${line.penaltyPaid}',
        );
        _due[line.memberId] = line.penaltyDue;
        _reasons[line.memberId] = line.reason;
      }
      _expenses.addAll(point.expenses);
      _donations.addAll(point.donations);
      _baseline = _fingerprint();
      if (!_savedBefore &&
          !point.cancelled &&
          point.rate > 0 &&
          ref.read(sharedServiceProvider).canWrite(group, 'finance')) {
        for (final line in point.lines) {
          if (line.contribution == 0) {
            _contributions[line.memberId]!.text = '${point.rate}';
            _untouchedPrefills.add(line.memberId);
            var previousText = _contributions[line.memberId]!.text;
            _contributions[line.memberId]!.addListener(() {
              final text = _contributions[line.memberId]!.text;
              if (text != previousText) {
                _untouchedPrefills.remove(line.memberId);
                previousText = text;
              }
            });
            _prefilled = true;
          }
        }
      }
      setState(() => _loaded = true);
    } on Object catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  @override
  void dispose() {
    for (final controller in [
      ..._contributions.values,
      ..._penalties.values,
      _search,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  int _amount(TextEditingController c) => int.tryParse(c.text) ?? 0;
  FinancialPoint _current() => FinancialPoint(
    playedAt: _point.playedAt,
    rate: _point.rate,
    cancelled: _cancelled,
    lines: [
      for (final id in _contributions.keys)
        FinancialLine(
          memberId: id,
          contribution: _amount(_contributions[id]!),
          penaltyPaid: _amount(_penalties[id]!),
          penaltyDue: _due[id] ?? 0,
          reason: _reasons[id] ?? '',
        ),
    ],
    expenses: List.of(_expenses),
    donations: List.of(_donations),
  );

  Future<void> _save() async {
    if (_saving) return;
    if (ref.read(activeTeamIdProvider) != _group) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Le groupe actif a changé. Rouvrez ce point financier.',
          ),
        ),
      );
      return;
    }
    final point = _current();
    setState(() => _saving = true);
    try {
      point.validate();
      final reason = TextEditingController();
      final confirm = await showAppFormDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Valider le point financier ?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _total('Cotisations reçues', point.contributions),
                _total('Pénalités reçues', point.penaltiesReceived),
                _total('Autres recettes', point.donationsReceived),
                const Divider(),
                _total('Total encaissé', point.received),
                _total('Dépenses', point.spent),
                _total('Variation de caisse', point.cashChange),
                if (_cancelled)
                  const Text('Séance annulée : les cotisations restent dues.'),
                if (_savedBefore)
                  TextField(
                    controller: reason,
                    decoration: const InputDecoration(
                      labelText: 'Motif de correction (obligatoire)',
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Revenir'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmer'),
            ),
          ],
        ),
      );
      final correction = reason.text.trim();
      reason.dispose();
      if (confirm != true || !mounted) return;
      await ref
          .read(financeRepositoryProvider)
          .savePoint(_group!, widget.sessionId, point, reason: correction);
      ref
        ..invalidate(financialPointsProvider)
        ..invalidate(financialTotalsProvider);
      if (mounted) {
        _savedBefore = true;
        _baseline = jsonEncode({
          'point': point.toJson(),
          'invalid': <String, String>{},
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Point enregistré sur ce téléphone.')),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _total(String label, int value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            '${_money(value)} F',
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  Future<void> _addMovement(bool donation) async {
    final label = TextEditingController();
    final amount = TextEditingController();
    final accepted = await showAppFormDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          donation ? 'Autre encaissement / don' : 'Ajouter une dépense',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: label,
              decoration: const InputDecoration(labelText: 'Motif'),
            ),
            TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Montant reçu / dépensé (F)',
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
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
    final text = label.text.trim();
    final value = int.tryParse(amount.text);
    label.dispose();
    amount.dispose();
    if (accepted == true &&
        text.isNotEmpty &&
        value != null &&
        value > 0 &&
        mounted) {
      setState(
        () => (donation ? _donations : _expenses).add(
          FinancialMovement(
            id: ref.read(sharedServiceProvider).operationId(),
            label: text,
            amount: value,
          ),
        ),
      );
    }
  }

  Future<void> _assess(Player player) async {
    final amount = TextEditingController(text: '${_due[player.id] ?? 0}');
    final reason = TextEditingController(text: _reasons[player.id] ?? '');
    final accepted = await showAppFormDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Pénalité due · ${player.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Montant dû, même si le membre ne paie pas aujourd’hui. Aucune avance de cotisation ne le couvre.',
            ),
            TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Pénalité / sanction due (F)',
              ),
            ),
            TextField(
              controller: reason,
              decoration: const InputDecoration(
                labelText: 'Motif : retard, sanction…',
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
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    final value = int.tryParse(amount.text) ?? 0;
    final text = reason.text.trim();
    amount.dispose();
    reason.dispose();
    if (accepted == true && mounted) {
      setState(() {
        _due[player.id] = value;
        _reasons[player.id] = text;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(sharedStatusProvider);
    final shared = ref.watch(sharedServiceProvider);
    final canWrite = shared.canWrite(_group, 'finance');
    return DefaultTabController(
      length: 2,
      child: PopScope(
        canPop: _allowExit || (!_dirty && !_saving),
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) unawaited(_confirmExit());
        },
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            title: const Text('Point financier'),
            bottom: TabBar(
              isScrollable: _largeText,
              tabAlignment: _largeText ? TabAlignment.start : TabAlignment.fill,
              labelColor: context.colors.onHeader,
              unselectedLabelColor: context.colors.onHeader,
              tabs: const [
                Tab(text: 'Encaissements'),
                Tab(text: 'Dépenses'),
              ],
            ),
          ),
          body: _error != null
              ? Center(child: Text(_error!))
              : !_loaded
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(
                      child: TabBarView(
                        children: [
                          _receipts(canWrite && !_cancelled),
                          _expenseList(canWrite && !_cancelled),
                        ],
                      ),
                    ),
                    if (MediaQuery.viewInsetsOf(context).bottom == 0)
                      SafeArea(
                        maintainBottomViewPadding: true,
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              if (!_largeText)
                                Wrap(
                                  spacing: 24,
                                  runSpacing: 8,
                                  children: [
                                    _summary(
                                      'Total encaissé',
                                      _current().received,
                                      context.colors.primary500,
                                    ),
                                    _summary(
                                      'Total dépensé',
                                      _current().spent,
                                      context.colors.foreground50,
                                    ),
                                  ],
                                ),
                              if (!_largeText) const SizedBox(height: 12),
                              if (canWrite)
                                SizedBox(
                                  width: double.infinity,
                                  child: PrimaryButton(
                                    onPressed: _saving
                                        ? null
                                        : () => unawaited(_save()),
                                    icon: Remix.checkbox_circle_line,
                                    label: _saving
                                        ? 'Enregistrement…'
                                        : 'Valider le point',
                                  ),
                                ),
                              if (!canWrite)
                                const Text('Consultation uniquement'),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  String _money(int value) =>
      NumberFormat.decimalPattern('fr_FR').format(value);

  Widget _summary(String label, int value, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label,
        style: TextStyle(color: context.colors.foreground400, fontSize: 12),
      ),
      Text(
        '${_money(value)} F',
        style: TextStyle(
          color: color,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );

  InputDecoration _fieldDecoration({
    String? hint,
    String? suffix,
    Widget? icon,
  }) => InputDecoration(
    hintText: hint,
    suffixText: suffix,
    prefixIcon: icon,
    filled: true,
    fillColor: context.colors.background800,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
      borderSide: BorderSide(color: context.colors.primary500, width: 2),
    ),
  );

  Widget _overview(bool canWrite) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat(
              "EEE d MMM yyyy · HH'h'mm",
              'fr_FR',
            ).format(_point.playedAt),
            style: TextStyle(color: context.colors.foreground400, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 8,
            children: [
              Text(
                'Cotisation : ${_money(_point.rate)} F',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (canWrite)
                TextButton.icon(
                  icon: const Icon(Remix.edit_line, size: 18),
                  label: const Text('Modifier'),
                  onPressed: () async {
                    final value = await _askRate();
                    if (value != null && mounted) {
                      setState(
                        () => _point = FinancialPoint(
                          playedAt: _point.playedAt,
                          rate: value,
                          lines: _point.lines,
                        ),
                      );
                    }
                  },
                ),
            ],
          ),
          if (canWrite) ...[
            Divider(color: context.colors.background700, height: 24),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Séance annulée'),
              subtitle: Text(
                'Cotisations dues, aucun mouvement de caisse',
                style: TextStyle(
                  color: context.colors.foreground400,
                  fontSize: 12,
                ),
              ),
              activeTrackColor: context.colors.primary500,
              value: _cancelled,
              onChanged: (value) => setState(() {
                if (value) {
                  for (final id in _untouchedPrefills.toList()) {
                    _contributions[id]!.clear();
                  }
                }
                _cancelled = value;
              }),
            ),
          ] else if (_cancelled)
            const Text('Séance annulée · les cotisations restent dues.'),
          if (_largeText) ...[
            Divider(color: context.colors.background700, height: 24),
            _total('Total encaissé', _current().received),
            _total('Total dépensé', _current().spent),
          ],
        ],
      ),
    ),
  );

  Future<int?> _askRate() async {
    final c = TextEditingController(text: '${_point.rate}');
    final value = await showAppFormDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cotisation de cette séance'),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(c.text)),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    c.dispose();
    return value;
  }

  Widget _receipts(bool writable) {
    final players = ref.watch(playersListProvider);
    final participants =
        ref.watch(sessionParticipantsProvider(widget.sessionId)).value ?? [];
    final presentIds = participants
        .map((p) => p.participation.playerId)
        .toSet();
    return players.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (all) {
        final list =
            all
                .where(
                  (p) =>
                      _contributions.containsKey(p.id) &&
                      '${p.name} ${p.nickname ?? ''}'.toLowerCase().contains(
                        _search.text.toLowerCase(),
                      ),
                )
                .toList()
              ..sort((a, b) {
                final presence =
                    (presentIds.contains(b.id) ? 1 : 0) -
                    (presentIds.contains(a.id) ? 1 : 0);
                return presence != 0 ? presence : a.name.compareTo(b.name);
              });
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _overview(
              ref.read(sharedServiceProvider).canWrite(_group, 'finance'),
            ),
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: _fieldDecoration(
                hint: 'Rechercher un membre',
                icon: const Icon(Remix.search_line),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Saisissez les montants effectivement reçus.'),
            if (_prefilled && !_savedBefore)
              const Text(
                'Cotisations préremplies au tarif. Effacez les montants des impayés avant de valider.',
              ),
            const SizedBox(height: 12),
            if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('Aucun membre trouvé'),
              ),
            for (var i = 0; i < list.length; i++) ...[
              if (i == 0 ||
                  presentIds.contains(list[i].id) !=
                      presentIds.contains(list[i - 1].id))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    presentIds.contains(list[i].id)
                        ? 'Participants'
                        : 'Absents',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _memberCard(list[i], writable),
              ),
            ],
            for (final movement in _donations)
              AppCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(movement.label),
                  subtitle: Text('${_money(movement.amount)} F'),
                  trailing: writable
                      ? IconButton(
                          tooltip: 'Retirer la recette',
                          icon: const Icon(Remix.close_line),
                          onPressed: () =>
                              setState(() => _donations.remove(movement)),
                        )
                      : null,
                ),
              ),
            if (writable)
              TextButton.icon(
                onPressed: () => unawaited(_addMovement(true)),
                icon: const Icon(Remix.add_line),
                label: const Text('Autre encaissement / don'),
              ),
          ],
        );
      },
    );
  }

  Widget _memberCard(Player player, bool writable) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InitialAvatar(
              initial: player.name.isEmpty ? '?' : player.name.substring(0, 1),
              baseColor: InitialAvatar.colorForName(player.name),
              size: 40,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                player.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final fields = [
              _moneyField(
                _contributions[player.id]!,
                writable,
                'Cotisation de ${player.name}',
                _point.rate,
                'Cotisation reçue',
              ),
              _moneyField(
                _penalties[player.id]!,
                writable,
                'Pénalité payée par ${player.name}',
                ref.watch(financialDefaultsProvider).value?.latePenalty ?? 0,
                'Pénalité reçue',
              ),
            ];
            if (constraints.maxWidth < 300 ||
                MediaQuery.textScalerOf(context).scale(14) > 20) {
              return Column(
                children: [
                  fields.first,
                  const SizedBox(height: 16),
                  fields.last,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: fields.first),
                const SizedBox(width: 12),
                Expanded(child: fields.last),
              ],
            );
          },
        ),
        if ((_due[player.id] ?? 0) > 0)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Pénalité due : ${_money(_due[player.id]!)} F',
              style: TextStyle(color: context.colors.warning, fontSize: 13),
            ),
          ),
        if (writable)
          TextButton.icon(
            onPressed: () => unawaited(_assess(player)),
            icon: const Icon(Remix.time_line, size: 18),
            label: const Text('Retard / sanction'),
          ),
      ],
    ),
  );

  Widget _moneyField(
    TextEditingController controller,
    bool writable,
    String label,
    int defaultAmount,
    String visibleLabel,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        visibleLabel,
        style: TextStyle(color: context.colors.foreground400, fontSize: 13),
      ),
      const SizedBox(height: 8),
      Semantics(
        label: label,
        child: TextField(
          controller: controller,
          enabled: writable,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(12),
          ],
          decoration: _fieldDecoration(hint: '$defaultAmount', suffix: 'F'),
          onChanged: (_) => setState(() {}),
        ),
      ),
    ],
  );

  Widget _expenseList(bool writable) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _overview(ref.read(sharedServiceProvider).canWrite(_group, 'finance')),
      const Text('Les dépenses sont prises dans la caisse.'),
      const SizedBox(height: 16),
      if (_expenses.isEmpty)
        AppCard(
          child: Column(
            children: [
              Icon(
                Remix.wallet_3_line,
                size: 32,
                color: context.colors.foreground400,
              ),
              const SizedBox(height: 12),
              const Text(
                'Aucune dépense',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Les sorties de caisse de cette séance apparaîtront ici.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.colors.foreground400,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      for (final movement in _expenses)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(movement.label),
              subtitle: Text('${_money(movement.amount)} F'),
              trailing: writable
                  ? IconButton(
                      tooltip: 'Retirer la dépense',
                      icon: const Icon(Remix.close_line),
                      onPressed: () =>
                          setState(() => _expenses.remove(movement)),
                    )
                  : null,
            ),
          ),
        ),
      const SizedBox(height: 16),
      if (writable)
        OutlinedButton.icon(
          onPressed: () => unawaited(_addMovement(false)),
          icon: const Icon(Remix.add_line),
          label: const Text('Ajouter une dépense'),
        ),
    ],
  );
}
