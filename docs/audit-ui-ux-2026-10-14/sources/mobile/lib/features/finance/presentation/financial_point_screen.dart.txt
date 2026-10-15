import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_form_dialog.dart';
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
  FinancialPoint? _point;
  String? _error;
  String? _group;
  bool _loaded = false;
  bool _savedBefore = false;
  bool _saving = false;
  bool _cancelled = false;

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
    playedAt: _point!.playedAt,
    rate: _point!.rate,
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
      setState(() => _saving = true);
      await ref
          .read(financeRepositoryProvider)
          .savePoint(_group!, widget.sessionId, point, reason: correction);
      ref.invalidate(financialPointsProvider);
      ref.invalidate(financialTotalsProvider);
      if (mounted) {
        _savedBefore = true;
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
        Text('$value F', style: const TextStyle(fontWeight: FontWeight.bold)),
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
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: const Text('Point financier'),
          bottom: TabBar(
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
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Cotisation : ${_point!.rate} F · ${_point!.playedAt.day}/${_point!.playedAt.month}/${_point!.playedAt.year}',
                          ),
                        ),
                        if (canWrite)
                          TextButton(
                            onPressed: () async {
                              final value = await _askRate();
                              if (value != null && mounted) {
                                setState(
                                  () => _point = FinancialPoint(
                                    playedAt: _point!.playedAt,
                                    rate: value,
                                    lines: _point!.lines,
                                  ),
                                );
                              }
                            },
                            child: const Text('Modifier'),
                          ),
                      ],
                    ),
                  ),
                  if (canWrite)
                    SwitchListTile(
                      title: const Text('Séance annulée'),
                      subtitle: const Text(
                        'Cotisations dues, aucun mouvement de caisse',
                      ),
                      value: _cancelled,
                      onChanged: (value) => setState(() => _cancelled = value),
                    ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _receipts(canWrite && !_cancelled),
                        _expenseList(canWrite && !_cancelled),
                      ],
                    ),
                  ),
                  SafeArea(
                    maintainBottomViewPadding: true,
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _total('Total encaissé', _current().received),
                          _total('Total dépensé', _current().spent),
                          if (canWrite)
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _saving
                                    ? null
                                    : () => unawaited(_save()),
                                child: Text(
                                  _saving
                                      ? 'Enregistrement…'
                                      : 'Valider le point',
                                ),
                              ),
                            ),
                          if (!canWrite) const Text('Consultation uniquement'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<int?> _askRate() async {
    final c = TextEditingController(text: '${_point!.rate}');
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
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Remix.search_line),
                hintText: 'Rechercher un membre',
              ),
            ),
            const SizedBox(height: 12),
            const Text('Saisissez les montants effectivement reçus.'),
            const SizedBox(height: 12),
            const Row(
              children: [
                Expanded(flex: 3, child: Text('Membre')),
                Expanded(flex: 2, child: Text('Cotisation')),
                Expanded(flex: 2, child: Text('Pénalité')),
              ],
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
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: InkWell(
                        onTap: writable
                            ? () => unawaited(_assess(list[i]))
                            : null,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(list[i].name),
                            if ((_due[list[i].id] ?? 0) > 0)
                              Text(
                                'Due : ${_due[list[i].id]} F',
                                style: TextStyle(
                                  color: context.colors.warning,
                                  fontSize: 11,
                                ),
                              ),
                            if (writable)
                              const Text(
                                'Retard / sanction',
                                style: TextStyle(fontSize: 10),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: _moneyField(
                        _contributions[list[i].id]!,
                        writable,
                        'Cotisation de ${list[i].name}',
                        _point!.rate,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 2,
                      child: _moneyField(
                        _penalties[list[i].id]!,
                        writable,
                        'Pénalité payée par ${list[i].name}',
                        ref
                                .watch(financialDefaultsProvider)
                                .value
                                ?.latePenalty ??
                            0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            for (final movement in _donations)
              ListTile(
                title: Text(movement.label),
                subtitle: Text('${movement.amount} F'),
                trailing: writable
                    ? IconButton(
                        tooltip: 'Retirer la recette',
                        icon: const Icon(Remix.close_line),
                        onPressed: () =>
                            setState(() => _donations.remove(movement)),
                      )
                    : null,
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

  Widget _moneyField(
    TextEditingController controller,
    bool writable,
    String label,
    int defaultAmount,
  ) => Semantics(
    label: label,
    child: TextField(
      controller: controller,
      enabled: writable,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(12),
      ],
      decoration: InputDecoration(
        hintText: '$defaultAmount',
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) => setState(() {}),
    ),
  );

  Widget _expenseList(bool writable) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const Text('Les dépenses sont prises dans la caisse.'),
      for (final movement in _expenses)
        Card(
          child: ListTile(
            title: Text(movement.label),
            subtitle: Text('${movement.amount} F'),
            trailing: writable
                ? IconButton(
                    tooltip: 'Retirer la dépense',
                    icon: const Icon(Remix.close_line),
                    onPressed: () => setState(() => _expenses.remove(movement)),
                  )
                : null,
          ),
        ),
      if (writable)
        OutlinedButton.icon(
          onPressed: () => unawaited(_addMovement(false)),
          icon: const Icon(Remix.add_line),
          label: const Text('Ajouter une dépense'),
        ),
    ],
  );
}
