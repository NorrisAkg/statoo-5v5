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
import '../../../core/widgets/status_badge.dart';
import '../application/sessions_provider.dart';
import '../domain/participation.dart';
import '../domain/session.dart';
import '../domain/session_close_rules.dart';
import '../domain/session_summary.dart';
import 'add_late_players_bottom_sheet.dart';

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

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionDetailProvider(widget.sessionId));
    final participantsAsync = ref.watch(sessionParticipantsProvider(widget.sessionId));
    final activeSessionId = ref.watch(activeSessionIdProvider).value;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Remix.arrow_left_line),
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
              if (session == null) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Remix.delete_bin_line),
                tooltip: 'Supprimer',
                color: context.colors.danger,
                onPressed: () => unawaited(_confirmDelete(context, ref, session.status == SessionStatus.draft)),
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

    final goalsAssignedA = teamAPlayers.fold<int>(0, (sum, p) => sum + p.participation.goals);
    final goalsAssignedB = teamBPlayers.fold<int>(0, (sum, p) => sum + p.participation.goals);
    final scoreA = session.scoreA ?? 0;
    final scoreB = session.scoreB ?? 0;
    final hasDiscrepancy = (goalsAssignedA + session.unassignedGoalsA != scoreA) ||
        (goalsAssignedB + session.unassignedGoalsB != scoreB);

    final formattedDate = DateFormat("EEE d MMM yyyy · HH'h'mm", 'fr_FR').format(session.playedAt);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeader(context, ref, session, formattedDate, isCurrentActive, isWaitingDraft, scoreA, scoreB),
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
          _buildWarningBanner(context, goalsAssignedA + goalsAssignedB, scoreA + scoreB),
        ],
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Composition & Équipes', style: Theme.of(context).textTheme.titleMedium),
            if (isDraft)
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
        _buildTeamsSection(context, ref, session, teamAPlayers, teamBPlayers, isCurrentActive),
        if (isDraft) ...[
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
        _buildActions(
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
    bool isCurrentActive,
    bool isWaitingDraft,
    int scoreA,
    int scoreB,
  ) {
    return AppCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isCurrentActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.colors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(9999),
                    border: Border.all(color: context.colors.warning.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    'EN COURS',
                    style: TextStyle(
                      color: context.colors.warning,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else if (isWaitingDraft)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.colors.background800,
                    borderRadius: BorderRadius.circular(9999),
                    border: Border.all(color: context.colors.foreground600),
                  ),
                  child: Text(
                    'BROUILLON (EN ATTENTE)',
                    style: TextStyle(
                      color: context.colors.foreground300,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                const StatusBadge(status: BadgeStatus.closed),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: context.colors.background800,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: const Text('5v5', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              ),
              if (!session.isRanked) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.colors.background800,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: const Text('AMICAL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            formattedDate,
            style: TextStyle(color: context.colors.foreground400, fontSize: 14),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTeamScore(
                context,
                ref,
                title: 'Équipe A',
                score: session.scoreA,
                color: context.colors.accent500,
                isDraft: isCurrentActive,
                onScoreChanged: (newScore) {
                  unawaited(
                    ref.read(sessionsControllerProvider).updateScore(
                      sessionId: session.id,
                      scoreA: newScore,
                      scoreB: scoreB,
                    ),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  '-',
                  style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: context.colors.foreground600),
                ),
              ),
              _buildTeamScore(
                context,
                ref,
                title: 'Équipe B',
                score: session.scoreB,
                color: context.colors.secondary500,
                isDraft: isCurrentActive,
                onScoreChanged: (newScore) {
                  unawaited(
                    ref.read(sessionsControllerProvider).updateScore(
                      sessionId: session.id,
                      scoreA: scoreA,
                      scoreB: newScore,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTeamScore(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required int? score,
    required Color color,
    required bool isDraft,
    required ValueChanged<int> onScoreChanged,
  }) {
    return Column(
      children: [
        Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        // Null = not entered yet: showing 0 would pass an unrecorded score off as a real 0.
        Text(score?.toString() ?? '–', style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900)),
        if (isDraft) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Remix.subtract_line),
                color: context.colors.foreground400,
                onPressed: score != null && score > 0 ? () => onScoreChanged(score - 1) : null,
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Remix.add_line),
                color: color,
                onPressed: () => onScoreChanged((score ?? 0) + 1),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildWarningBanner(BuildContext context, int totalPlayerGoals, int totalScoreGoals) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Remix.error_warning_line, color: context.colors.warning, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Avertissement : la somme des buts des joueurs ($totalPlayerGoals) ne correspond pas au score du match ($totalScoreGoals).',
              style: TextStyle(color: context.colors.warning, fontSize: 13),
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
    bool isCurrentActive,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTeamTabButton(
                context,
                title: 'Équipe A',
                playerCount: teamAPlayers.length,
                color: context.colors.accent500,
                textColor: context.colors.accent400,
                isSelected: _selectedTeamTab == Team.a,
                onTap: () => setState(() => _selectedTeamTab = Team.a),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildTeamTabButton(
                context,
                title: 'Équipe B',
                playerCount: teamBPlayers.length,
                color: context.colors.secondary500,
                textColor: context.colors.secondary400,
                isSelected: _selectedTeamTab == Team.b,
                onTap: () => setState(() => _selectedTeamTab = Team.b),
              ),
            ),
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
                  'Équipe A',
                  context.colors.accent500,
                  teamAPlayers,
                  isCurrentActive,
                )
              : _buildTeamCard(
                  key: const ValueKey('team_b_card'),
                  context,
                  ref,
                  session,
                  'Équipe B',
                  context.colors.secondary500,
                  teamBPlayers,
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isSelected ? color : color.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? context.colors.foreground50 : context.colors.foreground400,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
    List<SessionParticipantDetail> players,
    bool isCurrentActive, {
    Key? key,
  }) {
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
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              Text('${players.length} joueurs', style: TextStyle(color: context.colors.foreground400, fontSize: 13)),
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
      onTap: isCurrentActive ? () => _editPlayerStats(context, ref, session.id, item) : null,
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

  void _editPlayerStats(
    BuildContext context,
    WidgetRef ref,
    String sessionId,
    SessionParticipantDetail item,
  ) {
    int goals = item.participation.goals;
    int assists = item.participation.assists;
    int yellowCards = item.participation.yellowCards;
    int redCards = item.participation.redCards;

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
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: 'Enregistrer les stats',
                      onPressed: () async {
                        await ref.read(sessionsControllerProvider).updateParticipationStats(
                          sessionId: sessionId,
                          participationId: item.participation.id,
                          goals: goals,
                          assists: assists,
                          yellowCards: yellowCards,
                          redCards: redCards,
                        );
                        if (context.mounted) Navigator.pop(ctx);
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
          icon: const Icon(Remix.subtract_line),
          color: context.colors.foreground400,
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
        ),
        Text('$value', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        IconButton(
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
              icon: const Icon(Remix.close_circle_line, size: 18),
              label: const Text('Annuler la séance'),
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

    final started = await ref.read(sessionsControllerProvider).startSession(targetSessionId);
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
    final blockers = closeBlockers(
      session: session,
      teamACount: participants.where((p) => p.participation.team == Team.a).length,
      teamBCount: participants.where((p) => p.participation.team == Team.b).length,
    );

    if (blockers.contains(CloseBlocker.unevenTeams)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_closeBlockerMessage(CloseBlocker.unevenTeams))),
      );
      return;
    }

    final neverScored = session.scoreA == null && session.scoreB == null;
    if (blockers.contains(CloseBlocker.missingScore) && !neverScored) {
      // Partial score row: offering 0-0 here would overwrite what was entered.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_closeBlockerMessage(CloseBlocker.missingScore))),
      );
      return;
    }

    final bool? confirmed;
    if (neverScored) {
      // An untouched score is not a 0-0: ask rather than guess.
      confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Score non saisi'),
          content: const Text(
            "Aucun score n'a été saisi pour cette séance. S'il s'agit d'un match nul 0 - 0, vous pouvez clôturer directement.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Saisir le score'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Clôturer à 0 - 0'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await controller.updateScore(sessionId: session.id, scoreA: 0, scoreB: 0);
      }
    } else {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Clôturer la séance ?'),
          content: const Text(
            'Les points du match seront calculés et intégrés au classement général et aux statistiques.',
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
    }

    if (confirmed != true) return;
    String message;
    try {
      final remaining = await controller.closeSession(session.id);
      message = remaining.isEmpty ? 'Séance clôturée avec succès !' : _closeBlockerMessage(remaining.first);
    } on SessionCloseException {
      message = "La séance n'a pas pu être clôturée. Rechargez-la et réessayez.";
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _closeBlockerMessage(CloseBlocker blocker) => switch (blocker) {
    CloseBlocker.missingScore => 'Clôture impossible : renseignez le score de la séance.',
    CloseBlocker.unevenTeams =>
      "Clôture impossible : l'écart d'effectif dépasse 1 et l'option équipes inégales n'est pas activée.",
  };

  Future<void> _confirmReopen(BuildContext context, WidgetRef ref) async {
    final activeId = ref.read(activeSessionIdProvider).value;
    if (activeId != null && activeId != widget.sessionId) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Une séance est déjà en cours'),
          content: const Text(
            'Une autre séance est actuellement en cours. Cette séance sera rouverte en tant que brouillon en attente.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Rouvrir en brouillon'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    await ref.read(sessionsControllerProvider).reopenSession(widget.sessionId);
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, bool isDraft) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isDraft ? 'Supprimer le brouillon ?' : 'Supprimer la séance ?'),
        content: Text(
          isDraft
              ? 'Ce brouillon sera définitivement supprimé.'
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
      await ref.read(sessionsControllerProvider).deleteSession(widget.sessionId);
      if (context.mounted) {
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
          alreadyAssignedPlayerIds: alreadyAssignedIds,
        ),
      ),
    );
  }
}
