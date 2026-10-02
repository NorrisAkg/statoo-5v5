import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/initial_avatar.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/soccer_shoe_icon.dart';
import '../../players/application/players_provider.dart';
import '../../ranking/application/ranking_providers.dart';
import '../../ranking/domain/standing_entry.dart';
import '../../sessions/application/sessions_provider.dart';
import '../../sessions/domain/session.dart';
import '../../sessions/domain/session_summary.dart';
import '../../stats/application/stats_providers.dart';
import '../../team/application/team_provider.dart';
import '../../team/presentation/team_switcher_bottom_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeDraftAsync = ref.watch(activeDraftSessionProvider);
    final sessionsAsync = ref.watch(sessionsListProvider);
    final activeTeam = ref.watch(activeTeamProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: () => showTeamSwitcher(context),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: context.colors.primary500.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Remix.shield_user_line,
                    size: 16,
                    color: context.colors.primary500,
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Text(
                    activeTeam?.name ?? 'Mon groupe',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Remix.arrow_down_s_line,
                  size: 18,
                  color: context.colors.foreground400,
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Remix.settings_4_line),
            tooltip: 'Réglages',
            onPressed: () => context.push('/reglages'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSessionHeader(
            context,
            activeDraftAsync.value,
            sessionsAsync.value,
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Nouvelle séance',
            icon: Remix.add_line,
            onPressed: () => context.push('/seances/nouvelle'),
          ),
          _buildPlayerOfTheMonth(context, ref),
          const SizedBox(height: 32),
          _buildSectionHeader(context, 'Classement', '/classement'),
          const SizedBox(height: 16),
          _buildRanking(context, ref),
          const SizedBox(height: 32),
          _buildTiles(context, ref),
          const SizedBox(height: 32),
          _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildSessionHeader(
    BuildContext context,
    Session? activeDraft,
    List<SessionSummaryItem>? sessions,
  ) {
    // 1. If active draft session exists, show active session banner
    if (activeDraft != null) {
      final playedAtStr = DateFormat(
        "EEE d MMM · HH'h'mm",
        'fr_FR',
      ).format(activeDraft.playedAt);

      return AppCard(
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: context.colors.warning,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Séance en cours',
                  style: TextStyle(
                    color: context.colors.warning,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Text(
                  playedAtStr,
                  style: TextStyle(
                    color: context.colors.foreground400,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Équipe A',
                  style: TextStyle(
                    color: context.colors.accent400,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${activeDraft.scoreA ?? 0}',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '-',
                    style: TextStyle(
                      fontSize: 28,
                      color: context.colors.foreground600,
                    ),
                  ),
                ),
                Text(
                  '${activeDraft.scoreB ?? 0}',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Équipe B',
                  style: TextStyle(
                    color: context.colors.secondary400,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Remix.play_fill, size: 16),
                label: const Text('Reprendre le match en direct'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.colors.warning,
                  side: BorderSide(
                    color: context.colors.warning.withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => context.push('/seances/${activeDraft.id}'),
              ),
            ),
          ],
        ),
      );
    }

    // 2. If recent closed session exists
    final recentClosed = sessions?.where((s) => s.isClosed).firstOrNull;
    if (recentClosed != null) {
      final s = recentClosed.session;
      return AppCard(
        child: InkWell(
          onTap: () => context.push('/seances/${s.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Remix.check_double_line,
                    size: 16,
                    color: context.colors.primary500,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Dernière séance',
                    style: TextStyle(
                      color: context.colors.primary400,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    recentClosed.formattedDateTime,
                    style: TextStyle(
                      color: context.colors.foreground400,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Équipe A',
                    style: TextStyle(
                      color: context.colors.accent400,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${s.scoreA ?? 0}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '-',
                      style: TextStyle(
                        fontSize: 24,
                        color: context.colors.foreground600,
                      ),
                    ),
                  ),
                  Text(
                    '${s.scoreB ?? 0}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Équipe B',
                    style: TextStyle(
                      color: context.colors.secondary400,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // 3. Empty state
    return AppCard(
      child: Column(
        children: [
          Icon(
            Remix.football_line,
            size: 48,
            color: context.colors.primary500.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune séance pour le moment',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Créez votre première séance pour commencer à suivre vos statistiques !',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.foreground400),
          ),
        ],
      ),
    );
  }

  static const _frenchMonths = [
    'Janvier',
    'Février',
    'Mars',
    'Avril',
    'Mai',
    'Juin',
    'Juillet',
    'Août',
    'Septembre',
    'Octobre',
    'Novembre',
    'Décembre',
  ];

  static String _formatMonthLabel(String? monthStr) {
    if (monthStr == null || monthStr.isEmpty) return '';
    final parts = monthStr.split('-');
    if (parts.length == 2) {
      final year = parts[0];
      final monthIndex = int.tryParse(parts[1]);
      if (monthIndex != null && monthIndex >= 1 && monthIndex <= 12) {
        return '${_frenchMonths[monthIndex - 1]} $year';
      }
    }
    return monthStr;
  }

  Widget _buildPlayerOfTheMonth(BuildContext context, WidgetRef ref) {
    final mvpAsync = ref.watch(playerOfTheMonthProvider);

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: mvpAsync.maybeWhen(
        data: (mvp) {
          if (mvp == null) {
            return AppCard(
              child: InkWell(
                onTap: () {
                  ref
                      .read(standingsViewModeProvider.notifier)
                      .selectMode(StandingsViewMode.mvp);
                  context.go('/classement');
                },
                borderRadius: BorderRadius.circular(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Remix.trophy_line,
                        color: Color(0xFFFFD700),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Joueur du mois',
                            style: TextStyle(
                              color: Color(0xFFFFD700),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'En attente des séances · Aucun MVP désigné',
                            style: TextStyle(
                              color: context.colors.foreground400,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Remix.arrow_right_s_line,
                      size: 20,
                      color: context.colors.foreground500,
                    ),
                  ],
                ),
              ),
            );
          }

          final monthLabel = _formatMonthLabel(mvp.month);

          return AppCard(
            child: InkWell(
              onTap: () {
                ref
                    .read(standingsViewModeProvider.notifier)
                    .selectMode(StandingsViewMode.mvp);
                context.go('/classement');
              },
              borderRadius: BorderRadius.circular(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Remix.trophy_fill,
                        color: Color(0xFFFFD700),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        monthLabel.isNotEmpty
                            ? 'Joueur du mois · $monthLabel'
                            : 'Joueur du mois',
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFFFD700)
                                .withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          '${mvp.score.toStringAsFixed(2)} pts',
                          style: const TextStyle(
                            color: Color(0xFFFFD700),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      InitialAvatar(
                        initial: mvp.name.isNotEmpty
                            ? mvp.name[0].toUpperCase()
                            : '?',
                        baseColor: const Color(0xFFFFD700),
                        size: 40,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    mvp.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (mvp.nickname != null &&
                                    mvp.nickname!.isNotEmpty) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    '« ${mvp.nickname} »',
                                    style: TextStyle(
                                      color: context.colors.foreground500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 10,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _buildStatIconCount(
                                  icon: Remix.calendar_event_line,
                                  count: mvp.matchesPlayed,
                                  color: context.colors.foreground400,
                                ),
                                _buildStatIconCount(
                                  icon: Remix.football_line,
                                  count: mvp.goals,
                                  color: context.colors.primary400,
                                ),
                                _buildStatIconCount(
                                  customIcon: SoccerShoeIcon(
                                    size: 13,
                                    color: context.colors.secondary400,
                                  ),
                                  count: mvp.assists,
                                  color: context.colors.secondary400,
                                ),
                                _buildCardBadge(
                                  color: context.colors.card,
                                  count: mvp.yellowCards,
                                ),
                                _buildCardBadge(
                                  color: context.colors.danger,
                                  count: mvp.redCards,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Remix.arrow_right_s_line,
                        size: 20,
                        color: context.colors.foreground500,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildStatIconCount({
    required int count,
    required Color color,
    IconData? icon,
    Widget? customIcon,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (customIcon != null)
          customIcon
        else if (icon != null)
          Icon(icon, size: 13, color: color),
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

  Widget _buildCardBadge({required Color color, required int count}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
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

  Widget _buildSectionHeader(BuildContext context, String title, String route) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        GestureDetector(
          onTap: () => context.go(route),
          child: Text(
            'Voir tout',
            style: TextStyle(
              color: context.colors.primary400,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRanking(BuildContext context, WidgetRef ref) {
    final standingsAsync = ref.watch(standingsProvider);

    return standingsAsync.when(
      loading: () => const AppCard(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        ),
      ),
      error: (_, _) => _buildEmptyRanking(context),
      data: (standings) {
        final playedStandings = standings
            .where((s) => s.matchesPlayed > 0)
            .take(3)
            .toList();
        if (playedStandings.isEmpty) {
          return _buildEmptyRanking(context);
        }

        return AppCard(
          child: Column(
            children: [
              for (var i = 0; i < playedStandings.length; i++) ...[
                if (i > 0) const Divider(height: 16),
                _buildHomeStandingRow(context, playedStandings[i], i + 1),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildHomeStandingRow(
    BuildContext context,
    StandingEntry entry,
    int rank,
  ) {
    final rankColor = rank == 1
        ? const Color(0xFFFFD700)
        : rank == 2
        ? const Color(0xFFC0C0C0)
        : const Color(0xFFCD7F32);

    return InkWell(
      onTap: () => context.go('/classement'),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: rankColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: rankColor.withValues(alpha: 0.6)),
              ),
              child: Text(
                '$rank',
                style: TextStyle(
                  color: rankColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 10),
            InitialAvatar(
              initial: entry.name.isNotEmpty
                  ? entry.name[0].toUpperCase()
                  : '?',
              baseColor: context.colors.foreground300,
              size: 28,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          entry.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (entry.nickname != null &&
                          entry.nickname!.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Text(
                          '« ${entry.nickname} »',
                          style: TextStyle(
                            color: context.colors.foreground500,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    '${entry.matchesPlayed} MJ · ${entry.wins}V ${entry.draws}N ${entry.losses}D',
                    style: TextStyle(
                      color: context.colors.foreground500,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${entry.points} pts',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: context.colors.foreground50,
                  ),
                ),
                Text(
                  '${entry.goals} buts',
                  style: TextStyle(
                    color: context.colors.foreground500,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyRanking(BuildContext context) {
    return AppCard(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(
                Remix.medal_line,
                size: 32,
                color: context.colors.foreground600,
              ),
              const SizedBox(height: 8),
              Text(
                'Le classement est vide',
                style: TextStyle(
                  color: context.colors.foreground400,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Clôturez une séance classée pour l'alimenter.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.colors.foreground500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTiles(BuildContext context, WidgetRef ref) {
    final playersAsync = ref.watch(playersListProvider);
    final playersCount = playersAsync.maybeWhen(
      data: (players) => players.where((p) => p.isActive).length.toString(),
      orElse: () => '-',
    );

    final sessionsAsync = ref.watch(sessionsListProvider);
    final sessionsCount = sessionsAsync.maybeWhen(
      data: (sessions) => sessions.length.toString(),
      orElse: () => '0',
    );

    final groupTotalsAsync = ref.watch(groupTotalsProvider);
    final statsWidget = groupTotalsAsync.maybeWhen(
      data: (totals) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Remix.football_line, size: 16, color: context.colors.primary400),
          const SizedBox(width: 4),
          Text(
            '${totals.totalGoals}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          SoccerShoeIcon(size: 16, color: context.colors.secondary400),
          const SizedBox(width: 4),
          Text(
            '${totals.totalAssists}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      orElse: () => const Text(
        '-',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );

    return Row(
      children: [
        Expanded(
          child: _buildTile(
            context,
            Remix.user_line,
            'Joueurs',
            value: playersCount,
            onTap: () => context.go('/joueurs'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildTile(
            context,
            Remix.calendar_event_line,
            'Séances',
            value: sessionsCount,
            onTap: () => context.go('/seances'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildTile(
            context,
            Remix.pie_chart_line,
            'Stats',
            customValue: statsWidget,
            onTap: () => context.go('/stats'),
          ),
        ),
      ],
    );
  }

  Widget _buildTile(
    BuildContext context,
    IconData icon,
    String title, {
    String? value,
    Widget? customValue,
    VoidCallback? onTap,
  }) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: context.colors.primary500, size: 24),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  color: context.colors.foreground400,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              if (customValue != null)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: customValue,
                )
              else if (value != null && value.isNotEmpty)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Remix.cloud_windy_line,
          color: context.colors.foreground500,
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          'Aucune sauvegarde cloud',
          style: TextStyle(color: context.colors.foreground500, fontSize: 12),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => context.push('/reglages'),
          child: Text(
            'Sauvegarder',
            style: TextStyle(
              color: context.colors.primary400,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
