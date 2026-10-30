import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/initial_avatar.dart';
import '../../../core/widgets/soccer_shoe_icon.dart';
import '../application/sessions_provider.dart';
import '../domain/participation.dart';
import '../domain/session.dart';
import '../domain/session_summary.dart';
import '../domain/team_appearance.dart';
import 'session_team_colors.dart';
import 'team_tab_pill.dart';

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
        teamColor: widget.session.teamColor(context, team),
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
    final isTournament = s.sessionType == SessionType.tournament3;
    final teams = [
      Team.a,
      Team.b,
      if (isTournament) Team.c,
    ];
    final activeSelected =
        (!isTournament && selected == Team.c) ? Team.a : selected;
    final players = widget.players
        .where((p) => p.participation.team == activeSelected)
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
        Row(
          children: [
            for (int i = 0; i < teams.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(
                child: TeamTabPill(
                  title: s.teamName(teams[i]),
                  playerCount: widget.players
                      .where((p) => p.participation.team == teams[i])
                      .length,
                  color: s.teamColor(context, teams[i]),
                  isSelected: activeSelected == teams[i],
                  onTap: () => setState(() => selected = teams[i]),
                ),
              ),
            ],
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
    this.teamColor,
    this.initial,
    this.editing = false,
  });
  final String type;
  final String teamName;
  final Team team;
  final List<SessionParticipantDetail> players;
  final Color? teamColor;
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
    final colors = context.colors;
    final teamColor = widget.teamColor ?? colors.primary500;
    final goal = widget.type == 'goal';
    final assistStep = goal && scorer != null;
    final scorerName = widget.players
        .where((p) => p.participation.id == scorer)
        .firstOrNull
        ?.playerName;

    return AlertDialog(
      backgroundColor: colors.background900,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.background700),
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      scrollable: true,
      title: _buildTitle(context, goal, assistStep, scorerName, teamColor),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (assistStep) ...[
              _buildSpecialOption(
                context,
                title: 'Aucun passeur',
                subtitle: 'Action individuelle ou sans passeur direct',
                icon: Remix.close_circle_line,
                onTap: () => finish(scorer),
              ),
              const SizedBox(height: 8),
              Divider(color: colors.background700, height: 16),
              const SizedBox(height: 4),
            ],
            for (final p in widget.players.where(
              (p) => !assistStep || p.participation.id != scorer,
            )) ...[
              _buildPlayerTile(
                context,
                player: p,
                onTap: () => assistStep
                    ? finish(scorer, p.participation.id)
                    : goal
                    ? setState(() => scorer = p.participation.id)
                    : finish(p.participation.id),
              ),
              const SizedBox(height: 8),
            ],
            if (goal && !assistStep) ...[
              const SizedBox(height: 4),
              Divider(color: colors.background700, height: 16),
              const SizedBox(height: 4),
              _buildSpecialOption(
                context,
                title: 'Buteur non renseigné',
                subtitle: 'Attribué au score sans joueur nominatif',
                icon: Remix.question_line,
                onTap: () => finish(null),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (assistStep)
          TextButton.icon(
            onPressed: () => setState(() => scorer = null),
            icon: const Icon(Remix.arrow_left_line, size: 16),
            label: const Text('Retour au buteur'),
            style: TextButton.styleFrom(
              foregroundColor: colors.foreground300,
            ),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            foregroundColor: colors.foreground400,
          ),
          child: Text(
            widget.editing
                ? 'Annuler la modification'
                : goal
                ? 'Annuler le but'
                : 'Annuler le carton',
          ),
        ),
      ],
    );
  }

  Widget _buildTitle(
    BuildContext context,
    bool goal,
    bool assistStep,
    String? scorerName,
    Color teamColor,
  ) {
    final colors = context.colors;
    final Widget headerIcon;
    final String titleText;
    final String? subtitleText;

    if (assistStep) {
      headerIcon = SoccerShoeIcon(
        size: 20,
        color: colors.secondary400,
      );
      titleText = scorerName != null ? 'But de $scorerName' : 'But';
      subtitleText = 'Qui lui a fait la passe ?';
    } else if (goal) {
      headerIcon = Icon(
        Remix.football_line,
        size: 20,
        color: colors.primary400,
      );
      titleText = 'Qui a marqué ?';
      subtitleText = "Sélectionnez le buteur de l'action";
    } else {
      final isYellow = widget.type == 'yellow';
      headerIcon = Container(
        width: 14,
        height: 18,
        decoration: BoxDecoration(
          color: isYellow ? colors.card : colors.danger,
          borderRadius: BorderRadius.circular(3),
        ),
      );
      titleText = 'Quel joueur reçoit le carton ?';
      subtitleText = isYellow ? 'Carton jaune' : 'Carton rouge direct';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.background800,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.background700),
              ),
              child: headerIcon,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    titleText,
                    style: TextStyle(
                      color: colors.foreground50,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitleText,
                    style: TextStyle(
                      color: colors.foreground400,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: teamColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: teamColor.withValues(alpha: 0.28)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: teamColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  widget.teamName,
                  style: TextStyle(
                    color: teamColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerTile(
    BuildContext context, {
    required SessionParticipantDetail player,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;
    final initial = player.playerName.trim().isNotEmpty
        ? player.playerName.trim()[0]
        : '?';

    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        backgroundColor: colors.background800,
        foregroundColor: colors.foreground50,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.background700),
        ),
        minimumSize: const Size(48, 48),
      ),
      child: Row(
        children: [
          InitialAvatar(
            initial: initial,
            baseColor: InitialAvatar.colorForName(player.playerName),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              player.playerName,
              style: TextStyle(
                color: colors.foreground50,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(
            Remix.arrow_right_s_line,
            size: 18,
            color: colors.foreground400,
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        backgroundColor: colors.background800.withValues(alpha: 0.5),
        foregroundColor: colors.foreground300,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.background700),
        ),
        minimumSize: const Size(48, 48),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.background700.withValues(alpha: 0.7),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 18,
              color: colors.foreground400,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.foreground300,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: colors.foreground500,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
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
