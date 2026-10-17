import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/data/app_database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_form_dialog.dart';
import '../../../core/widgets/primary_button.dart';
import '../../finance/application/finance_providers.dart';
import '../../players/application/players_provider.dart';
import '../../sessions/application/sessions_provider.dart';
import '../../team/application/team_provider.dart';
import '../application/shared_providers.dart';
import 'decision_details.dart';

const roleLabels = <String, String>{
  'ADMIN': 'Admin',
  'PDT': 'Président',
  'VP': 'Vice-président',
  'TR': 'Trésorier',
  'TGA': 'Trésorier-adjoint',
  'SG': 'Secrétaire général',
  'SGA': 'Secrétaire général adjoint',
  'CENSOR': 'Censeur',
  'MEMBER': 'Membre',
};

class SharedGroupScreen extends ConsumerStatefulWidget {
  const SharedGroupScreen({super.key});
  @override
  ConsumerState<SharedGroupScreen> createState() => _SharedGroupScreenState();
}

class _SharedGroupScreenState extends ConsumerState<SharedGroupScreen> {
  bool _decisionOpen = false;
  static const _apiUrl = String.fromEnvironment(
    'STATOO_API',
    defaultValue: 'https://statoo-api.onrender.com',
  );
  final _group = TextEditingController();
  final _user = TextEditingController();
  final _password = TextEditingController();
  final _sharedUser = TextEditingController(text: 'membres');
  final _sharedPassword = TextEditingController();
  bool _create = false;
  bool _busy = false;
  bool _failed = false;
  final Set<TextEditingController> _shownPasswords = {};
  String? _message;

  @override
  void dispose() {
    for (final c in [
      _group,
      _user,
      _password,
      _sharedUser,
      _sharedPassword,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _perform(Future<void> Function() operation) async {
    if (!mounted || _busy) return;
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() {
      _busy = true;
      _message = null;
      _failed = false;
    });
    try {
      await operation();
      container.read(sharedStatusProvider.notifier).refresh();
      container
        ..invalidate(allSessionsProvider)
        ..invalidate(playersListProvider)
        ..invalidate(financialPointsProvider)
        ..invalidate(financialTotalsProvider);
      if (mounted) setState(() => _message = 'Données mises à jour.');
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _failed = true;
          _message = '$e';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connect() async {
    final container = ProviderScope.containerOf(context, listen: false);
    final service = container.read(sharedServiceProvider);
    const url = _apiUrl;
    final username = _user.text.trim();
    final password = _password.text;
    final sharedUsername = _sharedUser.text.trim();
    final sharedPassword = _sharedPassword.text;
    final targetGroup = _group.text.trim();
    final group = container.read(activeTeamIdProvider);
    Map<String, dynamic>? registration;
    if (_create) {
      if (group == null) throw StateError('Créez d’abord votre groupe local.');
      final db = await AppDatabase.instance.database;
      final info = (await db.query(
        'teams',
        where: 'id = ?',
        whereArgs: [group],
      )).single;
      final members = await db.query(
        'players',
        where: 'team_id = ?',
        whereArgs: [group],
      );
      final shortNames = await db.query('meta', where: 'key = ?', whereArgs: ['team_short_name_$group']);
      registration = {
        'group_id': group,
        'name': info['name'],
        'short_name': shortNames.isEmpty ? '' : shortNames.single['value'],
        'username': username,
        'password': password,
        'shared_username': sharedUsername,
        'shared_password': sharedPassword,
        'members': members,
      };
    }
    await service.connect(
      url,
      _create ? group! : targetGroup,
      username,
      password,
      registration: registration,
    );
    await container
        .read(activeTeamIdProvider.notifier)
        .selectTeam(service.groupId!);
    await container.read(hasTeamProvider.notifier).reloadFromDb();
    container
      ..invalidate(teamInfoProvider)
      ..invalidate(allTeamsProvider);
  }

  Future<void> _addAccount() async {
    final name = TextEditingController();
    final password = TextEditingController();
    String? member;
    final roles = <String>{};
    final players = ref.read(playersListProvider).value ?? [];
    final result = await showAppFormDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => _dialog(
          ctx,
          title: const Text('Compte individuel et rôles'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: member,
                    decoration: const InputDecoration(labelText: 'Membre'),
                    items: players
                        .map(
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => update(() => member = value),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Identifiant'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Mot de passe (8 caractères minimum)',
                    ),
                  ),
                  for (final entry in roleLabels.entries.where(
                    (e) => e.key != 'ADMIN' && e.key != 'MEMBER',
                  ))
                    CheckboxListTile(
                      title: Text(entry.value),
                      value: roles.contains(entry.key),
                      onChanged: (value) => update(() {
                        if (value == true) {
                          roles.add(entry.key);
                        } else {
                          roles.remove(entry.key);
                        }
                      }),
                    ),
                  const SizedBox(height: 8),
                  const Text('Sélectionnez au moins un rôle de responsable.'),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: member == null || roles.isEmpty
                  ? null
                  : () => Navigator.pop(ctx, true),
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
    final wire = {
      'username': name.text.trim(),
      'password': password.text,
      'member_id': member,
      'roles': roles.toList(),
    };
    name.dispose();
    password.dispose();
    if (result == true && member != null && roles.isNotEmpty) {
      await _perform(() async {
        final service = ref.read(sharedServiceProvider);
        await service.request(
          'POST',
          '/groups/${service.groupId}/accounts',
          wire,
        );
        await service.synchronize();
      });
    }
  }

  Future<void> _approveOpening() async {
    if (_busy || _decisionOpen) return;
    _decisionOpen = true;
    try {
      final service = ref.read(sharedServiceProvider);
      final raw = service.snapshot?['opening_proposal'];
      if (raw is! Map || raw['cash'] is! int || raw['members'] is! Map) {
        throw const FormatException(
          'Proposition incomplète. Actualisez les données avant approbation.',
        );
      }
      // Copie profonde : une synchronisation ne doit pas changer la proposition
      // envoyée pendant que l'utilisateur consulte le récapitulatif.
      final proposal = jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
      final members = proposal['members'] as Map<String, dynamic>;
      for (final balance in members.values) {
        if (balance is! Map ||
            balance['contribution_balance'] is! int ||
            balance['penalty_debt'] is! int) {
          throw const FormatException(
            'Soldes incomplets. Actualisez avant approbation.',
          );
        }
      }
      final names = {
        for (final m
            in (service.snapshot?['members'] as List? ?? [])
                .whereType<Map<String, dynamic>>())
          '${m['id']}': '${m['name']}',
      };
      final leaders = {
        for (final account
            in (service.snapshot?['leaders'] as List? ?? [])
                .whereType<Map<String, dynamic>>())
          '${account['id']}': '${account['username']}',
      };
      final proposals = (service.snapshot?['audit'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .where((e) => e['action'] == 'opening_proposed')
          .toList();
      final proposed = proposals.isEmpty ? null : proposals.last;
      final confirmed = await showAppFormDialog<bool>(
        context: context,
        builder: (ctx) => _dialog(
          ctx,
          title: const Text('Vérifier les soldes initiaux'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Caisse de départ : ${decisionAmount(proposal['cash'])}',
                  ),
                  Text(
                    'Date de départ : ${proposal['start_date'] ?? 'Non renseignée'}',
                  ),
                  Text(
                    'Proposé par : ${leaders['${proposed?['actor']}'] ?? proposed?['actor'] ?? 'Non renseigné'}',
                  ),
                  Text(
                    'Date de proposition : ${decisionDate(proposed?['at'])}',
                  ),
                  const SizedBox(height: 12),
                  if (members.isEmpty)
                    const Text('Aucun solde individuel renseigné.'),
                  for (final entry in members.entries) ...[
                    Text(
                      '${names[entry.key] ?? 'Membre inconnu'} (${entry.key})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Cotisations : ${((entry.value as Map<String, dynamic>)['contribution_balance'] as int) > 0
                          ? 'avance'
                          : ((entry.value as Map<String, dynamic>)['contribution_balance'] as int) < 0
                          ? 'dette'
                          : 'solde nul'} ${decisionAmount(((entry.value as Map<String, dynamic>)['contribution_balance'] as int).abs())}',
                    ),
                    Text(
                      'Pénalités : dette ${decisionAmount((entry.value as Map<String, dynamic>)['penalty_debt'])}',
                    ),
                    const SizedBox(height: 10),
                  ],
                  const Text(
                    'Confirmer initialise la caisse et les soldes du groupe avec ces valeurs.',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Revenir'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmer les soldes'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await _perform(() async {
        await service.request(
          'POST',
          '/groups/${service.groupId}/opening/approve',
          {'proposal': proposal},
        );
        try {
          await service.synchronize();
        } on Object {
          throw StateError(
            'Soldes approuvés. Actualisation impossible : synchronisez pour afficher le nouvel état.',
          );
        }
      });
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _failed = true;
          _message = '$error';
        });
      }
    } finally {
      _decisionOpen = false;
    }
  }

  Future<void> _arbitrate(Map<String, dynamic> document) async {
    if (_busy || _decisionOpen) return;
    _decisionOpen = true;
    try {
      await _showArbitration(document);
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _failed = true;
          _message = 'Comparaison impossible : $error';
        });
      }
    } finally {
      _decisionOpen = false;
    }
  }

  Future<void> _showArbitration(Map<String, dynamic> document) async {
    final service = ref.read(sharedServiceProvider);
    String candidateId = 'current';
    final reason = TextEditingController();
    final candidates = document['candidates'] as List<dynamic>;
    final versions = <Map<String, dynamic>>[
      {
        'id': 'current',
        'actor': document['owner'],
        'at': document['updated_at'],
        'payload': document['payload'],
      },
      ...candidates.cast<Map<String, dynamic>>(),
    ];
    final memberNames = {
      for (final member
          in (service.snapshot?['members'] as List? ?? [])
              .whereType<Map<String, dynamic>>())
        '${member['id']}': '${member['name']}',
    };
    final accounts = {
      for (final account in [
        ...(service.snapshot?['leaders'] as List? ?? []),
        ...(service.snapshot?['accounts'] as List? ?? []),
      ].whereType<Map<String, dynamic>>())
        '${account['id']}': '${account['username']}',
    };
    final rows = [
      for (final v in versions)
        decisionRows(
          document['domain'] as String,
          v['payload'] as Map<String, dynamic>,
          memberNames,
        ),
    ];
    String? reasonError;
    final accepted = await showAppFormDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => _dialog(
          ctx,
          title: const Text('Choisir la version à retenir'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: reason,
                  decoration: InputDecoration(
                    labelText: 'Motif de décision',
                    error: reasonError == null ? null : const SizedBox.shrink(),
                  ),
                ),
                if (reasonError != null)
                  Semantics(
                    liveRegion: true,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        reasonError!,
                        style: TextStyle(
                          color: Theme.of(ctx).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Les versions écartées restent conservées et ne sont pas additionnées.',
                        ),
                        RadioGroup<String>(
                          groupValue: candidateId,
                          onChanged: (value) =>
                              update(() => candidateId = value!),
                          child: Column(
                            children: [
                              for (final version in versions)
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    RadioListTile<String>(
                                      contentPadding: EdgeInsets.zero,
                                      value: version['id'] as String,
                                      title: Text(
                                        version['id'] == 'current'
                                            ? 'Version actuellement publiée'
                                            : 'Version concurrente',
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Auteur : ${accounts['${version['actor']}'] ?? version['actor'] ?? 'Non renseigné'}',
                                          ),
                                          Text(
                                            'Saisie : ${decisionDate(version['at'])}',
                                          ),
                                          if (version['reason'] != null)
                                            Text(
                                              'Motif : ${version['reason']}',
                                            ),
                                        ],
                                      ),
                                    ),
                                    DecisionDetails(
                                      rows: rows[versions.indexOf(version)],
                                      others: [
                                        for (
                                          var i = 0;
                                          i < versions.length;
                                          i++
                                        )
                                          if (i != versions.indexOf(version))
                                            rows[i],
                                      ],
                                    ),
                                    const Divider(height: 20),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
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
                if (reason.text.trim().isEmpty) {
                  update(() => reasonError = 'Indiquez le motif de décision.');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Retenir cette version'),
            ),
          ],
        ),
      ),
    );
    final explanation = reason.text.trim();
    reason.dispose();
    if (accepted == true && explanation.isNotEmpty) {
      await _perform(() async {
        await service.request(
          'POST',
          '/groups/${service.groupId}/documents/${document['domain']}/${document['occurrence_id']}/resolve',
          {
            'revision': document['revision'],
            'candidate_id': candidateId,
            'reason': explanation,
          },
        );
        await service.synchronize();
      });
    }
  }

  String _summary(String domain, Map<String, dynamic> payload) {
    final dateValue = domain == 'sport'
        ? (payload['session'] as Map)['played_at']
        : payload['played_at'];
    final date = DateTime.tryParse('$dateValue');
    final label = date == null
        ? 'Date non renseignée'
        : DateFormat("d MMM yyyy '·' HH'h'mm", 'fr_FR').format(date);
    if (domain == 'sport') {
      final session = payload['session'] as Map<String, dynamic>;
      return "$label · ${session['score_a'] ?? '–'} – ${session['score_b'] ?? '–'}";
    }
    final lines = payload['lines'] as List<dynamic>;
    final received = lines.fold<int>(
      0,
      (n, l) =>
          n + ((l as Map)['contribution'] as int) + (l['penalty_paid'] as int),
    );
    return '$label · Versements membres : $received F';
  }

  Future<void> _changeRoles(Map<String, dynamic> account) async {
    final roles = (account['roles'] as List<dynamic>).cast<String>().toSet();
    final reason = TextEditingController();
    final accepted = await showAppFormDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => _dialog(
          ctx,
          title: Text('Rôles · ${account['username']}'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Un transfert retire le rôle unique à son ancien titulaire.',
                  ),
                  for (final entry in roleLabels.entries.where(
                    (e) => e.key != 'MEMBER',
                  ))
                    CheckboxListTile(
                      title: Text(entry.value),
                      value: roles.contains(entry.key),
                      onChanged: (value) => update(() {
                        if (value == true) {
                          roles.add(entry.key);
                        } else {
                          roles.remove(entry.key);
                        }
                      }),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reason,
                    decoration: const InputDecoration(
                      labelText: 'Motif de changement / transfert',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmer les rôles'),
            ),
          ],
        ),
      ),
    );
    final explanation = reason.text.trim();
    reason.dispose();
    if (accepted == true && explanation.isNotEmpty) {
      await _perform(() async {
        final service = ref.read(sharedServiceProvider);
        await service.request(
          'PUT',
          '/groups/${service.groupId}/accounts/${account['id']}/roles',
          {'roles': roles.toList(), 'transfer': true, 'reason': explanation},
        );
        await service.synchronize();
      });
    }
  }

  Future<void> _opening() async {
    final service = ref.read(sharedServiceProvider);
    final cash = TextEditingController(text: '0');
    final start = TextEditingController(
      text: DateTime.now().toIso8601String().substring(0, 10),
    );
    final balances = <String, TextEditingController>{};
    final penalties = <String, TextEditingController>{};
    final players = ref.read(playersListProvider).value ?? [];
    for (final player in players) {
      balances[player.id] = TextEditingController(text: '0');
      penalties[player.id] = TextEditingController(text: '0');
    }
    final accepted = await showAppFormDialog<bool>(
      context: context,
      builder: (ctx) => _dialog(
        ctx,
        title: const Text('Situation financière de départ'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Ces soldes précèdent les séances enregistrées. Les versements historiques ne sont pas comptés une seconde fois.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: cash,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Caisse disponible (F)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: start,
                  decoration: const InputDecoration(
                    labelText: 'Comptabiliser à partir du (AAAA-MM-JJ)',
                  ),
                ),
                for (final player in players) ...[
                  const Divider(),
                  Text(player.name),
                  const SizedBox(height: 12),
                  TextField(
                    controller: balances[player.id],
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                    ),
                    decoration: const InputDecoration(
                      labelText:
                          'Cotisations : avance positive / dette négative',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: penalties[player.id],
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Retards et sanctions impayés (F)',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Soumettre au PDT / VP'),
          ),
        ],
      ),
    );
    final payload = {
      'cash': int.tryParse(cash.text),
      'start_date': start.text.trim(),
      'members': {
        for (final player in players)
          player.id: {
            'contribution_balance': int.tryParse(balances[player.id]!.text),
            'penalty_debt': int.tryParse(penalties[player.id]!.text),
          },
      },
    };
    cash.dispose();
    start.dispose();
    for (final c in [...balances.values, ...penalties.values]) {
      c.dispose();
    }
    if (accepted == true) {
      await _perform(() async {
        await service.request(
          'POST',
          '/groups/${service.groupId}/opening',
          payload,
        );
        await service.synchronize();
      });
    }
  }

  Future<void> _transfer(Map<String, dynamic> document) async {
    final service = ref.read(sharedServiceProvider);
    final leaders = (service.snapshot?['leaders'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final permitted = document['domain'] == 'sport'
        ? ['ADMIN', 'PDT', 'VP', 'SG', 'SGA']
        : ['TR', 'TGA'];
    final choices = leaders
        .where((a) => (a['roles'] as List<dynamic>).any(permitted.contains))
        .toList();
    String? target;
    final reason = TextEditingController();
    final accepted = await showAppFormDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => _dialog(
          ctx,
          title: const Text('Transférer la responsabilité'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: target,
                items: choices
                    .map(
                      (a) => DropdownMenuItem(
                        value: a['id'] as String,
                        child: Text(a['username'] as String),
                      ),
                    )
                    .toList(),
                onChanged: (v) => update(() => target = v),
                decoration: const InputDecoration(
                  labelText: 'Nouveau responsable',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reason,
                decoration: const InputDecoration(
                  labelText: 'Motif obligatoire',
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
              child: const Text('Transférer'),
            ),
          ],
        ),
      ),
    );
    final explanation = reason.text.trim();
    reason.dispose();
    if (accepted == true && target != null && explanation.isNotEmpty) {
      await _perform(() async {
        await service.request(
          'POST',
          '/groups/${service.groupId}/documents/${document['domain']}/${document['occurrence_id']}/transfer',
          {
            'revision': document['revision'],
            'account_id': target,
            'reason': explanation,
          },
        );
        await service.synchronize();
      });
    }
  }

  InputDecorationTheme _inputs(BuildContext context) => InputDecorationTheme(
    filled: true,
    fillColor: context.colors.background800,
    labelStyle: TextStyle(color: context.colors.foreground400, fontSize: 13),
    hintStyle: TextStyle(color: context.colors.foreground500, fontSize: 13),
    floatingLabelStyle: TextStyle(
      color: context.colors.primary400,
      fontSize: 13,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: context.colors.background700),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: context.colors.background700),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: context.colors.primary500, width: 2),
    ),
  );

  Widget _dialog(
    BuildContext dialogContext, {
    required Widget title,
    required Widget content,
    required List<Widget> actions,
  }) => Theme(
    data: Theme.of(dialogContext).copyWith(
      inputDecorationTheme: _inputs(dialogContext),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: dialogContext.colors.primary500,
          foregroundColor: Theme.of(dialogContext).colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9999),
          ),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    ),
    child: AlertDialog(
      backgroundColor: dialogContext.colors.background900,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: TextStyle(
        color: dialogContext.colors.foreground50,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      contentTextStyle: TextStyle(
        color: dialogContext.colors.foreground400,
        fontSize: 13,
      ),
      title: title,
      content: content,
      actions: actions,
    ),
  );

  Widget _heading(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      title,
      style: TextStyle(
        color: context.colors.foreground50,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    IconData? icon,
    String? hint,
    bool password = false,
    TextInputType? keyboardType,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: context.colors.foreground200,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: !_busy,
          obscureText: password && !_shownPasswords.contains(controller),
          autocorrect: false,
          keyboardType: keyboardType,
          style: TextStyle(color: context.colors.foreground50, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint ?? (password ? 'Au moins 8 caractères' : 'Ex. : membres'),
            prefixIcon: icon == null
                ? null
                : Icon(icon, color: context.colors.foreground400, size: 20),
            suffixIcon: password
                ? IconButton(
                    tooltip: _shownPasswords.contains(controller)
                        ? 'Masquer le mot de passe'
                        : 'Afficher le mot de passe',
                    icon: Icon(
                      _shownPasswords.contains(controller)
                          ? Remix.eye_off_line
                          : Remix.eye_line,
                      color: context.colors.foreground400,
                      size: 20,
                    ),
                    onPressed: () => setState(() {
                      if (!_shownPasswords.add(controller)) {
                        _shownPasswords.remove(controller);
                      }
                    }),
                  )
                : null,
          ),
        ),
      ],
    ),
  );

  Widget _action({
    required String title,
    required IconData icon,
    String? subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    Color? color,
  }) => ListTile(
    contentPadding: EdgeInsets.zero,
    horizontalTitleGap: 12,
    minLeadingWidth: 22,
    leading: Icon(icon, color: color ?? context.colors.primary400, size: 22),
    title: Text(
      title,
      style: TextStyle(
        color: color ?? context.colors.foreground50,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),
    subtitle: subtitle == null
        ? null
        : Text(
            subtitle,
            style: TextStyle(color: context.colors.foreground400, fontSize: 12),
          ),
    trailing:
        trailing ??
        (onTap == null
            ? null
            : Icon(
                Remix.arrow_right_s_line,
                color: context.colors.foreground500,
                size: 18,
              )),
    onTap: _busy ? null : onTap,
  );

  Widget _badge(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: context.colors.primary500.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(9999),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: context.colors.primary400,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Future<void> _publishMembers() async {
    await _perform(() async {
      final service = ref.read(sharedServiceProvider);
      final db = await AppDatabase.instance.database;
      final members = await db.query(
        'players',
        where: 'team_id = ?',
        whereArgs: [service.groupId],
      );
      await service.request(
        'PUT',
        '/groups/${service.groupId}/members',
        members,
      );
      await service.synchronize();
    });
  }

  List<Widget> _connection() => [
    AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Remix.team_line, color: context.colors.primary400, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Votre groupe, ensemble',
                  style: TextStyle(
                    color: context.colors.foreground50,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Partagez vos séances, vos classements et les finances du groupe.',
            style: TextStyle(
              color: context.colors.foreground400,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('Rejoindre')),
                ButtonSegment(value: true, label: Text('Partager')),
              ],
              selected: {_create},
              onSelectionChanged: _busy
                  ? null
                  : (values) => setState(() => _create = values.first),
              style: ButtonStyle(
                textStyle: const WidgetStatePropertyAll(
                  TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                foregroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? context.colors.primary400
                      : context.colors.foreground300,
                ),
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? context.colors.primary500.withValues(alpha: 0.15)
                      : context.colors.background800,
                ),
                side: WidgetStatePropertyAll(
                  BorderSide(color: context.colors.background700),
                ),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 24),
    _heading(_create ? 'Votre accès gestionnaire' : 'Votre accès au groupe'),
    AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _create
                ? 'Partagez votre groupe local et créez votre compte Admin.'
                : 'Utilisez les identifiants reçus du gestionnaire.',
            style: TextStyle(
              color: context.colors.foreground400,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          if (!_create)
            _field(
              _group,
              'Identifiant du groupe',
              icon: Remix.team_line,
              hint: 'Communiqué par votre gestionnaire',
            ),
          _field(
            _user,
            _create ? 'Votre identifiant' : 'Identifiant',
            icon: Remix.user_line,
          ),
          _field(
            _password,
            'Mot de passe',
            password: true,
            icon: Remix.lock_line,
          ),
        ],
      ),
    ),
    if (_create) ...[
      const SizedBox(height: 24),
      _heading('Accès des membres'),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Un accès commun pour consulter les données du groupe.',
              style: TextStyle(
                color: context.colors.foreground400,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            _field(_sharedUser, 'Identifiant commun', icon: Remix.team_line),
            _field(
              _sharedPassword,
              'Mot de passe commun',
              password: true,
              icon: Remix.lock_line,
            ),
          ],
        ),
      ),
    ],
    const SizedBox(height: 24),
    PrimaryButton(
      label: _busy
          ? 'Connexion en cours…'
          : _create
          ? 'Créer le groupe partagé'
          : 'Se connecter',
      icon: Remix.arrow_right_s_line,
      onPressed: _busy ? null : () => unawaited(_perform(_connect)),
    ),
  ];

  List<Widget> _management() {
    final service = ref.watch(sharedServiceProvider);
    final documents =
        (service.snapshot?['documents'] as Map<String, dynamic>? ?? {}).values
            .cast<Map<String, dynamic>>()
            .toList();
    final admin = service.roles.contains('ADMIN');
    final arbiter = service.roles.any(['PDT', 'VP'].contains);
    final accounts = (service.snapshot?['accounts'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final conflicts = documents
        .where((d) => (d['candidates'] as List<dynamic>? ?? []).isNotEmpty)
        .toList();
    final responsibilities = documents
        .where((d) => d['owner'] == service.accountId || arbiter)
        .toList();
    return [
      if (service.syncWarning != null) ...[
        AppCard(child: Text(service.syncWarning!, style: TextStyle(color: context.colors.warning))),
        const SizedBox(height: 16),
      ],
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Remix.team_line,
                  color: context.colors.primary400,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    service.snapshot?['name'] as String? ?? 'Votre groupe',
                    style: TextStyle(
                      color: context.colors.foreground50,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _badge('Partagé'),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final role in service.roles)
                  _badge(roleLabels[role] ?? role),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Identifiant du groupe',
              style: TextStyle(
                color: context.colors.foreground400,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              service.groupId ?? '',
              style: TextStyle(
                color: context.colors.foreground200,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      _heading('Synchronisation'),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _action(
              title: 'Vos données partagées',
              subtitle:
                  'Vos saisies hors ligne sont transmises à la reconnexion.',
              icon: Remix.refresh_line,
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: _busy ? 'Mise à jour…' : 'Synchroniser maintenant',
              icon: Remix.refresh_line,
              onPressed: _busy
                  ? null
                  : () => unawaited(_perform(service.synchronize)),
            ),
          ],
        ),
      ),
      if (admin) ...[
        const SizedBox(height: 24),
        _heading('Comptes et rôles'),
        Text(
          'Les simples membres utilisent l’accès collectif en lecture seule.',
          style: TextStyle(color: context.colors.foreground400, fontSize: 12),
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              for (final account in accounts) ...[
                _action(
                  title: account['username'] as String,
                  subtitle: (account['roles'] as List<dynamic>)
                      .map((r) => roleLabels[r] ?? r)
                      .join(' · '),
                  icon: account['shared'] == true
                      ? Remix.team_line
                      : Remix.user_line,
                  onTap: account['shared'] == true
                      ? null
                      : () => unawaited(_changeRoles(account)),
                  trailing: account['shared'] == true
                      ? Text(
                          'Lecture seule',
                          style: TextStyle(
                            color: context.colors.foreground400,
                            fontSize: 11,
                          ),
                        )
                      : null,
                ),
                Divider(color: context.colors.background700, height: 1),
              ],
              _action(
                title: 'Ajouter un gestionnaire',
                subtitle: 'Compte individuel et attribution des rôles',
                icon: Remix.add_line,
                onTap: () => unawaited(_addAccount()),
              ),
              Divider(color: context.colors.background700, height: 1),
              _action(
                title: 'Mettre à jour les membres',
                subtitle: 'Partager votre effectif local',
                icon: Remix.team_line,
                onTap: () => unawaited(_publishMembers()),
              ),
            ],
          ),
        ),
      ],
      if (arbiter) ...[
        const SizedBox(height: 24),
        _heading('Arbitrages'),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              if (conflicts.isEmpty)
                _action(
                  title: 'Aucun conflit à traiter',
                  icon: Remix.check_line,
                ),
              for (final document in conflicts)
                _action(
                  title:
                      'Conflit ${document['domain'] == 'sport' ? 'sportif' : 'financier'}',
                  subtitle: _summary(
                    document['domain'] as String,
                    document['payload'] as Map<String, dynamic>,
                  ),
                  icon: Remix.alert_line,
                  onTap: () => unawaited(_arbitrate(document)),
                ),
            ],
          ),
        ),
      ],
      if ((service.roles.any(['TR', 'TGA'].contains) &&
              service.snapshot?['opening'] == null) ||
          (arbiter && service.snapshot?['opening_proposal'] != null)) ...[
        const SizedBox(height: 24),
        _heading('Situation financière de départ'),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              if (service.roles.any(['TR', 'TGA'].contains) &&
                  service.snapshot?['opening'] == null)
                _action(
                  title: 'Renseigner les soldes initiaux',
                  subtitle: 'Caisse, avances et dettes du groupe',
                  icon: Remix.wallet_line,
                  onTap: () => unawaited(_opening()),
                ),
              if (arbiter && service.snapshot?['opening_proposal'] != null)
                _action(
                  title: 'Approuver les soldes initiaux',
                  subtitle: 'Vérifier la situation soumise par le trésorier',
                  icon: Remix.check_line,
                  onTap: () => unawaited(_approveOpening()),
                ),
            ],
          ),
        ),
      ],
      if (responsibilities.isNotEmpty) ...[
        const SizedBox(height: 24),
        _heading('Responsables des séances'),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              for (final document in responsibilities)
                _action(
                  title:
                      'Responsabilité ${document['domain'] == 'sport' ? 'sportive' : 'financière'}',
                  subtitle: _summary(
                    document['domain'] as String,
                    document['payload'] as Map<String, dynamic>,
                  ),
                  icon: document['domain'] == 'sport'
                      ? Remix.team_line
                      : Remix.wallet_line,
                  onTap: () => unawaited(_transfer(document)),
                ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 24),
      TextButton.icon(
        icon: const Icon(Remix.logout_box_r_line, size: 18),
        label: const Text('Se déconnecter'),
        style: TextButton.styleFrom(
          foregroundColor: context.colors.danger,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        onPressed: _busy ? null : () => unawaited(_perform(service.disconnect)),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(sharedStatusProvider);
    final service = ref.watch(sharedServiceProvider);
    return Theme(
      data: Theme.of(context).copyWith(inputDecorationTheme: _inputs(context)),
      child: Scaffold(
        backgroundColor: context.colors.background950,
        appBar: AppBar(
          title: const Text('Groupe partagé'),
          leading: Navigator.of(context).canPop()
              ? IconButton(
                  icon: const Icon(Remix.arrow_left_s_line),
                  onPressed: () => Navigator.of(context).pop(),
                )
              : null,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
          children: [
            ...service.connected ? _management() : _connection(),
            if (_busy) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ],
            if (_message != null) ...[
              const SizedBox(height: 16),
              AppCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _failed ? Remix.alert_line : Remix.check_line,
                      color: _failed
                          ? context.colors.danger
                          : context.colors.primary400,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _message!,
                        style: TextStyle(
                          color: context.colors.foreground200,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
