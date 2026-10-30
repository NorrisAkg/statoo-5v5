import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/soccer_shoe_icon.dart';
import '../domain/participation.dart';
import '../domain/session.dart';
import '../domain/session_summary.dart';
import '../domain/team_appearance.dart';
import 'session_team_colors.dart';

class MatchEventsTimeline extends StatelessWidget {
  const MatchEventsTimeline({
    required this.session,
    required this.participants,
    this.journal = const [],
    super.key,
  });

  final Session session;
  final List<SessionParticipantDetail> participants;
  final List<Map<String, dynamic>> journal;

  List<_TimelineEvent> _buildEvents() {
    final nameMap = <String, String>{};
    for (final p in participants) {
      nameMap[p.participation.id] = p.playerName;
      nameMap[p.participation.playerId] = p.playerName;
    }

    if (journal.isNotEmpty) {
      final events = <_TimelineEvent>[];
      int scoreA = 0;
      int scoreB = 0;

      for (final entry in journal) {
        final a = (entry['action'] as Map?) ?? const {};
        final type = (a['type'] as String?) ?? '';
        final team = (a['team'] as String? ?? 'A').toUpperCase();
        final playerId = a['player'] as String?;
        final playerName = (playerId != null ? nameMap[playerId] : null) ?? 'Joueur inconnu';
        final assistId = a['assist'] as String?;
        final assistName = assistId != null ? nameMap[assistId] : null;

        String? runningScore;
        if (type == 'goal') {
          if (team == 'A') {
            scoreA++;
          } else if (team == 'B') {
            scoreB++;
          }
          runningScore = '($scoreA - $scoreB)';
        }

        events.add(
          _TimelineEvent(
            type: type,
            team: team,
            playerName: playerName,
            assistName: assistName,
            runningScore: runningScore,
          ),
        );
      }
      return events;
    }

    // Fallback on participants if journal is empty
    final events = <_TimelineEvent>[];
    int scoreA = 0;
    int scoreB = 0;

    for (final p in participants) {
      final teamCode = p.participation.team.name.toUpperCase();
      for (var i = 0; i < p.participation.goals; i++) {
        if (teamCode == 'A') {
          scoreA++;
        } else if (teamCode == 'B') {
          scoreB++;
        }
        events.add(
          _TimelineEvent(
            type: 'goal',
            team: teamCode,
            playerName: p.playerName,
            runningScore: '($scoreA - $scoreB)',
          ),
        );
      }
      for (var i = 0; i < p.participation.yellowCards; i++) {
        events.add(
          _TimelineEvent(
            type: 'yellow',
            team: teamCode,
            playerName: p.playerName,
          ),
        );
      }
      for (var i = 0; i < p.participation.redCards; i++) {
        events.add(
          _TimelineEvent(
            type: 'red',
            team: teamCode,
            playerName: p.playerName,
          ),
        );
      }
    }
    return events;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final events = _buildEvents();

    if (events.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
          child: Text(
            'Aucun fait de jeu enregistré pour cette séance.',
            style: TextStyle(
              color: colors.foreground400,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final teamAName = session.teamName(Team.a);
    final teamBName = session.teamName(Team.b);
    final colorA = session.teamColor(context, Team.a);
    final colorB = session.teamColor(context, Team.b);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Teams header row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: _buildTeamHeaderPill(
                  name: teamAName,
                  color: colorA,
                  alignment: CrossAxisAlignment.end,
                ),
              ),
              Container(
                width: 36,
                alignment: Alignment.center,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: colors.background800,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.background700),
                  ),
                  child: Icon(
                    Remix.play_circle_line,
                    size: 14,
                    color: colors.foreground400,
                  ),
                ),
              ),
              Expanded(
                child: _buildTeamHeaderPill(
                  name: teamBName,
                  color: colorB,
                  alignment: CrossAxisAlignment.start,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Timeline items
        for (var i = 0; i < events.length; i++)
          _buildTimelineRow(
            context,
            event: events[i],
            colorA: colorA,
            colorB: colorB,
            isFirst: i == 0,
            isLast: i == events.length - 1,
          ),

        // Timeline finish node
        Center(
          child: Container(
            key: const ValueKey('timeline-spine'),
            width: 36,
            height: 36,
            alignment: Alignment.center,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: 0,
                  bottom: 18,
                  child: Container(
                    width: 2,
                    color: colors.background700,
                  ),
                ),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: colors.background800,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.background700, width: 2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTeamHeaderPill({
    required String name,
    required Color color,
    required CrossAxisAlignment alignment,
  }) {
    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.28)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  name,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
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

  Widget _buildTimelineRow(
    BuildContext context, {
    required _TimelineEvent event,
    required Color colorA,
    required Color colorB,
    required bool isFirst,
    required bool isLast,
  }) {
    final colors = context.colors;
    final isTeamA = event.team == 'A';
    final isTeamB = event.team == 'B';
    final teamColor = isTeamA
        ? colorA
        : (event.team == 'C' ? session.teamColor(context, Team.c) : colorB);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left side: Team A card or empty
          Expanded(
            child: isTeamA
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: _buildEventCard(
                      context,
                      event: event,
                      teamColor: teamColor,
                      alignRight: true,
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // Central spine column
          SizedBox(
            width: 36,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Vertical spine line
                Container(
                  key: const ValueKey('timeline-spine'),
                  width: 2,
                  color: colors.background700,
                ),
                // Event node badge
                _buildNodeBadge(context, event: event, teamColor: teamColor),
              ],
            ),
          ),

          // Right side: Team B card or empty
          Expanded(
            child: isTeamB
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: _buildEventCard(
                      context,
                      event: event,
                      teamColor: teamColor,
                      alignRight: false,
                    ),
                  )
                : (event.team == 'C'
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: _buildEventCard(
                          context,
                          event: event,
                          teamColor: session.teamColor(context, Team.c),
                          alignRight: false,
                        ),
                      )
                    : const SizedBox.shrink()),
          ),
        ],
      ),
    );
  }

  Widget _buildNodeBadge(
    BuildContext context, {
    required _TimelineEvent event,
    required Color teamColor,
  }) {
    final colors = context.colors;
    Widget icon;

    if (event.type == 'goal') {
      icon = Icon(
        Remix.football_line,
        size: 13,
        color: colors.foreground50,
      );
    } else if (event.type == 'yellow') {
      icon = Icon(
        Remix.rectangle_fill,
        size: 11,
        color: colors.card,
      );
    } else if (event.type == 'red') {
      icon = Icon(
        Remix.rectangle_fill,
        size: 11,
        color: colors.danger,
      );
    } else {
      icon = Icon(
        Remix.trophy_line,
        size: 13,
        color: colors.secondary400,
      );
    }

    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.background800,
        shape: BoxShape.circle,
        border: Border.all(
          color: event.type == 'goal' ? teamColor : colors.background700,
          width: 1.5,
        ),
      ),
      child: icon,
    );
  }

  Widget _buildEventCard(
    BuildContext context, {
    required _TimelineEvent event,
    required Color teamColor,
    required bool alignRight,
  }) {
    final colors = context.colors;
    final isGoal = event.type == 'goal';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: colors.background800,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isGoal ? teamColor.withValues(alpha: 0.3) : colors.background700,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top row: Running score or event label
          if (isGoal && event.runningScore != null) ...[
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: alignRight ? WrapAlignment.end : WrapAlignment.start,
              spacing: 4,
              children: [
                if (!alignRight)
                  Icon(Remix.football_line, size: 12, color: colors.foreground400),
                Text(
                  event.runningScore!,
                  style: TextStyle(
                    color: colors.primary400,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                if (alignRight)
                  Icon(Remix.football_line, size: 12, color: colors.foreground400),
              ],
            ),
            const SizedBox(height: 2),
          ] else if (event.type == 'yellow') ...[
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: alignRight ? WrapAlignment.end : WrapAlignment.start,
              spacing: 4,
              children: [
                Icon(Remix.rectangle_fill, size: 11, color: colors.card),
                Text(
                  'Carton jaune',
                  style: TextStyle(
                    color: colors.card,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
          ] else if (event.type == 'red') ...[
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: alignRight ? WrapAlignment.end : WrapAlignment.start,
              spacing: 4,
              children: [
                Icon(Remix.rectangle_fill, size: 11, color: colors.danger),
                Text(
                  'Carton rouge',
                  style: TextStyle(
                    color: colors.danger,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
          ],

          // Player name
          Text(
            event.playerName,
            style: TextStyle(
              color: colors.foreground50,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            textAlign: alignRight ? TextAlign.right : TextAlign.left,
            overflow: TextOverflow.ellipsis,
          ),

          // Assist name if present
          if (event.assistName != null) ...[
            const SizedBox(height: 2),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: alignRight ? WrapAlignment.end : WrapAlignment.start,
              spacing: 4,
              children: [
                if (!alignRight)
                  SoccerShoeIcon(size: 11, color: colors.secondary400),
                Text(
                  'Passe : ${event.assistName}',
                  style: TextStyle(
                    color: colors.foreground400,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (alignRight)
                  SoccerShoeIcon(size: 11, color: colors.secondary400),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TimelineEvent {
  const _TimelineEvent({
    required this.type,
    required this.team,
    required this.playerName,
    this.assistName,
    this.runningScore,
  });

  final String type;
  final String team;
  final String playerName;
  final String? assistName;
  final String? runningScore;
}
