import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/theme/app_colors.dart';
import '../../sessions/application/sessions_provider.dart';
import '../../sessions/domain/participation.dart';
import '../../sessions/domain/session.dart';
import '../../sessions/domain/session_summary.dart';
import '../../sessions/domain/team_appearance.dart';
import '../../sessions/presentation/session_team_colors.dart';

/// Compact result and session-only scorers for the home card.
class HomeSessionResult extends ConsumerWidget {
  const HomeSessionResult({required this.session, super.key});

  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final participants = ref.watch(sessionParticipantsProvider(session.id));
    final tournament = session.sessionType == SessionType.tournament3;
    final list = participants.asData?.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (tournament) ...[
          Text(
            'Tournoi · 3 équipes',
            style: TextStyle(color: context.colors.foreground400, fontSize: 12),
          ),
          const SizedBox(height: 12),
          for (final (index, team) in [Team.a, Team.b, Team.c].indexed) ...[
            if (index > 0)
              Divider(color: context.colors.background700, height: 24),
            _tournamentTeamBlock(context, team, list),
          ],
        ] else ...[
          Row(
            children: [
              Expanded(child: _teamIdentity(context, Team.a)),
              Expanded(child: _centralScore(context)),
              Expanded(child: _teamIdentity(context, Team.b)),
            ],
          ),
          if (_hasClassicScorers(list)) ...[
            const SizedBox(height: 14),
            Divider(color: context.colors.background700, height: 1),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _classicScorersColumn(context, Team.a, list)),
                const SizedBox(width: 16),
                Expanded(child: _classicScorersColumn(context, Team.b, list)),
              ],
            ),
          ],
        ],
        if (participants.isLoading || participants.hasError) ...[
          const SizedBox(height: 10),
          Text(
            participants.hasError
                ? 'Buteurs indisponibles'
                : 'Chargement des buteurs…',
            style: TextStyle(color: context.colors.foreground400, fontSize: 12),
          ),
        ],
      ],
    );
  }

  bool _hasClassicScorers(List<SessionParticipantDetail>? participants) {
    if (session.unassignedGoalsA > 0 || session.unassignedGoalsB > 0) {
      return true;
    }
    if (participants == null) return false;
    return participants.any(
      (p) =>
          p.participation.sessionId == session.id &&
          (p.participation.team == Team.a || p.participation.team == Team.b) &&
          p.participation.goals > 0,
    );
  }

  Widget _teamIdentity(BuildContext context, Team team) {
    final color = session.teamColor(context, team);
    return Column(
      children: [
        Text(
          session.teamName(team),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: 48,
          height: 54,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Remix.shield_fill, color: color, size: 34),
        ),
      ],
    );
  }

  Widget _centralScore(BuildContext context) {
    final scoreA = session.scoreA ?? 0;
    final scoreB = session.scoreB ?? 0;
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$scoreA',
              semanticsLabel: '$scoreA buts',
              style: TextStyle(
                color: context.colors.foreground50,
                fontSize: 34,
                fontWeight: FontWeight.w900,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '-',
                style: TextStyle(
                  color: context.colors.foreground400,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '$scoreB',
              semanticsLabel: '$scoreB buts',
              style: TextStyle(
                color: context.colors.foreground50,
                fontSize: 34,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _classicScorersColumn(
    BuildContext context,
    Team team,
    List<SessionParticipantDetail>? participants,
  ) {
    final color = session.teamColor(context, team);
    final scorers = _teamScorers(team, participants);
    final unassigned = _unassignedGoals(team);
    return Column(
      key: ValueKey('home-team-${team.name}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final scorer in scorers)
          _scorer(
            context,
            team,
            scorer.playerName,
            scorer.participation.goals,
            color,
            centered: true,
          ),
        if (unassigned > 0)
          _scorer(
            context,
            team,
            'Non attribués',
            unassigned,
            color,
            centered: true,
          ),
      ],
    );
  }

  Widget _tournamentTeamBlock(
    BuildContext context,
    Team team,
    List<SessionParticipantDetail>? participants,
  ) {
    final color = session.teamColor(context, team);
    final wins = switch (team) {
      Team.a => session.winsA,
      Team.b => session.winsB,
      Team.c => session.winsC,
    };
    final scorers = _teamScorers(team, participants);
    final unassigned = _unassignedGoals(team);
    final hasScorers = scorers.isNotEmpty || unassigned > 0;

    return Column(
      key: ValueKey('home-team-${team.name}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Remix.shield_fill, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                session.teamName(team),
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$wins V',
              semanticsLabel: '$wins victoires',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        if (hasScorers) ...[
          const SizedBox(height: 8),
          for (final scorer in scorers)
            _scorer(
              context,
              team,
              scorer.playerName,
              scorer.participation.goals,
              color,
            ),
          if (unassigned > 0)
            _scorer(context, team, 'Non attribués', unassigned, color),
        ],
      ],
    );
  }

  List<SessionParticipantDetail> _teamScorers(
    Team team,
    List<SessionParticipantDetail>? participants,
  ) {
    if (participants == null) return const [];
    final list = participants
        .where(
          (p) =>
              p.participation.sessionId == session.id &&
              p.participation.team == team &&
              p.participation.goals > 0,
        )
        .toList()
      ..sort((a, b) {
        final goals = b.participation.goals.compareTo(a.participation.goals);
        return goals != 0 ? goals : a.playerName.compareTo(b.playerName);
      });
    return list;
  }

  int _unassignedGoals(Team team) => switch (team) {
    Team.a => session.unassignedGoalsA,
    Team.b => session.unassignedGoalsB,
    Team.c => session.unassignedGoalsC,
  };

  Widget _scorer(
    BuildContext context,
    Team team,
    String name,
    int goals,
    Color color, {
    bool centered = false,
  }) {
    final label = '$goals ${goals == 1 ? 'but' : 'buts'}';
    return Padding(
      key: ValueKey('home-scorer-${team.name}-$name'),
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Semantics(
        label: '$name, $label, ${session.teamName(team)}',
        child: Wrap(
          alignment: centered ? WrapAlignment.center : WrapAlignment.start,
          spacing: 6,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              name,
              textAlign: centered ? TextAlign.center : TextAlign.start,
              style: TextStyle(color: context.colors.foreground300, fontSize: 12),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: _buildGoalIndicators(goals, color),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGoalIndicators(int goals, Color color) {
    if (goals <= 1) {
      return [Icon(Remix.football_fill, size: 14, color: color)];
    }
    if (goals == 2) {
      return [
        Icon(Remix.football_fill, size: 14, color: color),
        const SizedBox(width: 3),
        Icon(Remix.football_fill, size: 14, color: color),
      ];
    }
    return [
      Icon(Remix.football_fill, size: 14, color: color),
      const SizedBox(width: 4),
      Text(
        'x$goals',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ];
  }
}
