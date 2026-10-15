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
    final teams = [Team.a, Team.b, if (tournament) Team.c];
    final blocks = [
      for (final team in teams)
        _teamBlock(context, team, tournament, participants.asData?.value),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (tournament) ...[
          Text(
            'Tournoi · 3 équipes',
            style: TextStyle(color: context.colors.foreground400, fontSize: 12),
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < blocks.length; index++) ...[
            if (index > 0)
              Divider(color: context.colors.background700, height: 24),
            blocks[index],
          ],
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: blocks[0]),
              const SizedBox(width: 16),
              Expanded(child: blocks[1]),
            ],
          ),
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

  Widget _teamBlock(
    BuildContext context,
    Team team,
    bool tournament,
    List<SessionParticipantDetail>? participants,
  ) {
    final color = session.teamColor(context, team);
    final value = tournament
        ? switch (team) {
            Team.a => session.winsA,
            Team.b => session.winsB,
            Team.c => session.winsC,
          }
        : team == Team.a
        ? session.scoreA ?? 0
        : session.scoreB ?? 0;
    final name = Text(
      session.teamName(team),
      style: TextStyle(color: color, fontWeight: FontWeight.w600),
    );
    final score = Text(
      tournament ? '$value V' : '$value',
      semanticsLabel: tournament ? '$value victoires' : '$value buts',
      style: TextStyle(
        fontSize: tournament ? 18 : 28,
        fontWeight: FontWeight.w900,
      ),
    );
    final scorers =
        participants
            ?.where(
              (p) =>
                  p.participation.sessionId == session.id &&
                  p.participation.team == team &&
                  p.participation.goals > 0,
            )
            .toList()
          ?..sort((a, b) {
            final goals = b.participation.goals.compareTo(
              a.participation.goals,
            );
            return goals != 0 ? goals : a.playerName.compareTo(b.playerName);
          });
    final unassigned = switch (team) {
      Team.a => session.unassignedGoalsA,
      Team.b => session.unassignedGoalsB,
      Team.c => session.unassignedGoalsC,
    };
    return Column(
      key: ValueKey('home-team-${team.name}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (tournament)
          Row(
            children: [
              Expanded(child: name),
              const SizedBox(width: 12),
              score,
            ],
          )
        else ...[
          name,
          const SizedBox(height: 8),
          score,
        ],
        const SizedBox(height: 8),
        if (scorers != null) ...[
          for (final scorer in scorers)
            _scorer(
              context,
              scorer.playerName,
              scorer.participation.goals,
              color,
            ),
          if (unassigned > 0)
            _scorer(context, 'Non attribués', unassigned, color),
          if (scorers.isEmpty && unassigned == 0)
            Text(
              'Aucun but enregistré',
              style: TextStyle(
                color: context.colors.foreground400,
                fontSize: 12,
              ),
            ),
        ],
      ],
    );
  }

  Widget _scorer(BuildContext context, String name, int goals, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Wrap(
        spacing: 6,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            name,
            style: TextStyle(color: context.colors.foreground300, fontSize: 12),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Remix.football_fill, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                '$goals ${goals == 1 ? 'but' : 'buts'}',
                style: TextStyle(
                  color: context.colors.foreground300,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
