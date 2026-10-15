import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../../team/application/team_provider.dart';
import '../../team/presentation/team_switcher_bottom_sheet.dart';
import '../application/sessions_provider.dart';
import '../domain/session.dart';
import '../domain/session_summary.dart';
import '../../shared/application/shared_providers.dart';

class SessionsScreen extends ConsumerWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeFilter = ref.watch(sessionsFilterProvider);
    final sessionsAsync = ref.watch(sessionsListProvider);
    final allSessionsAsync = ref.watch(allSessionsProvider);
    final activeTeam = ref.watch(activeTeamProvider).value;

    final totalCount = allSessionsAsync.value?.length ?? 0;

    final filterText = switch (activeFilter) {
      'ranked' => '${sessionsAsync.value?.length ?? 0} classée(s)',
      'friendly' => '${sessionsAsync.value?.length ?? 0} amicale(s)',
      'draft' => '${sessionsAsync.value?.length ?? 0} brouillon(s)',
      _ => '$totalCount au total',
    };

    final subtitleText = '$filterText${activeTeam != null ? ' · ${activeTeam.name}' : ''}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Séances'),
        actions: [
          IconButton(
            icon: const Icon(Remix.arrow_left_right_line),
            tooltip: 'Changer de groupe',
            onPressed: () => showTeamSwitcher(context),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              subtitleText,
              style: TextStyle(color: context.colors.onHeader, fontSize: 14),
            ),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildFilters(context, ref, activeFilter),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: sessionsAsync.when(
              data: (sessions) {
                if (sessions.isEmpty) {
                  return _buildEmptyState(
                    context,
                    ref,
                    activeFilter,
                    totalCount > 0,
                  );
                }
                return _buildSessionsList(context, sessions);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Erreur: $err', style: TextStyle(color: context.colors.danger)),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: ref.watch(canWriteProvider('sport')) ? FloatingActionButton(
        onPressed: () => context.push('/seances/nouvelle'),
        backgroundColor: context.colors.primary500,
        foregroundColor: context.colors.background950,
        child: const Icon(Remix.add_line),
      ) : null,
    );
  }

  Widget _buildFilters(BuildContext context, WidgetRef ref, String activeFilter) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip(context, ref, label: 'Toutes', filterKey: 'all', isSelected: activeFilter == 'all'),
          const SizedBox(width: 8),
          _buildFilterChip(context, ref, label: 'Classées', filterKey: 'ranked', isSelected: activeFilter == 'ranked'),
          const SizedBox(width: 8),
          _buildFilterChip(context, ref, label: 'Amicales', filterKey: 'friendly', isSelected: activeFilter == 'friendly'),
          const SizedBox(width: 8),
          _buildFilterChip(context, ref, label: 'Brouillons', filterKey: 'draft', isSelected: activeFilter == 'draft'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    WidgetRef ref, {
    required String label,
    required String filterKey,
    required bool isSelected,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        ref.read(sessionsFilterProvider.notifier).selectFilter(filterKey);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? context.colors.primary500.withValues(alpha: 0.15) : context.colors.background800,
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(
            color: isSelected ? context.colors.primary500 : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? context.colors.primary500 : context.colors.foreground300,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    WidgetRef ref,
    String activeFilter,
    bool hasAnySessions,
  ) {
    if (!hasAnySessions) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: AppCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Remix.football_line,
                    size: 56,
                    color: context.colors.primary500.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Aucune séance pour le moment',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Créez votre première séance pour enregistrer les scores et statistiques de vos matchs.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.colors.foreground400, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                    if (ref.watch(canWriteProvider('sport'))) PrimaryButton(
                    label: 'Nouvelle séance',
                    icon: Remix.add_line,
                    onPressed: () => context.push('/seances/nouvelle'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final message = switch (activeFilter) {
      'ranked' => 'Aucune séance classée trouvée.',
      'friendly' => 'Aucune séance amicale trouvée.',
      'draft' => 'Aucun brouillon en cours.',
      _ => 'Aucune séance trouvée.',
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: AppCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Remix.filter_3_line,
                  size: 48,
                  color: context.colors.foreground500,
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Essayez un autre filtre pour afficher vos séances.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.foreground400, fontSize: 13),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  icon: const Icon(Remix.refresh_line, size: 16),
                  label: const Text('Voir toutes les séances'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.colors.primary400,
                    side: BorderSide(color: context.colors.primary500.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    ref.read(sessionsFilterProvider.notifier).selectFilter('all');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSessionsList(BuildContext context, List<SessionSummaryItem> sessions) {
    final grouped = <String, List<SessionSummaryItem>>{};
    for (final item in sessions) {
      final key = item.monthYearGroup;
      grouped.putIfAbsent(key, () => []).add(item);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: grouped.keys.length,
      itemBuilder: (context, index) {
        final monthKey = grouped.keys.elementAt(index);
        final monthSessions = grouped[monthKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 12),
              child: Text(
                monthKey,
                style: TextStyle(
                  color: context.colors.foreground400,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ...monthSessions.map((item) => _buildSessionCard(context, item)),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  Widget _buildSessionCard(BuildContext context, SessionSummaryItem item) {
    final session = item.session;
    final isDraft = item.isDraft;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/seances/${session.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colors.background900,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDraft ? context.colors.primary500.withValues(alpha: 0.4) : context.colors.background700,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    item.formattedDateTime,
                    style: TextStyle(color: context.colors.foreground400, fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                  if (item.isInProgress)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: context.colors.warning.withValues(alpha: 0.15),
                        border: Border.all(color: context.colors.warning.withValues(alpha: 0.5)),
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Text(
                        'EN COURS',
                        style: TextStyle(
                          color: context.colors.warning,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else if (item.isWaitingDraft)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        border: Border.all(color: context.colors.foreground600),
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Text(
                        'BROUILLON',
                        style: TextStyle(
                          color: context.colors.foreground400,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    const StatusBadge(status: BadgeStatus.closed),
                  if (!item.isRanked) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        border: Border.all(color: context.colors.foreground600),
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Text(
                        'AMICAL',
                        style: TextStyle(
                          color: context.colors.foreground400,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (item.hasGoalWarning)
                    Row(
                      children: [
                        Icon(Remix.error_warning_line, color: context.colors.warning, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'Buts',
                          style: TextStyle(
                            color: context.colors.warning,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (session.sessionType == SessionType.tournament3)
                Row(
                  children: [
                    _buildTournamentPill(context, 'A', session.winsA, context.colors.accent500),
                    const SizedBox(width: 8),
                    _buildTournamentPill(context, 'B', session.winsB, context.colors.secondary500),
                    const SizedBox(width: 8),
                    _buildTournamentPill(context, 'C', session.winsC, context.colors.primary500),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: context.colors.background800,
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: const Text('Tournoi', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${item.playerCount} joueur${item.playerCount > 1 ? 's' : ''}',
                      style: TextStyle(color: context.colors.foreground400, fontSize: 12),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    _buildTeamDot(context, context.colors.accent500, 'A'),
                    const SizedBox(width: 12),
                    Text(
                      '${session.scoreA ?? 0}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '-',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: context.colors.foreground600,
                        ),
                      ),
                    ),
                    Text(
                      '${session.scoreB ?? 0}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 12),
                    _buildTeamDot(context, context.colors.secondary500, 'B'),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: context.colors.background800,
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Text(
                        item.playerCount > 0
                            ? (item.playerCount.isEven
                                ? '${item.playerCount ~/ 2}v${item.playerCount ~/ 2}'
                                : '${(item.playerCount + 1) ~/ 2}v${item.playerCount ~/ 2}')
                            : '5v5',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${item.playerCount} joueur${item.playerCount > 1 ? 's' : ''}',
                      style: TextStyle(color: context.colors.foreground400, fontSize: 12),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamDot(BuildContext context, Color color, String label) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        label,
        style: TextStyle(
          color: context.colors.foreground50,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTournamentPill(BuildContext context, String team, int wins, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Text(
              team,
              style: TextStyle(color: context.colors.foreground50, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$wins V',
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
