import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/app_database.dart';
import '../../../core/widgets/app_form_dialog.dart';
import '../../finance/application/finance_providers.dart';
import '../../players/application/players_provider.dart';
import '../../sessions/application/sessions_provider.dart';
import '../../team/application/team_provider.dart';
import '../application/shared_providers.dart';

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
  final _url = TextEditingController(
    text: const String.fromEnvironment('STATOO_API'),
  );
  final _group = TextEditingController();
  final _user = TextEditingController();
  final _password = TextEditingController();
  final _sharedUser = TextEditingController(text: 'membres');
  final _sharedPassword = TextEditingController();
  bool _create = false;
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    for (final c in [
      _url,
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
    if (!mounted) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await operation();
      ref.read(sharedStatusProvider.notifier).refresh();
      ref.invalidate(allSessionsProvider);
      ref.invalidate(playersListProvider);
      ref.invalidate(financialPointsProvider);
      ref.invalidate(financialTotalsProvider);
      if (mounted) setState(() => _message = 'Données mises à jour.');
    } on Object catch (e) {
      if (mounted) setState(() => _message = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connect() async {
    final service = ref.read(sharedServiceProvider);
    final group = ref.read(activeTeamIdProvider);
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
      registration = {
        'group_id': group,
        'name': info['name'],
        'username': _user.text.trim(),
        'password': _password.text,
        'shared_username': _sharedUser.text.trim(),
        'shared_password': _sharedPassword.text,
        'members': members,
      };
    }
    await service.connect(
      _url.text,
      _create ? group! : _group.text.trim(),
      _user.text.trim(),
      _password.text,
      registration: registration,
    );
    await ref.read(activeTeamIdProvider.notifier).selectTeam(service.groupId!);
    await ref.read(hasTeamProvider.notifier).reloadFromDb();
    ref.invalidate(teamInfoProvider);
    ref.invalidate(allTeamsProvider);
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
        builder: (ctx, update) => AlertDialog(
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
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Identifiant'),
                  ),
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
    if (result == true && member != null) {
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

  Future<void> _arbitrate(Map<String, dynamic> document) async {
    final service = ref.read(sharedServiceProvider);
    String candidateId = 'current';
    final reason = TextEditingController();
    final candidates = document['candidates'] as List<dynamic>;
    final accepted = await showAppFormDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Choisir la version à retenir'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Les versions écartées restent conservées et ne sont pas additionnées.',
                  ),
                  RadioGroup<String>(
                    groupValue: candidateId,
                    onChanged: (value) => update(() => candidateId = value!),
                    child: Column(
                      children: [
                        for (final version in [
                          {
                            'id': 'current',
                            'actor': document['owner'],
                            'payload': document['payload'],
                          },
                          ...candidates.cast<Map<String, dynamic>>(),
                        ])
                          RadioListTile<String>(
                            value: version['id'] as String,
                            title: Text(
                              version['id'] == 'current'
                                  ? 'Version actuellement publiée'
                                  : 'Version concurrente',
                            ),
                            subtitle: Text(
                              _summary(
                                document['domain'] as String,
                                version['payload'] as Map<String, dynamic>,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  TextField(
                    controller: reason,
                    decoration: const InputDecoration(
                      labelText: 'Motif de décision',
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
    if (domain == 'sport') {
      final s = payload['session'] as Map;
      return '${s['played_at']} · ${s['score_a'] ?? '–'} – ${s['score_b'] ?? '–'}';
    }
    final lines = payload['lines'] as List<dynamic>;
    final received = lines.fold<int>(
      0,
      (n, l) =>
          n + ((l as Map)['contribution'] as int) + (l['penalty_paid'] as int),
    );
    return '${payload['played_at']} · Versements membres : $received F';
  }

  Future<void> _changeRoles(Map<String, dynamic> account) async {
    final roles = (account['roles'] as List<dynamic>).cast<String>().toSet();
    final reason = TextEditingController();
    final accepted = await showAppFormDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
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
      builder: (ctx) => AlertDialog(
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
                TextField(
                  controller: cash,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Caisse disponible (F)',
                  ),
                ),
                TextField(
                  controller: start,
                  decoration: const InputDecoration(
                    labelText: 'Comptabiliser à partir du (AAAA-MM-JJ)',
                  ),
                ),
                for (final player in players) ...[
                  const Divider(),
                  Text(player.name),
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
        ? ['SG', 'SGA']
        : ['TR', 'TGA'];
    final choices = leaders
        .where((a) => (a['roles'] as List<dynamic>).any(permitted.contains))
        .toList();
    String? target;
    final reason = TextEditingController();
    final accepted = await showAppFormDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
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

  @override
  Widget build(BuildContext context) {
    ref.watch(sharedStatusProvider);
    final service = ref.watch(sharedServiceProvider);
    final documents =
        (service.snapshot?['documents'] as Map<String, dynamic>? ?? {}).values
            .cast<Map<String, dynamic>>();
    return Scaffold(
      appBar: AppBar(title: const Text('Groupe partagé')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!service.connected) ...[
            const Text(
              'Connectez votre groupe à l’API pour partager les données. Les identifiants de gestion sont individuels ; l’accès Membre est collectif.',
            ),
            TextField(
              controller: _url,
              decoration: const InputDecoration(
                labelText: 'Adresse de l’API HTTPS',
              ),
            ),
            SwitchListTile(
              title: const Text('Publier mon groupe local (créateur / Admin)'),
              value: _create,
              onChanged: (value) => setState(() => _create = value),
            ),
            if (!_create)
              TextField(
                controller: _group,
                decoration: const InputDecoration(
                  labelText: 'Identifiant du groupe communiqué par l’Admin',
                ),
              ),
            TextField(
              controller: _user,
              decoration: const InputDecoration(
                labelText: 'Identifiant personnel ou collectif',
              ),
            ),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Mot de passe'),
            ),
            if (_create) ...[
              TextField(
                controller: _sharedUser,
                decoration: const InputDecoration(
                  labelText: 'Identifiant collectif des membres',
                ),
              ),
              TextField(
                controller: _sharedPassword,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mot de passe collectif',
                ),
              ),
            ],
            FilledButton(
              onPressed: _busy ? null : () => unawaited(_perform(_connect)),
              child: Text(_create ? 'Créer le groupe partagé' : 'Se connecter'),
            ),
          ] else ...[
            Text(
              'Groupe : ${service.groupId}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Rôles : ${service.roles.map((r) => roleLabels[r] ?? r).join(', ')}',
            ),
            const Text(
              'La saisie hors ligne utilise vos droits connus. La synchronisation vérifie les droits actuels sur le serveur.',
            ),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () => unawaited(_perform(service.synchronize)),
              child: const Text('Synchroniser maintenant'),
            ),
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => unawaited(_perform(service.disconnect)),
              child: const Text('Se déconnecter'),
            ),
            if (service.roles.contains('ADMIN')) ...[
              FilledButton(
                onPressed: _busy ? null : () => unawaited(_addAccount()),
                child: const Text('Ajouter un compte et attribuer des rôles'),
              ),
              for (final account
                  in service.snapshot?['accounts'] as List<dynamic>? ?? [])
                ListTile(
                  title: Text((account as Map)['username'] as String),
                  subtitle: Text(
                    (account['roles'] as List<dynamic>).join(', '),
                  ),
                  trailing: account['shared'] == true
                      ? null
                      : TextButton(
                          onPressed: _busy
                              ? null
                              : () => unawaited(
                                  _changeRoles(
                                    Map<String, dynamic>.from(account),
                                  ),
                                ),
                          child: const Text('Rôles'),
                        ),
                ),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => unawaited(
                        _perform(() async {
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
                        }),
                      ),
                child: const Text('Publier l’effectif local'),
              ),
            ],
            if (service.roles.any(['PDT', 'VP'].contains))
              for (final document in documents.where(
                (d) => (d['candidates'] as List<dynamic>? ?? []).isNotEmpty,
              ))
                Card(
                  child: ListTile(
                    title: Text(
                      'Conflit ${document['domain'] == 'sport' ? 'sportif' : 'financier'}',
                    ),
                    subtitle: Text(
                      _summary(
                        document['domain'] as String,
                        document['payload'] as Map<String, dynamic>,
                      ),
                    ),
                    trailing: TextButton(
                      onPressed: _busy
                          ? null
                          : () => unawaited(_arbitrate(document)),
                      child: const Text('Arbitrer'),
                    ),
                  ),
                ),
            if (service.roles.any(['TR', 'TGA'].contains) &&
                service.snapshot?['opening'] == null)
              OutlinedButton(
                onPressed: _busy ? null : () => unawaited(_opening()),
                child: const Text('Soumettre les soldes initiaux'),
              ),
            for (final document in documents.where(
              (d) =>
                  d['owner'] == service.accountId ||
                  service.roles.any(['PDT', 'VP'].contains),
            ))
              ListTile(
                title: Text(
                  'Responsabilité ${document['domain'] == 'sport' ? 'sportive' : 'financière'}',
                ),
                subtitle: Text(
                  _summary(
                    document['domain'] as String,
                    document['payload'] as Map<String, dynamic>,
                  ),
                ),
                trailing: TextButton(
                  onPressed: _busy
                      ? null
                      : () => unawaited(_transfer(document)),
                  child: const Text('Transférer'),
                ),
              ),
            if (service.snapshot?['opening_proposal'] != null &&
                service.roles.any(['PDT', 'VP'].contains))
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => unawaited(
                        _perform(() async {
                          await service.request(
                            'POST',
                            '/groups/${service.groupId}/opening/approve',
                          );
                          await service.synchronize();
                        }),
                      ),
                child: const Text('Approuver les soldes initiaux'),
              ),
          ],
          if (_busy) const LinearProgressIndicator(),
          if (_message != null)
            Padding(padding: const EdgeInsets.all(12), child: Text(_message!)),
        ],
      ),
    );
  }
}
