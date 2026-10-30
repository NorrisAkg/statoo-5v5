import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:remixicon/remixicon.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/initial_avatar.dart';
import '../../../core/widgets/primary_button.dart';
import '../../shared/application/shared_providers.dart';
import '../application/sessions_provider.dart';
import '../domain/goal_score_sync.dart';
import '../domain/participation.dart';
import '../domain/session.dart';
import '../domain/session_close_rules.dart';
import '../domain/session_summary.dart';
import '../domain/team_appearance.dart';
import 'add_late_players_bottom_sheet.dart';
import 'live_stats_panel.dart';
import 'session_celebration.dart';
import 'session_header.dart';
import 'session_team_colors.dart';

class SessionDetailScreen extends ConsumerStatefulWidget {
  const SessionDetailScreen({
    required this.sessionId,
    super.key,
  });

  final String sessionId;

  @override
  ConsumerState<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends ConsumerState<SessionDetailScreen> {
  Team _selectedTeamTab = Team.a;
  bool get _writable => ref.watch(canWriteSessionProvider((domain: 'sport', sessionId: widget.sessionId))).value ?? false;

  Future<bool> _sportMutation(Future<void> Function() operation) async {
    try {
      await operation();
      return true;
    } on Object catch (error) {
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error is StateError ? error.message : 'Modification impossible : $error'),
      )); }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionDetailProvider(widget.sessionId));
    final participantsAsync = ref.watch(sessionParticipantsProvider(widget.sessionId));
    final activeSessionId = ref.watch(activeSessionIdProvider).value;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Remix.arrow_left_line),
          tooltip: 'Retour',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/seances');
            }
          },
        ),
        title: const Text('Détail séance'),
        actions: [
          sessionAsync.maybeWhen(
            data: (session) {
              if (!_writable || session == null || session.status != SessionStatus.draft || session.id != activeSessionId) {
                return const SizedBox.shrink();
              }
              final participants = participantsAsync.value;
              return IconButton(
                icon: const Icon(Remix.stop_circle_line),
                tooltip: 'Clôturer la séance',
                onPressed: participants == null
                    ? null
                    : () => unawaited(_confirmClose(context, ref, session, participants)),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: sessionAsync.when(
        data: (session) {
          if (session == null) {
            return const Center(child: Text('Séance introuvable.'));
          }

          final isDraft = session.status == SessionStatus.draft;
          final isCurrentActive = isDraft && (session.id == activeSessionId);
          final isWaitingDraft = isDraft && !isCurrentActive;

          return participantsAsync.when(
            data: (participants) => _buildContent(
              context,
              ref,
              session,
              participants,
              isCurrentActive: isCurrentActive,
              isWaitingDraft: isWaitingDraft,
              activeSessionId: activeSessionId,
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Erreur: $err')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erreur: $err')),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    Session session,
    List<SessionParticipantDetail> participants, {
    required bool isCurrentActive,
    required bool isWaitingDraft,
    required String? activeSessionId,
  }) {
    final isDraft = session.status == SessionStatus.draft;
    final teamAPlayers = participants.where((p) => p.participation.team == Team.a).toList();
    final teamBPlayers = participants.where((p) => p.participation.team == Team.b).toList();
    final teamCPlayers = participants.where((p) => p.participation.team == Team.c).toList();

    final goalsAssignedA = teamAPlayers.fold<int>(0, (sum, p) => sum + p.participation.goals);
    final goalsAssignedB = teamBPlayers.fold<int>(0, (sum, p) => sum + p.participation.goals);
    final scoreA = session.scoreA ?? 0;
    final scoreB = session.scoreB ?? 0;
    final isTournament = session.sessionType == SessionType.tournament3;
    final hasDiscrepancy = !isTournament &&
        ((goalsAssignedA + session.unassignedGoalsA != scoreA) ||
            (goalsAssignedB + session.unassignedGoalsB != scoreB));

    final formattedDate = DateFormat("EEE d MMM yyyy · HH'h'mm", 'fr_FR').format(session.playedAt);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeader(
          context,
          ref,
          session,
          formattedDate,
          isCurrentActive,
          participants: participants,
          formatLabel: (teamAPlayers.isNotEmpty || teamBPlayers.isNotEmpty)
              ? '${teamAPlayers.length}v${teamBPlayers.length}'
              : '5v5',
        ),
        if (isWaitingDraft) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.colors.background800,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colors.background700),
            ),
            child: Row(
              children: [
                Icon(Remix.time_line, color: context.colors.primary400, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    activeSessionId != null
                        ? 'Cette séance est en brouillon. Une autre séance est actuellement en cours.'
                        : 'Cette séance est prête en brouillon. Démarrez-la pour commencer à saisir les stats en direct.',
                    style: TextStyle(color: context.colors.foreground300, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (hasDiscrepancy && !isDraft) ...[
          const SizedBox(height: 16),
          _buildWarningBanner(
            context,
            scoreA: scoreA,
            scoreB: scoreB,
            teamAGoalsTotal: goalsAssignedA + session.unassignedGoalsA,
            teamBGoalsTotal: goalsAssignedB + session.unassignedGoalsB,
            unassignedA: session.unassignedGoalsA,
            unassignedB: session.unassignedGoalsB,
          ),
        ],
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text('Composition & Équipes', style: Theme.of(context).textTheme.titleMedium),
            if (isDraft && _writable)
              TextButton.icon(
                icon: const Icon(Remix.user_add_line, size: 16),
                label: const Text('Ajouter un joueur'),
                style: TextButton.styleFrom(
                  foregroundColor: context.colors.primary400,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _openAddLatePlayers(context, session, participants),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _buildTeamsSection(context, ref, session, teamAPlayers, teamBPlayers, teamCPlayers, isCurrentActive && _writable),
        if (isDraft && _writable) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Remix.user_add_line, size: 16),
            label: const Text('Ajouter des joueurs (retardataires)'),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.colors.primary400,
              side: BorderSide(color: context.colors.primary500.withValues(alpha: 0.35)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => _openAddLatePlayers(context, session, participants),
          ),
        ],
        const SizedBox(height: 24),
        OutlinedButton.icon(onPressed: () => context.push('/seances/${session.id}/finances'),
          icon: const Icon(Remix.wallet_line), label: const Text('Point financier')),
        const SizedBox(height: 16),
        if (_writable) _buildActions(
          context,
          ref,
          session,
          participants,
          isCurrentActive: isCurrentActive,
          isWaitingDraft: isWaitingDraft,
          activeSessionId: activeSessionId,
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    Session session,
    String formattedDate,
    bool isCurrentActive, {
    required String formatLabel,
    required List<SessionParticipantDetail> participants,
  }) {
    return SessionHeader(
      session: session,
      participants: participants,
      formattedDate: formattedDate,
      formatLabel: formatLabel,
      isCurrentActive: isCurrentActive,
      canEdit: false,
      tournamentBoard: session.sessionType == SessionType.tournament3
          ? LiveWinsBoard(session: session, editable: isCurrentActive && _writable)
          : null,
      onScoreIncrement: (team, delta) {
        unawaited(_sportMutation(() => ref.read(sessionsControllerProvider).incrementScore(
          sessionId: session.id,
          team: team,
          delta: delta,
        )));
      },
    );
  }
  Widget _buildWarningBanner(
    BuildContext context, {
    required int scoreA,
    required int scoreB,
    required int teamAGoalsTotal,
    required int teamBGoalsTotal,
    required int unassignedA,
    required int unassignedB,
  }) {
    final diffA = teamAGoalsTotal != scoreA;
    final diffB = teamBGoalsTotal != scoreB;
    final details = <String>[];
    if (diffA) {
      final unassignedText = unassignedA > 0 ? ' (dont $unassignedA CSC/non attribué)' : '';
      details.add('Équipe A : $teamAGoalsTotal but(s)$unassignedText pour $scoreA au score');
    }
    if (diffB) {
      final unassignedText = unassignedB > 0 ? ' (dont $unassignedB CSC/non attribué)' : '';
      details.add('Équipe B : $teamBGoalsTotal but(s)$unassignedText pour $scoreB au score');
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Remix.error_warning_line, color: context.colors.warning, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Avertissement : écart entre buts et score',
                  style: TextStyle(color: context.colors.warning, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  details.join(' · '),
                  style: TextStyle(color: context.colors.warning, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamsSection(
    BuildContext context,
    WidgetRef ref,
    Session session,
    List<SessionParticipantDetail> teamAPlayers,
    List<SessionParticipantDetail> teamBPlayers,
    List<SessionParticipantDetail> teamCPlayers,
    bool isCurrentActive,
  ) {
    final isTournament = session.sessionType == SessionType.tournament3;

    if (session.id == ref.watch(activeSessionIdProvider).value && session.status == SessionStatus.draft) {
      return LiveStatsPanel(session: session, players: [...teamAPlayers, ...teamBPlayers, ...teamCPlayers], editable: isCurrentActive);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTeamTabButton(
                context,
                title: session.teamName(Team.a),
                playerCount: teamAPlayers.length,
                color: session.teamColor(context, Team.a),
                textColor: session.teamColor(context, Team.a),
                isSelected: _selectedTeamTab == Team.a,
                onTap: () => setState(() => _selectedTeamTab = Team.a),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildTeamTabButton(
                context,
                title: session.teamName(Team.b),
                playerCount: teamBPlayers.length,
                color: session.teamColor(context, Team.b),
                textColor: session.teamColor(context, Team.b),
                isSelected: _selectedTeamTab == Team.b,
                onTap: () => setState(() => _selectedTeamTab = Team.b),
              ),
            ),
            if (isTournament) ...[
              const SizedBox(width: 8),
              Expanded(
                child: _buildTeamTabButton(
                  context,
                  title: session.teamName(Team.c),
                  playerCount: teamCPlayers.length,
                  color: session.teamColor(context, Team.c),
                  textColor: session.teamColor(context, Team.c),
                  isSelected: _selectedTeamTab == Team.c,
                  onTap: () => setState(() => _selectedTeamTab = Team.c),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _selectedTeamTab == Team.a
              ? _buildTeamCard(
                  key: const ValueKey('team_a_card'),
                  context,
                  ref,
                  session,
                  session.teamName(Team.a),
                  session.teamColor(context, Team.a),
                  Team.a,
                  teamAPlayers,
                  isCurrentActive,
                )
              : _selectedTeamTab == Team.b
                  ? _buildTeamCard(
                      key: const ValueKey('team_b_card'),
                      context,
                      ref,
                      session,
                      session.teamName(Team.b),
                      session.teamColor(context, Team.b),
                      Team.b,
                      teamBPlayers,
                      isCurrentActive,
                    )
                  : _buildTeamCard(
                      key: const ValueKey('team_c_card'),
                      context,
                      ref,
                      session,
                      session.teamName(Team.c),
                      session.teamColor(context, Team.c),
                      Team.c,
                      teamCPlayers,
                      isCurrentActive,
                    ),
        ),
      ],
    );
  }

  Widget _buildTeamTabButton(
    BuildContext context, {
    required String title,
    required int playerCount,
    required Color color,
    required Color textColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : context.colors.background900,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : context.colors.background700,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: isSelected ? color : color.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? context.colors.foreground50 : context.colors.foreground400,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? color.withValues(alpha: 0.25) : context.colors.background800,
                borderRadius: BorderRadius.circular(9999),
              ),
              child: Text(
                '$playerCount',
                style: TextStyle(
                  color: isSelected ? textColor : context.colors.foreground500,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamCard(
    BuildContext context,
    WidgetRef ref,
    Session session,
    String title,
    Color color,
    Team team,
    List<SessionParticipantDetail> players,
    bool isCurrentActive, {
    Key? key,
  }) {
    final unassigned = team == Team.a
        ? session.unassignedGoalsA
        : (team == Team.b ? session.unassignedGoalsB : session.unassignedGoalsC);
    return AppCard(
      key: key,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
              const SizedBox(width: 8),
              Flexible(child: Text('${players.length} joueurs', style: TextStyle(color: context.colors.foreground400, fontSize: 13))),
            ],
          ),
          const SizedBox(height: 12),
          if (players.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Aucun joueur assigné', style: TextStyle(color: context.colors.foreground500, fontSize: 13)),
            )
          else
            ...players.map((p) => _buildPlayerRow(context, ref, session, p, color, isCurrentActive)),
          if (unassigned > 0 || isCurrentActive) ...[
            const Divider(height: 24),
            _buildUnassignedGoalsRow(context, ref, session, team, unassigned, color, isCurrentActive),
          ],
        ],
      ),
    );
  }

  Widget _buildUnassignedGoalsRow(
    BuildContext context,
    WidgetRef ref,
    Session session,
    Team team,
    int unassigned,
    Color teamColor,
    bool isCurrentActive,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: teamColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Remix.football_line, size: 16, color: teamColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('CSC adverse / Non attribué', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(
                  'Buts pour cette équipe sans joueur assigné',
                  style: TextStyle(color: context.colors.foreground500, fontSize: 11),
                ),
              ],
            ),
          ),
          if (isCurrentActive) ...[
            IconButton(
              tooltip: 'Diminuer les buts CSC / non attribués',
              icon: const Icon(Remix.subtract_line, size: 16),
              color: context.colors.foreground400,
              onPressed: unassigned > 0
                  ? () {
                      final newA = team == Team.a ? unassigned - 1 : null;
                      final newB = team == Team.b ? unassigned - 1 : null;
                      unawaited(
                        _sportMutation(() => ref.read(sessionsControllerProvider).updateUnassignedGoals(
                          sessionId: session.id,
                          unassignedGoalsA: newA,
                          unassignedGoalsB: newB,
                        )),
                      );
                    }
                  : null,
            ),
            Text(
              '$unassigned',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            IconButton(
              tooltip: 'Ajouter un but CSC / non attribué',
              icon: const Icon(Remix.add_line, size: 16),
              color: teamColor,
              onPressed: () {
                final newA = team == Team.a ? unassigned + 1 : null;
                final newB = team == Team.b ? unassigned + 1 : null;
                unawaited(
                  _sportMutation(() => ref.read(sessionsControllerProvider).updateUnassignedGoals(
                    sessionId: session.id,
                    unassignedGoalsA: newA,
                    unassignedGoalsB: newB,
                  )),
                );
              },
            ),
          ] else if (unassigned > 0) ...[
            _buildStatPill(context, '$unassigned', Remix.football_line, context.colors.foreground200),
          ],
        ],
      ),
    );
  }

  Widget _buildPlayerRow(
    BuildContext context,
    WidgetRef ref,
    Session session,
    SessionParticipantDetail item,
    Color teamColor,
    bool isCurrentActive,
  ) {
    final part = item.participation;

    return InkWell(
      onTap: isCurrentActive ? () => _editPlayerStats(context, ref, session, item) : null,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            InitialAvatar(
              initial: item.playerName.isNotEmpty ? item.playerName[0].toUpperCase() : '?',
              baseColor: context.colors.foreground300,
              size: 28,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.playerName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  if (item.playerNickname != null)
                    Text('« ${item.playerNickname} »', style: TextStyle(color: context.colors.foreground500, fontSize: 11)),
                ],
              ),
            ),
            if (part.goals > 0)
              _buildStatPill(context, '${part.goals}', Remix.football_line, context.colors.foreground200),
            if (part.assists > 0)
              _buildStatPill(context, '${part.assists}', Remix.arrow_right_up_line, context.colors.accent400),
            if (part.yellowCards > 0)
              _buildStatPill(context, '${part.yellowCards}', null, context.colors.card, isCard: true),
            if (part.redCards > 0)
              _buildStatPill(context, '${part.redCards}', null, context.colors.danger, isCard: true),
            if (isCurrentActive) ...[
              const SizedBox(width: 8),
              Icon(Remix.edit_2_line, size: 16, color: context.colors.foreground500),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatPill(BuildContext context, String val, IconData? icon, Color color, {bool isCard = false}) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(val, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(width: 3),
          if (icon != null) Icon(icon, color: color, size: 13),
          if (isCard)
            Container(
              width: 9,
              height: 12,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
            ),
        ],
      ),
    );
  }

  /// Tells whether saving [goalDelta] more goals for the player moves the team score.
  /// Mirrors the repository rule: goals already in the score but without a scorer
  /// are consumed first, and removing a goal never lowers the score.
  String? _scoreImpactMessage(
    WidgetRef ref,
    Session session,
    SessionParticipantDetail item,
    int goalDelta,
  ) {
    if (session.sessionType == SessionType.tournament3 || goalDelta == 0) return null;
    final team = item.participation.team;
    if (team == Team.c) return null;
    final label = team == Team.a ? 'A' : 'B';
    if (goalDelta < 0) return "Le score de l'Équipe $label ne change pas.";

    final participants = ref.read(sessionParticipantsProvider(session.id)).value ?? const [];
    final assigned = participants
        .where((p) => p.participation.team == team)
        .fold<int>(0, (sum, p) => sum + p.participation.goals);
    final score = (team == Team.a ? session.scoreA : session.scoreB) ?? 0;
    final unassigned = team == Team.a ? session.unassignedGoalsA : session.unassignedGoalsB;
    final increase = scoreIncreaseForAttributedGoals(
      score: score,
      assignedGoals: assigned,
      unassignedGoals: unassigned,
      added: goalDelta,
    );
    if (increase == 0) return 'Ces buts sont déjà comptés dans le score.';
    return "Le score de l'Équipe $label passera de $score à ${score + increase}.";
  }

  void _editPlayerStats(
    BuildContext context,
    WidgetRef ref,
    Session session,
    SessionParticipantDetail item,
  ) {
    final sessionId = session.id;
    int goals = item.participation.goals;
    int assists = item.participation.assists;
    int yellowCards = item.participation.yellowCards;
    int redCards = item.participation.redCards;
    final initialGoals = goals;

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: context.colors.background900,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              final goalDelta = goals - initialGoals;
              final scoreImpact = _scoreImpactMessage(ref, session, item, goalDelta);
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Stats de ${item.playerName}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          tooltip: 'Fermer',
                          icon: const Icon(Remix.close_line),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildCounterRow(
                      context,
                      label: 'Buts',
                      icon: Remix.football_line,
                      value: goals,
                      onChanged: (v) => setModalState(() => goals = v),
                    ),
                    const SizedBox(height: 12),
                    _buildCounterRow(
                      context,
                      label: 'Passes décisives',
                      icon: Remix.arrow_right_up_line,
                      value: assists,
                      onChanged: (v) => setModalState(() => assists = v),
                    ),
                    const SizedBox(height: 12),
                    _buildCounterRow(
                      context,
                      label: 'Cartons jaunes',
                      icon: null,
                      isYellowCard: true,
                      value: yellowCards,
                      onChanged: (v) => setModalState(() => yellowCards = v),
                    ),
                    const SizedBox(height: 12),
                    _buildCounterRow(
                      context,
                      label: 'Cartons rouges',
                      icon: null,
                      isRedCard: true,
                      value: redCards,
                      onChanged: (v) => setModalState(() => redCards = v),
                    ),
                    if (scoreImpact != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Remix.information_line, size: 16, color: context.colors.primary400),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              scoreImpact,
                              style: TextStyle(color: context.colors.foreground400, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: 'Enregistrer les stats',
                      onPressed: () async {
                        final saved = await _sportMutation(() => ref.read(sessionsControllerProvider).updateParticipationStats(
                          sessionId: sessionId,
                          participationId: item.participation.id,
                          goals: goals,
                          assists: assists,
                          yellowCards: yellowCards,
                          redCards: redCards,
                        ));
                        if (saved && context.mounted) Navigator.pop(ctx);
                      },
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Remix.arrow_left_right_line, size: 16),
                      label: Text('Basculer vers Équipe ${item.participation.team == Team.a ? 'B' : 'A'}'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        try {
                          await ref.read(sessionsControllerProvider).switchPlayerTeam(
                            sessionId: sessionId,
                            participationId: item.participation.id,
                            currentTeam: item.participation.team,
                          );
                        } on Object catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(e is StateError ? e.message : 'Erreur: $e'),
                                backgroundColor: context.colors.danger,
                              ),
                            );
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      icon: Icon(Remix.user_unfollow_line, size: 16, color: context.colors.danger),
                      label: Text(
                        'Retirer de la feuille de match',
                        style: TextStyle(color: context.colors.danger, fontSize: 13),
                      ),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (dialogCtx) => AlertDialog(
                            title: Text('Retirer ${item.playerName} ?'),
                            content: Text(
                              (item.participation.goals > 0 || item.participation.assists > 0)
                                  ? 'Ce joueur a des statistiques enregistrées (${item.participation.goals} but(s), ${item.participation.assists} passe(s)). Elles seront supprimées.'
                                  : 'Ce joueur sera retiré de la feuille de match de cette séance.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogCtx, false),
                                child: const Text('Annuler'),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(backgroundColor: context.colors.danger),
                                onPressed: () => Navigator.pop(dialogCtx, true),
                                child: const Text('Retirer'),
                              ),
                            ],
                          ),
                        );
                        if (confirm != true) return;
                        if (ctx.mounted) Navigator.pop(ctx);
                        try {
                          await ref.read(sessionsControllerProvider).removeParticipation(
                            sessionId: sessionId,
                            participationId: item.participation.id,
                            playerTeam: item.participation.team,
                          );
                        } on Object catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(e is StateError ? e.message : 'Erreur: $e'),
                                backgroundColor: context.colors.danger,
                              ),
                            );
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCounterRow(
    BuildContext context, {
    required String label,
    required IconData? icon,
    required int value,
    required ValueChanged<int> onChanged,
    bool isYellowCard = false,
    bool isRedCard = false,
  }) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: context.colors.foreground400),
          const SizedBox(width: 8),
        ] else if (isYellowCard) ...[
          Container(width: 12, height: 16, decoration: BoxDecoration(color: context.colors.card, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
        ] else if (isRedCard) ...[
          Container(width: 12, height: 16, decoration: BoxDecoration(color: context.colors.danger, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
        ],
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
        IconButton(
          tooltip: 'Diminuer $label',
          icon: const Icon(Remix.subtract_line),
          color: context.colors.foreground400,
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
        ),
        Text('$value', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        IconButton(
          tooltip: 'Augmenter $label',
          icon: const Icon(Remix.add_line),
          color: context.colors.primary500,
          onPressed: () => onChanged(value + 1),
        ),
      ],
    );
  }

  Widget _buildActions(
    BuildContext context,
    WidgetRef ref,
    Session session,
    List<SessionParticipantDetail> participants, {
    required bool isCurrentActive,
    required bool isWaitingDraft,
    required String? activeSessionId,
  }) {
    return Column(
      children: [
        if (isWaitingDraft) ...[
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: 'Démarrer la séance',
              icon: Remix.play_fill,
              onPressed: () => unawaited(_handleStartWaitingDraft(context, ref, session.id)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              icon: const Icon(Remix.delete_bin_line, size: 18),
              label: const Text('Supprimer le brouillon'),
              style: TextButton.styleFrom(
                foregroundColor: context.colors.danger,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => unawaited(_confirmDelete(context, ref, true)),
            ),
          ),
        ] else if (isCurrentActive) ...[
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: 'Clôturer la séance',
              icon: Remix.check_line,
              onPressed: () => unawaited(_confirmClose(context, ref, session, participants)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              icon: const Icon(Remix.delete_bin_line, size: 18),
              label: const Text('Supprimer ce match'),
              style: TextButton.styleFrom(
                foregroundColor: context.colors.danger,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => unawaited(_confirmDelete(context, ref, true)),
            ),
          ),
        ] else ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Remix.restart_line, size: 18),
              label: const Text('Rouvrir la séance'),
              onPressed: () => unawaited(_confirmReopen(context, ref)),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.colors.foreground50,
                side: BorderSide(color: context.colors.background700),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              icon: const Icon(Remix.delete_bin_line, size: 18),
              label: const Text('Supprimer la séance'),
              style: TextButton.styleFrom(
                foregroundColor: context.colors.danger,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => unawaited(_confirmDelete(context, ref, false)),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _handleStartWaitingDraft(BuildContext context, WidgetRef ref, String targetSessionId) async {
    final currentActiveId = ref.read(activeSessionIdProvider).value;
    if (currentActiveId != null && currentActiveId != targetSessionId) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Une séance est déjà en cours'),
          content: const Text(
            "Il ne peut y avoir qu'une seule séance en cours à la fois. Clôturez ou annulez la séance en cours avant de pouvoir débuter celle-ci.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Compris'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                unawaited(context.push('/seances/$currentActiveId'));
              },
              child: const Text('Voir la séance en cours'),
            ),
          ],
        ),
      );
      return;
    }

    var started = false;
    await _sportMutation(() async { started = await ref.read(sessionsControllerProvider).startSession(targetSessionId); });
    if (context.mounted && started) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Séance démarrée ! Saisie en direct activée.')),
      );
    }
  }

  Future<void> _confirmClose(
    BuildContext context,
    WidgetRef ref,
    Session session,
    List<SessionParticipantDetail> participants,
  ) async {
    final controller = ref.read(sessionsControllerProvider);
    final isTournament = session.sessionType == SessionType.tournament3;

    final teamAPlayers = participants.where((p) => p.participation.team == Team.a).toList();
    final teamBPlayers = participants.where((p) => p.participation.team == Team.b).toList();
    final teamCPlayers = participants.where((p) => p.participation.team == Team.c).toList();

    final goalsA = teamAPlayers.fold<int>(0, (s, p) => s + p.participation.goals);
    final goalsB = teamBPlayers.fold<int>(0, (s, p) => s + p.participation.goals);
    final goalsC = teamCPlayers.fold<int>(0, (s, p) => s + p.participation.goals);

    final assistsA = teamAPlayers.fold<int>(0, (s, p) => s + p.participation.assists);
    final assistsB = teamBPlayers.fold<int>(0, (s, p) => s + p.participation.assists);
    final assistsC = teamCPlayers.fold<int>(0, (s, p) => s + p.participation.assists);

    final blockers = closeBlockers(
      session: session,
      teamACount: teamAPlayers.length,
      teamBCount: teamBPlayers.length,
      teamCCount: isTournament ? teamCPlayers.length : null,
      playerGoalsA: goalsA,
      playerGoalsB: goalsB,
      playerGoalsC: goalsC,
      playerAssistsA: assistsA,
      playerAssistsB: assistsB,
      playerAssistsC: assistsC,
      participations: participants.map((p) => p.participation),
    );

    if (blockers.contains(CloseBlocker.unevenTeams)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_closeBlockerMessage(CloseBlocker.unevenTeams, session))),
      );
      return;
    }

    if (blockers.contains(CloseBlocker.missingScore)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_closeBlockerMessage(CloseBlocker.missingScore, session))),
      );
      return;
    }

    if (blockers.contains(CloseBlocker.goalsMismatch)) {
      final scoreA = session.scoreA ?? 0;
      final scoreB = session.scoreB ?? 0;
      final totalA = goalsA + session.unassignedGoalsA;
      final totalB = goalsB + session.unassignedGoalsB;
      final details = <String>[];
      if (totalA != scoreA) {
        details.add('Équipe A : $totalA but(s) attribués vs $scoreA au score');
      }
      if (totalB != scoreB) {
        details.add('Équipe B : $totalB but(s) attribués vs $scoreB au score');
      }
      if (isTournament && session.scoreC != null) {
        final scoreC = session.scoreC ?? 0;
        final totalC = goalsC + session.unassignedGoalsC;
        if (totalC != scoreC) {
          details.add('Équipe C : $totalC but(s) attribués vs $scoreC au score');
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Clôture impossible : ${details.join(' · ')}. '
            'Corrigez les buts des joueurs ou le score avant de clôturer.',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    if (blockers.contains(CloseBlocker.assistsExceedGoals)) {
      final details = <String>[];
      if (assistsA > goalsA) {
        details.add('Équipe A : $assistsA passe(s) pour $goalsA but(s) marqué(s)');
      }
      if (assistsB > goalsB) {
        details.add('Équipe B : $assistsB passe(s) pour $goalsB but(s) marqué(s)');
      }
      if (isTournament && assistsC > goalsC) {
        details.add('Équipe C : $assistsC passe(s) pour $goalsC but(s) marqué(s)');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Clôture impossible : ${details.join(' · ')}. '
            "Le nombre de passes décisives d'une équipe ne peut pas dépasser ses buts marqués.",
          ),
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    if (blockers.contains(CloseBlocker.selfAssist)) {
      final culprits = participants.where((p) {
        final teamGoals = switch (p.participation.team) {
          Team.a => goalsA,
          Team.b => goalsB,
          Team.c => goalsC,
        };
        return p.participation.goals + p.participation.assists > teamGoals;
      }).map((p) {
        final teamGoals = switch (p.participation.team) {
          Team.a => goalsA,
          Team.b => goalsB,
          Team.c => goalsC,
        };
        return '${p.playerName} (${p.participation.goals} but(s), ${p.participation.assists} passe(s) pour $teamGoals but(s) de son équipe)';
      }).toList();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Clôture impossible : auto-passe détectée pour ${culprits.join(', ')}. '
            'Un joueur ne peut pas se faire une passe décisive à lui-même.',
          ),
          duration: const Duration(seconds: 6),
        ),
      );
      return;
    }

    final String outcome;
    if (isTournament) {
      final res = computeTournamentResult(session.winsA, session.winsB, session.winsC);
      outcome = switch (res) {
        MatchResult.teamA => 'Vainqueur : Équipe A (${session.winsA} victoires) — 3 pts',
        MatchResult.teamB => 'Vainqueur : Équipe B (${session.winsB} victoires) — 3 pts',
        MatchResult.teamC => 'Vainqueur : Équipe C (${session.winsC} victoires) — 3 pts',
        MatchResult.drawAB =>
          'Égalité : Équipes A et B (${session.winsA} victoires) — ${session.drawPoints} pt(s) chacune',
        MatchResult.drawBC =>
          'Égalité : Équipes B et C (${session.winsB} victoires) — ${session.drawPoints} pt(s) chacune',
        MatchResult.drawAC =>
          'Égalité : Équipes A et C (${session.winsA} victoires) — ${session.drawPoints} pt(s) chacune',
        MatchResult.drawAll =>
          'Égalité à trois (${session.winsA} victoires) — ${session.drawPoints} pt(s) chacune',
        _ => 'Points calculés pour le classement général',
      };
    } else {
      final scoreA = session.scoreA ?? 0;
      final scoreB = session.scoreB ?? 0;
      outcome = scoreA > scoreB
          ? 'Victoire Équipe A ($scoreA – $scoreB)'
          : scoreB > scoreA
              ? 'Victoire Équipe B ($scoreA – $scoreB)'
              : 'Match nul ($scoreA – $scoreB)';
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clôturer la séance ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colors.background800,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    outcome,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    session.isRanked
                        ? 'Séance classée · Intégrée au classement général'
                        : 'Séance amicale · Statistiques seules (hors classement)',
                    style: TextStyle(color: context.colors.foreground400, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Une fois clôturée, la séance mettra à jour les classements.',
              style: TextStyle(color: context.colors.foreground300, fontSize: 13),
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
            child: const Text('Clôturer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    String message;
    var closed = false;
    try {
      final remaining = await controller.closeSession(session.id);
      closed = remaining.isEmpty;
      message = remaining.isEmpty
          ? 'Séance clôturée avec succès !'
          : _closeBlockerMessage(remaining.first, session);
    } on SessionCloseException {
      message = "La séance n'a pas pu être clôturée. Rechargez-la et réessayez.";
    } on Object catch (e) {
      message = 'Erreur lors de la clôture : $e';
    }
    if (!context.mounted) return;
    if (closed) {
      await showDialog<void>(context: context, builder: (_) => SessionCelebration(session: session));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _closeBlockerMessage(CloseBlocker blocker, Session session) => switch (blocker) {
    CloseBlocker.missingScore => session.sessionType == SessionType.tournament3
        ? 'Clôture impossible : au moins une victoire doit être enregistrée.'
        : 'Clôture impossible : renseignez le score de la séance.',
    CloseBlocker.unevenTeams => session.sessionType == SessionType.tournament3
        ? "Clôture impossible : l'écart d'effectif entre les 3 équipes dépasse 1 et l'option équipes inégales n'est pas activée."
        : "Clôture impossible : l'écart d'effectif dépasse 1 et l'option équipes inégales n'est pas activée.",
    CloseBlocker.goalsMismatch =>
      'Clôture impossible : le total des buts attribués ne correspond pas au score. Corrigez avant de clôturer.',
    CloseBlocker.assistsExceedGoals =>
      'Clôture impossible : le nombre de passes décisives dépasse le nombre de buts marqués par les joueurs.',
    CloseBlocker.selfAssist =>
      'Clôture impossible : un joueur ne peut pas se faire de passe décisive à lui-même.',
    CloseBlocker.duplicatePlayer =>
      'Clôture impossible : un même joueur est inscrit plusieurs fois dans la séance.',
  };

  Future<void> _confirmReopen(BuildContext context, WidgetRef ref) async {
    final activeId = ref.read(activeSessionIdProvider).value;
    final isAnotherActive = activeId != null && activeId != widget.sessionId;

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAnotherActive ? 'Une séance est déjà en cours' : 'Modifier cette séance ?'),
        content: Text(
          isAnotherActive
              ? 'Une autre séance est actuellement en cours. Cette séance sera rouverte en tant que brouillon en attente et sortira temporairement du classement.'
              : "Cette séance repassera en mode brouillon pour vous permettre d'ajuster le score, les effectifs ou les statistiques. Elle sortira temporairement du classement jusqu'à sa reclôture.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rouvrir pour modifier'),
          ),
        ],
      ),
    );
    if (proceed != true) return;

    final reopened = await _sportMutation(() => ref.read(sessionsControllerProvider).reopenSession(widget.sessionId));
    if (!reopened) return;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Séance rouverte en brouillon pour modification.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, bool isDraft) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isDraft ? 'Supprimer ce match en cours ?' : 'Supprimer la séance ?'),
        content: Text(
          isDraft
              ? 'Ce match en cours sera définitivement supprimé. Les scores et statistiques saisis seront perdus.'
              : 'Cette séance et toutes ses participations seront définitivement supprimées du classement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final deleted = await _sportMutation(() => ref.read(sessionsControllerProvider).deleteSession(widget.sessionId));
      if (!deleted) return;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Séance supprimée.')),
        );
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/seances');
        }
      }
    }
  }

  void _openAddLatePlayers(
    BuildContext context,
    Session session,
    List<SessionParticipantDetail> participants,
  ) {
    final teamAPlayers = participants.where((p) => p.participation.team == Team.a).toList();
    final teamBPlayers = participants.where((p) => p.participation.team == Team.b).toList();
    final teamCPlayers = participants.where((p) => p.participation.team == Team.c).toList();
    final alreadyAssignedIds = participants.map((p) => p.participation.playerId).toSet();

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => AddLatePlayersBottomSheet(
          sessionId: session.id,
          currentTeamACount: teamAPlayers.length,
          currentTeamBCount: teamBPlayers.length,
          currentTeamCCount: session.sessionType == SessionType.tournament3 ? teamCPlayers.length : null,
          alreadyAssignedPlayerIds: alreadyAssignedIds,
          allowUnevenTeams: session.allowUnevenTeams,
        ),
      ),
    );
  }
}
