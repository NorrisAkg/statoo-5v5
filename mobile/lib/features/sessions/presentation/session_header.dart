import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/participation.dart';
import '../domain/session.dart';
import '../domain/session_summary.dart';
import '../domain/team_appearance.dart';
import 'session_team_colors.dart';

/// Scoreboard and scorers from this session's participations only.
class SessionHeader extends StatelessWidget {
  const SessionHeader({
    required this.session,
    required this.participants,
    required this.formattedDate,
    required this.formatLabel,
    required this.isCurrentActive,
    required this.onScoreIncrement,
    this.tournamentBoard,
    this.canEdit = true,
    super.key,
  });

  final Session session;
  final List<SessionParticipantDetail> participants;
  final String formattedDate;
  final String formatLabel;
  final bool isCurrentActive;
  final bool canEdit;
  final void Function(Team team, int delta) onScoreIncrement;
  final Widget? tournamentBoard;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isTournament = session.sessionType == SessionType.tournament3;
    final teams = isTournament ? [Team.a, Team.b, Team.c] : [Team.a, Team.b];
    final status = session.status == SessionStatus.closed
        ? 'Terminée'
        : isCurrentActive
        ? 'En cours'
        : 'Brouillon';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.background700),
            gradient: LinearGradient(
              colors: [
                Color.alphaBlend(
                  _teamColor(context, Team.a).withValues(alpha: 0.18),
                  colors.background900,
                ),
                colors.background900,
                Color.alphaBlend(
                  _teamColor(context, Team.b).withValues(alpha: 0.18),
                  colors.background900,
                ),
              ],
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    Remix.football_line,
                    size: 18,
                    color: colors.foreground300,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${isTournament ? 'Tournoi · 3 équipes' : 'Football · $formatLabel'} · ${session.isRanked ? 'Classée' : 'Amical'}',
                      style: TextStyle(
                        color: colors.foreground300,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (isTournament) ...[
                ?tournamentBoard,
                const SizedBox(height: 8),
                Text(
                  status,
                  style: TextStyle(color: colors.foreground300, fontSize: 12),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(child: _teamIdentity(context, Team.a)),
                    Expanded(
                      child: Column(
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${session.scoreA ?? '–'} - ${session.scoreB ?? '–'}',
                              style: TextStyle(
                                color: colors.foreground50,
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            status,
                            style: TextStyle(
                              color: colors.foreground300,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: _teamIdentity(context, Team.b)),
                  ],
                ),
                if (isCurrentActive && canEdit) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _scoreControls(
                          context,
                          Team.a,
                          session.scoreA ?? 0,
                        ),
                      ),
                      const Spacer(),
                      Expanded(
                        child: _scoreControls(
                          context,
                          Team.b,
                          session.scoreB ?? 0,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
              const SizedBox(height: 20),
              Text(
                formattedDate,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.foreground400, fontSize: 13),
              ),
            ],
          ),
        ),
        if (participants.any(
              (p) =>
                  p.participation.sessionId == session.id &&
                  p.participation.goals > 0,
            ) ||
            session.unassignedGoalsA +
                    session.unassignedGoalsB +
                    session.unassignedGoalsC >
                0) ...[
          const SizedBox(height: 8),
          Container(
            key: const ValueKey('session-scorers'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.background900,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.background700),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isTournament)
                  // Stack three camps to keep names readable on narrow phones.
                  Column(
                    children: [
                      for (final team in teams) ...[
                        _scorers(context, team, showTitle: true),
                        if (team != teams.last) const SizedBox(height: 12),
                      ],
                    ],
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _scorers(context, Team.a)),
                      const SizedBox(width: 16),
                      Expanded(child: _scorers(context, Team.b)),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Color _teamColor(BuildContext context, Team team) =>
      session.teamColor(context, team);

  String _teamName(Team team) => session.teamName(team);

  Widget _teamIdentity(BuildContext context, Team team) {
    final color = _teamColor(context, team);
    return Column(
      children: [
        Text(
          _teamName(team),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.colors.foreground50,
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

  Widget _scoreControls(BuildContext context, Team team, int score) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Diminuer le score de ${_teamName(team)}',
            icon: const Icon(Remix.subtract_line, size: 20),
            color: context.colors.foreground400,
            onPressed: score > 0 ? () => onScoreIncrement(team, -1) : null,
          ),
          IconButton(
            tooltip: 'Augmenter le score de ${_teamName(team)}',
            icon: const Icon(Remix.add_line, size: 20),
            color: _teamColor(context, team),
            onPressed: () => onScoreIncrement(team, 1),
          ),
        ],
      ),
    );
  }

  Widget _scorers(BuildContext context, Team team, {bool showTitle = false}) {
    final scorers =
        participants
            .where(
              (p) =>
                  p.participation.sessionId == session.id &&
                  p.participation.team == team &&
                  p.participation.goals > 0,
            )
            .toList()
          ..sort((a, b) {
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
      key: ValueKey('session-scorers-${team.name}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTitle) ...[
          Text(
            _teamName(team),
            style: TextStyle(
              color: _teamColor(context, team),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
        ],
        for (final scorer in scorers)
          _scorerRow(
            context,
            team,
            scorer.playerName,
            scorer.participation.goals,
          ),
        if (unassigned > 0)
          _scorerRow(context, team, 'Non attribués', unassigned),
      ],
    );
  }

  Widget _scorerRow(BuildContext context, Team team, String name, int goals) {
    final label = '$goals ${goals == 1 ? 'but' : 'buts'}';
    final isLeftTeam = team == Team.a;
    final playerName = Expanded(
      flex: 3,
      child: Text(
        name,
        textAlign: isLeftTeam ? TextAlign.right : TextAlign.left,
        style: TextStyle(color: context.colors.foreground300, fontSize: 12),
      ),
    );
    final goalIcons = Flexible(
      flex: 2,
      child: Wrap(
        alignment: isLeftTeam ? WrapAlignment.end : WrapAlignment.start,
        spacing: 3,
        runSpacing: 3,
        children: [
          Icon(Remix.football_fill, size: 14, color: _teamColor(context, team)),
          if (goals > 1)
            Text(
              'x$goals',
              style: TextStyle(color: _teamColor(context, team), fontSize: 12),
            ),
        ],
      ),
    );
    return Padding(
      key: ValueKey('session-scorer-${team.name}-$name'),
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Semantics(
        label: '$name, $label, ${_teamName(team)}',
        excludeSemantics: true,
        child: Row(
          mainAxisAlignment: isLeftTeam
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: isLeftTeam
              ? [playerName, const SizedBox(width: 6), goalIcons]
              : [goalIcons, const SizedBox(width: 6), playerName],
        ),
      ),
    );
  }
}
