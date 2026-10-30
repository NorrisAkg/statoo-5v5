import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/soccer_shoe_icon.dart';
import '../application/sessions_provider.dart';
import '../domain/participation.dart';
import '../domain/session.dart';
import '../domain/session_summary.dart';
import '../domain/team_appearance.dart';
import 'session_team_colors.dart';

/// Live entry shares the persisted aggregates used by home, finance and ranking.
class LiveStatsPanel extends ConsumerStatefulWidget {
  const LiveStatsPanel({
    required this.session,
    required this.players,
    required this.editable,
    super.key,
  });
  final Session session;
  final List<SessionParticipantDetail> players;
  final bool editable;
  @override
  ConsumerState<LiveStatsPanel> createState() => _LiveStatsPanelState();
}

class _LiveStatsPanelState extends ConsumerState<LiveStatsPanel> {
  Team selected = Team.a;
  bool busy = false;
  String? message;
  bool get writable => widget.editable && !busy;
  String name(String? id) =>
      widget.players
          .where((p) => p.participation.id == id)
          .firstOrNull
          ?.playerName ??
      'Non attribué';
  Future<void> mutate(Map<String, dynamic>? action, {String? edit}) async {
    if (!writable) return;
    setState(() => busy = true);
    try {
      await ref
          .read(sessionsControllerProvider)
          .recordLive(widget.session.id, action, edit: edit);
      if (mounted) setState(() => message = 'Enregistré sur cet appareil');
    } on Object catch (e) {
      if (mounted) {
        setState(
          () => message = e is StateError
              ? e.message
              : 'Enregistrement impossible : $e',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> pick(
    String type, {
    String? player,
    String? edit,
    Team? eventTeam,
  }) async {
    if (!writable) return;
    final team = eventTeam ?? selected;
    final players = widget.players
        .where((p) => p.participation.team == team)
        .toList();
    final action = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _LivePicker(
        type: type,
        team: team,
        teamName: widget.session.teamName(team),
        players: players,
        initial: player,
        editing: edit != null,
      ),
    );
    if (action != null && mounted) await mutate(action, edit: edit);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final teams = [
      Team.a,
      Team.b,
      if (s.sessionType == SessionType.tournament3) Team.c,
    ];
    final players = widget.players
        .where((p) => p.participation.team == selected)
        .toList();
    final journal = ref.watch(liveJournalProvider(s.id));
    final operations = journal.value ?? <Map<String, dynamic>>[];
    final events = <String, Map<String, dynamic>>{};
    for (final op in operations) {
      events[(op['target'] ?? op['id']) as String] = op;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in teams)
              Semantics(
                selected: selected == t,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: selected == t
                        ? s.teamColor(context, t).withValues(alpha: .18)
                        : null,
                    side: BorderSide(
                      color: s.teamColor(context, t),
                      width: selected == t ? 2 : 1,
                    ),
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: () => setState(() => selected = t),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(s.teamName(t)),
                      if (selected == t)
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Remix.check_line, size: 16),
                            SizedBox(width: 4),
                            Text('Actif'),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (widget.editable) ...[
          Row(
            children: [
              Expanded(
                child: Tooltip(
                  message: 'Ajouter un but',
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    onPressed: writable ? () => pick('goal') : null,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Remix.football_line,
                            size: 20,
                            color: context.colors.foreground50,
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Remix.add_line,
                            size: 16,
                            color: context.colors.foreground50,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Tooltip(
                  message: 'Carton jaune',
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    onPressed: writable ? () => pick('yellow') : null,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Remix.rectangle_fill,
                            size: 20,
                            color: context.colors.card,
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Remix.add_line,
                            size: 16,
                            color: context.colors.card,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Tooltip(
                  message: 'Carton rouge',
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    onPressed: writable ? () => pick('red') : null,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Remix.rectangle_fill,
                            size: 20,
                            color: context.colors.danger,
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Remix.add_line,
                            size: 16,
                            color: context.colors.danger,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: writable && operations.isNotEmpty && !journal.hasError
                ? () => mutate(null)
                : null,
            child: const Text('Annuler la dernière action'),
          ),
        ],
        if (busy) const LinearProgressIndicator(),
        if (message != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(message!, semanticsLabel: message),
          ),
        if (journal.hasError)
          Text(
            'Journal local indisponible : ${journal.error}. Les statistiques conservées restent affichées.',
          ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (players.isEmpty) const Text('Aucun joueur assigné'),
              for (final p in players)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.playerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Semantics(
                              label:
                                  '${p.playerName}: ${p.participation.goals} buts, ${p.participation.assists} passes, ${p.participation.yellowCards} cartons jaunes, ${p.participation.redCards} cartons rouges',
                              excludeSemantics: true,
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  _buildStatItem(
                                    icon: Icon(
                                      Remix.football_line,
                                      size: 13,
                                      color: context.colors.primary400,
                                    ),
                                    count: p.participation.goals,
                                    color: context.colors.primary400,
                                  ),
                                  _buildStatItem(
                                    icon: SoccerShoeIcon(
                                      size: 13,
                                      color: context.colors.secondary400,
                                    ),
                                    count: p.participation.assists,
                                    color: context.colors.secondary400,
                                  ),
                                  _buildStatItem(
                                    icon: Container(
                                      width: 7,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: context.colors.card,
                                        borderRadius:
                                            BorderRadius.circular(1.5),
                                      ),
                                    ),
                                    count: p.participation.yellowCards,
                                    color: context.colors.card,
                                  ),
                                  _buildStatItem(
                                    icon: Container(
                                      width: 7,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: context.colors.danger,
                                        borderRadius:
                                            BorderRadius.circular(1.5),
                                      ),
                                    ),
                                    count: p.participation.redCards,
                                    color: context.colors.danger,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.editable)
                        IconButton(
                          tooltip: 'Ajouter un but pour ${p.playerName}',
                          onPressed: writable
                              ? () => pick('goal', player: p.participation.id)
                              : null,
                          icon: const Icon(Remix.add_line),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (events.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'Dernières actions',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Text('Historique de cet appareil'),
          for (final entry in events.entries.toList().reversed.take(8))
            Builder(
              builder: (context) {
                final a = entry.value['action'] as Map;
                final t = Team.values.firstWhere(
                  (t) => t.name.toUpperCase() == a['team'],
                );
                final type = a['type'];
                final label = type == 'goal'
                    ? 'But'
                    : type == 'win'
                    ? 'Victoire ${a['delta'] == -1 ? 'retirée' : 'ajoutée'}'
                    : type == 'yellow'
                    ? 'Carton jaune'
                    : 'Carton rouge';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$label · ${s.teamName(t)}${type == 'win' ? '' : ' · ${name(a['player'] as String?)}'}',
                      ),
                      if (a['assist'] != null)
                        Text('Passe de ${name(a['assist'] as String?)}'),
                      if (widget.editable && type == 'goal')
                        TextButton(
                          onPressed: writable
                              ? () =>
                                    pick('goal', edit: entry.key, eventTeam: t)
                              : null,
                          child: const Text('Modifier ce but'),
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ],
    );
  }

  Widget _buildStatItem({
    required Widget icon,
    required int count,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 4),
        Text(
          '$count',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _LivePicker extends StatefulWidget {
  const _LivePicker({
    required this.type,
    required this.team,
    required this.teamName,
    required this.players,
    this.initial,
    this.editing = false,
  });
  final String type;
  final String teamName;
  final Team team;
  final List<SessionParticipantDetail> players;
  final String? initial;
  final bool editing;
  @override
  State<_LivePicker> createState() => _LivePickerState();
}

class _LivePickerState extends State<_LivePicker> {
  String? scorer;
  @override
  void initState() {
    super.initState();
    scorer = widget.initial;
  }

  void finish(String? player, [String? assist]) => Navigator.pop(context, {
    'type': widget.type,
    'team': widget.team.name.toUpperCase(),
    'player': player,
    'assist': assist,
    'delta': 1,
  });
  @override
  Widget build(BuildContext context) {
    final goal = widget.type == 'goal';
    final assistStep = goal && scorer != null;
    final scorerName = widget.players
        .where((p) => p.participation.id == scorer)
        .firstOrNull
        ?.playerName;
    return Theme(
      data: Theme.of(context).copyWith(
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
        ),
      ),
      child: AlertDialog(
        title: Text(
          assistStep
              ? 'But de $scorerName'
              : goal
              ? 'Qui a marqué ?'
              : 'Quel joueur reçoit le carton ?',
        ),
        scrollable: true,
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.teamName),
              if (assistStep) ...[
                const Text('Qui lui a fait la passe ?'),
                TextButton(
                  onPressed: () => finish(scorer),
                  child: const Text('Aucun passeur'),
                ),
              ],
              for (final p in widget.players.where(
                (p) => !assistStep || p.participation.id != scorer,
              ))
                TextButton(
                  onPressed: () => assistStep
                      ? finish(scorer, p.participation.id)
                      : goal
                      ? setState(() => scorer = p.participation.id)
                      : finish(p.participation.id),
                  child: Text(p.playerName),
                ),
              if (goal && !assistStep)
                TextButton(
                  onPressed: () => finish(null),
                  child: const Text('Buteur non renseigné'),
                ),
            ],
          ),
        ),
        actions: [
          if (assistStep)
            TextButton(
              onPressed: () => setState(() => scorer = null),
              child: const Text('Retour au buteur'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              widget.editing
                  ? 'Annuler la modification'
                  : goal
                  ? 'Annuler le but'
                  : 'Annuler le carton',
            ),
          ),
        ],
      ),
    );
  }
}

class LiveWinsBoard extends ConsumerStatefulWidget {
  const LiveWinsBoard({
    required this.session,
    required this.editable,
    super.key,
  });
  final Session session;
  final bool editable;
  @override
  ConsumerState<LiveWinsBoard> createState() => _LiveWinsBoardState();
}

class _LiveWinsBoardState extends ConsumerState<LiveWinsBoard> {
  bool busy = false;
  Future<void> change(Team team, int delta) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await ref.read(sessionsControllerProvider).recordLive(widget.session.id, {
        'type': 'win',
        'team': team.name.toUpperCase(),
        'delta': delta,
      });
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    return Column(
      children: [
        for (final t in Team.values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  s.teamName(t),
                  style: TextStyle(
                    color: s.teamColor(context, t),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text('${[s.winsA, s.winsB, s.winsC][t.index]} victoires'),
                if (widget.editable)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Retirer une victoire à ${s.teamName(t)}',
                        onPressed:
                            !busy && [s.winsA, s.winsB, s.winsC][t.index] > 0
                            ? () => change(t, -1)
                            : null,
                        icon: const Icon(Remix.subtract_line),
                      ),
                      IconButton(
                        tooltip: 'Ajouter une victoire à ${s.teamName(t)}',
                        onPressed: busy ? null : () => change(t, 1),
                        icon: const Icon(Remix.add_line),
                      ),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
