import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/initial_avatar.dart';
import '../application/ranking_providers.dart';
import '../domain/assist_entry.dart';
import '../domain/card_entry.dart';
import '../domain/mvp_entry.dart';
import '../domain/scorer_entry.dart';
import '../domain/standing_entry.dart';
import '../domain/standing_per_match_entry.dart';

class StandingsScreen extends ConsumerWidget {
  const StandingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewMode = ref.watch(standingsViewModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Classement'), centerTitle: false),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _ViewModeSwitcher(currentMode: viewMode),
          ),
          Expanded(
            child: viewMode == StandingsViewMode.championship
                ? const _ChampionshipView()
                : const _MvpView(),
          ),
        ],
      ),
    );
  }
}

class _ViewModeSwitcher extends ConsumerWidget {
  const _ViewModeSwitcher({required this.currentMode});

  final StandingsViewMode currentMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.background900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.background700),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _buildSegment(
              context,
              ref,
              mode: StandingsViewMode.championship,
              label: 'Championnat',
              icon: Remix.trophy_line,
              isSelected: currentMode == StandingsViewMode.championship,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildSegment(
              context,
              ref,
              mode: StandingsViewMode.mvp,
              label: 'MVP du mois',
              icon: Remix.medal_line,
              isSelected: currentMode == StandingsViewMode.mvp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegment(
    BuildContext context,
    WidgetRef ref, {
    required StandingsViewMode mode,
    required String label,
    required IconData icon,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        ref.read(standingsViewModeProvider.notifier).selectMode(mode);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? context.colors.primary500 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? context.colors.background950
                  : context.colors.foreground400,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isSelected
                    ? context.colors.background950
                    : context.colors.foreground400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChampionshipView extends StatelessWidget {
  const _ChampionshipView();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: context.colors.primary500,
            indicatorWeight: 3,
            labelColor: context.colors.primary500,
            unselectedLabelColor: context.colors.foreground500,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.normal,
              fontSize: 14,
            ),
            tabs: const [
              Tab(text: 'Points'),
              Tab(text: 'Pts / Match'),
              Tab(text: 'Buteurs'),
              Tab(text: 'Passeurs'),
              Tab(text: 'Cartons'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _PointsTab(),
                _PointsPerMatchTab(),
                _ScorersTab(),
                _AssistsTab(),
                _CardsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PointsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final standingsAsync = ref.watch(standingsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(standingsProvider);
      },
      color: context.colors.primary500,
      backgroundColor: context.colors.background900,
      child: standingsAsync.when(
        data: (standings) {
          if (standings.isEmpty) {
            return _buildEmptyState(context, 'Aucun match classé enregistré');
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: standings.length,
            itemBuilder: (context, index) {
              final entry = standings[index];
              return _buildStandingCard(context, entry);
            },
          );
        },
        loading: () => Center(
          child: CircularProgressIndicator(color: context.colors.primary500),
        ),
        error: (err, stack) => _buildErrorState(context, err.toString(), () {
          ref.invalidate(standingsProvider);
        }),
      ),
    );
  }

  Widget _buildStandingCard(BuildContext context, StandingEntry entry) {
    final avatarColor = _getPlayerColor(context, entry.playerId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => context.push('/joueurs/${entry.playerId}'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.colors.background900,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.colors.background700),
          ),
          child: Row(
            children: [
              _buildRankBadge(context, entry.rank),
              const SizedBox(width: 10),
              InitialAvatar(
                initial: entry.name.isNotEmpty ? entry.name[0] : '?',
                baseColor: avatarColor,
                size: 42,
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
                            entry.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (entry.nickname != null &&
                            entry.nickname!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            '« ${entry.nickname} »',
                            style: TextStyle(
                              color: context.colors.foreground500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: context.colors.background800,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: context.colors.background700,
                            ),
                          ),
                          child: Text(
                            'J ${entry.matchesPlayed}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              color: context.colors.foreground300,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${entry.wins}V · ${entry.draws}N · ${entry.losses}D',
                          style: TextStyle(
                            color: context.colors.foreground400,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${entry.points} pts',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: context.colors.primary400,
                    ),
                  ),
                  Text(
                    '${entry.goals}B · ${entry.assists}P',
                    style: TextStyle(
                      color: context.colors.foreground500,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(
                Remix.arrow_right_s_line,
                color: context.colors.foreground500,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PointsPerMatchTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final standingsAsync = ref.watch(standingsPerMatchProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(standingsPerMatchProvider);
      },
      color: context.colors.primary500,
      backgroundColor: context.colors.background900,
      child: standingsAsync.when(
        data: (standings) {
          if (standings.isEmpty) {
            return _buildEmptyState(context, 'Aucun match classé enregistré');
          }

          final eligibleList = standings.where((e) => e.isEligible).toList();
          final ineligibleList = standings.where((e) => !e.isEligible).toList();
          final totalSessions = standings.first.totalSessions;
          final requiredMatches = (totalSessions + 1) ~/ 2;

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              _buildEligibilityInfoBanner(
                context,
                requiredMatches,
                totalSessions,
              ),
              const SizedBox(height: 12),
              if (eligibleList.isNotEmpty) ...[
                Text(
                  'JOUEURS ÉLIGIBLES (${eligibleList.length})',
                  style: TextStyle(
                    color: context.colors.foreground400,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...eligibleList.map(
                  (entry) => _buildEligibleCard(context, entry),
                ),
              ],
              if (ineligibleList.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Remix.error_warning_line,
                      color: context.colors.warning,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'MOINS DE 50% DE PRÉSENCE (${ineligibleList.length})',
                      style: TextStyle(
                        color: context.colors.warning,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...ineligibleList.map(
                  (entry) => _buildIneligibleCard(context, entry),
                ),
              ],
            ],
          );
        },
        loading: () => Center(
          child: CircularProgressIndicator(color: context.colors.primary500),
        ),
        error: (err, stack) => _buildErrorState(context, err.toString(), () {
          ref.invalidate(standingsPerMatchProvider);
        }),
      ),
    );
  }

  Widget _buildEligibilityInfoBanner(
    BuildContext context,
    int requiredMatches,
    int totalSessions,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.primary500.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colors.primary500.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Remix.information_line,
            color: context.colors.primary400,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Seuil d'éligibilité : 50% des matchs ($requiredMatches / $totalSessions séances classées)",
              style: TextStyle(
                color: context.colors.foreground200,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEligibleCard(BuildContext context, StandingPerMatchEntry entry) {
    final avatarColor = _getPlayerColor(context, entry.playerId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => context.push('/joueurs/${entry.playerId}'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.colors.background900,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.colors.background700),
          ),
          child: Row(
            children: [
              _buildRankBadge(context, entry.rank),
              const SizedBox(width: 10),
              InitialAvatar(
                initial: entry.name.isNotEmpty ? entry.name[0] : '?',
                baseColor: avatarColor,
                size: 42,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'J ${entry.matchesPlayed} (${entry.points} pts) · ${entry.wins}V ${entry.draws}N ${entry.losses}D',
                      style: TextStyle(
                        color: context.colors.foreground400,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    entry.pointsPerMatch.toStringAsFixed(2),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: context.colors.primary400,
                    ),
                  ),
                  Text(
                    'pts / match',
                    style: TextStyle(
                      color: context.colors.foreground500,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(
                Remix.arrow_right_s_line,
                color: context.colors.foreground500,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIneligibleCard(
    BuildContext context,
    StandingPerMatchEntry entry,
  ) {
    final avatarColor = _getPlayerColor(context, entry.playerId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        opacity: 0.6,
        child: InkWell(
          onTap: () => context.push('/joueurs/${entry.playerId}'),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.colors.background900,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.colors.background700),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  alignment: Alignment.center,
                  child: Text(
                    '-',
                    style: TextStyle(
                      color: context.colors.foreground500,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                InitialAvatar(
                  initial: entry.name.isNotEmpty ? entry.name[0] : '?',
                  baseColor: avatarColor,
                  size: 42,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: context.colors.warning.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Manque ${entry.missingMatches} match${entry.missingMatches > 1 ? 's' : ''}',
                              style: TextStyle(
                                color: context.colors.warning,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'J ${entry.matchesPlayed}',
                            style: TextStyle(
                              color: context.colors.foreground500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      entry.pointsPerMatch.toStringAsFixed(2),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: context.colors.foreground400,
                      ),
                    ),
                    Text(
                      'pts / match',
                      style: TextStyle(
                        color: context.colors.foreground600,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                Icon(
                  Remix.arrow_right_s_line,
                  color: context.colors.foreground600,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScorersTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scorersAsync = ref.watch(topScorersProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(topScorersProvider);
      },
      color: context.colors.primary500,
      backgroundColor: context.colors.background900,
      child: scorersAsync.when(
        data: (scorers) {
          if (scorers.isEmpty) {
            return _buildEmptyState(context, 'Aucun but enregistré');
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: scorers.length,
            itemBuilder: (context, index) {
              final entry = scorers[index];
              return _buildScorerCard(context, entry);
            },
          );
        },
        loading: () => Center(
          child: CircularProgressIndicator(color: context.colors.primary500),
        ),
        error: (err, stack) => _buildErrorState(context, err.toString(), () {
          ref.invalidate(topScorersProvider);
        }),
      ),
    );
  }

  Widget _buildScorerCard(BuildContext context, ScorerEntry entry) {
    final avatarColor = _getPlayerColor(context, entry.playerId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => context.push('/joueurs/${entry.playerId}'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.colors.background900,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.colors.background700),
          ),
          child: Row(
            children: [
              _buildRankBadge(context, entry.rank),
              const SizedBox(width: 10),
              InitialAvatar(
                initial: entry.name.isNotEmpty ? entry.name[0] : '?',
                baseColor: avatarColor,
                size: 42,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'J ${entry.matchesPlayed} match${entry.matchesPlayed > 1 ? 's' : ''}',
                      style: TextStyle(
                        color: context.colors.foreground400,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: [
                  Icon(
                    Remix.football_line,
                    color: context.colors.primary400,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${entry.goals}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: context.colors.primary400,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Icon(
                Remix.arrow_right_s_line,
                color: context.colors.foreground500,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssistsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assistsAsync = ref.watch(topAssistsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(topAssistsProvider);
      },
      color: context.colors.primary500,
      backgroundColor: context.colors.background900,
      child: assistsAsync.when(
        data: (assists) {
          if (assists.isEmpty) {
            return _buildEmptyState(
              context,
              'Aucune passe décisive enregistrée',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: assists.length,
            itemBuilder: (context, index) {
              final entry = assists[index];
              return _buildAssistCard(context, entry);
            },
          );
        },
        loading: () => Center(
          child: CircularProgressIndicator(color: context.colors.primary500),
        ),
        error: (err, stack) => _buildErrorState(context, err.toString(), () {
          ref.invalidate(topAssistsProvider);
        }),
      ),
    );
  }

  Widget _buildAssistCard(BuildContext context, AssistEntry entry) {
    final avatarColor = _getPlayerColor(context, entry.playerId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => context.push('/joueurs/${entry.playerId}'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.colors.background900,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.colors.background700),
          ),
          child: Row(
            children: [
              _buildRankBadge(context, entry.rank),
              const SizedBox(width: 10),
              InitialAvatar(
                initial: entry.name.isNotEmpty ? entry.name[0] : '?',
                baseColor: avatarColor,
                size: 42,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'J ${entry.matchesPlayed} match${entry.matchesPlayed > 1 ? 's' : ''}',
                      style: TextStyle(
                        color: context.colors.foreground400,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: [
                  Icon(
                    Remix.magic_line,
                    color: context.colors.accent400,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${entry.assists}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: context.colors.accent400,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Icon(
                Remix.arrow_right_s_line,
                color: context.colors.foreground500,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(topCardsProvider);
    final activeFilter = ref.watch(cardsFilterProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(topCardsProvider);
      },
      color: context.colors.primary500,
      backgroundColor: context.colors.background900,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                _buildFilterChip(
                  context,
                  label: 'Tous',
                  isSelected: activeFilter == 'all',
                  onTap: () =>
                      ref.read(cardsFilterProvider.notifier).filter = 'all',
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  context,
                  label: 'Cartons jaunes',
                  cardColor: context.colors.card,
                  isSelected: activeFilter == 'yellow',
                  onTap: () =>
                      ref.read(cardsFilterProvider.notifier).filter = 'yellow',
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  context,
                  label: 'Cartons rouges',
                  cardColor: context.colors.danger,
                  isSelected: activeFilter == 'red',
                  onTap: () =>
                      ref.read(cardsFilterProvider.notifier).filter = 'red',
                ),
              ],
            ),
          ),
          Expanded(
            child: cardsAsync.when(
              data: (cards) {
                if (cards.isEmpty) {
                  return _buildEmptyState(context, 'Aucun carton enregistré');
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: cards.length,
                  itemBuilder: (context, index) {
                    final entry = cards[index];
                    return _buildCardItem(context, entry);
                  },
                );
              },
              loading: () => Center(
                child: CircularProgressIndicator(
                  color: context.colors.primary500,
                ),
              ),
              error: (err, stack) =>
                  _buildErrorState(context, err.toString(), () {
                    ref.invalidate(topCardsProvider);
                  }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? cardColor,
  }) {
    final bg = isSelected
        ? (cardColor != null
              ? cardColor.withValues(alpha: 0.18)
              : context.colors.primary500.withValues(alpha: 0.18))
        : context.colors.background800;
    final borderColor = isSelected
        ? (cardColor ?? context.colors.primary500)
        : context.colors.background700;
    final textColor = isSelected
        ? (cardColor ?? context.colors.primary400)
        : context.colors.foreground400;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (cardColor != null) ...[
              Container(
                width: 8,
                height: 11,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardItem(BuildContext context, CardEntry entry) {
    final avatarColor = _getPlayerColor(context, entry.playerId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => context.push('/joueurs/${entry.playerId}'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.colors.background900,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.colors.background700),
          ),
          child: Row(
            children: [
              _buildRankBadge(context, entry.rank),
              const SizedBox(width: 10),
              InitialAvatar(
                initial: entry.name.isNotEmpty ? entry.name[0] : '?',
                baseColor: avatarColor,
                size: 42,
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
                            entry.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (entry.nickname != null &&
                            entry.nickname!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            '« ${entry.nickname} »',
                            style: TextStyle(
                              color: context.colors.foreground500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'J ${entry.matchesPlayed} match${entry.matchesPlayed > 1 ? 's' : ''}',
                      style: TextStyle(
                        color: context.colors.foreground400,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMiniCardBadge(
                    context,
                    color: context.colors.card,
                    count: entry.yellowCards,
                  ),
                  const SizedBox(width: 6),
                  _buildMiniCardBadge(
                    context,
                    color: context.colors.danger,
                    count: entry.redCards,
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Icon(
                Remix.arrow_right_s_line,
                color: context.colors.foreground500,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniCardBadge(
    BuildContext context, {
    required Color color,
    required int count,
  }) {
    final hasCards = count > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: hasCards
            ? color.withValues(alpha: 0.15)
            : context.colors.background800,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasCards
              ? color.withValues(alpha: 0.4)
              : context.colors.background700,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 13,
            decoration: BoxDecoration(
              color: hasCards ? color : context.colors.foreground600,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            '$count',
            style: TextStyle(
              color: hasCards ? color : context.colors.foreground500,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthSelectorBar extends ConsumerWidget {
  const _MonthSelectorBar();

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

  String _formatMonth(String monthStr) {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availableMonthsAsync = ref.watch(availableRankingMonthsProvider);
    final selectedMonth = ref.watch(selectedMvpMonthProvider);

    return availableMonthsAsync.maybeWhen(
      data: (months) {
        if (months.isEmpty) return const SizedBox.shrink();

        final activeMonth = selectedMonth ?? months.first;

        return Container(
          height: 48,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final month in months) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_formatMonth(month)),
                    selected: activeMonth == month,
                    onSelected: (selected) {
                      if (selected) {
                        ref
                            .read(selectedMvpMonthProvider.notifier)
                            .selectMonth(month);
                      }
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _MvpView extends ConsumerWidget {
  const _MvpView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mvpAsync = ref.watch(monthlyMvpRankingProvider);

    return Column(
      children: [
        const _MonthSelectorBar(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(monthlyMvpRankingProvider);
            },
            color: context.colors.primary500,
            backgroundColor: context.colors.background900,
            child: mvpAsync.when(
              data: (entries) {
                if (entries.isEmpty) {
                  return _buildEmptyState(
                    context,
                    'Aucune donnée MVP pour cette période',
                  );
                }

                return ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  children: [
                    for (final entry in entries) _buildMvpCard(context, entry),
                    const SizedBox(height: 16),
                    _buildMvpRulesCard(context),
                  ],
                );
              },
              loading: () => Center(
                child: CircularProgressIndicator(
                  color: context.colors.primary500,
                ),
              ),
              error: (err, stack) =>
                  _buildErrorState(context, err.toString(), () {
                    ref.invalidate(monthlyMvpRankingProvider);
                  }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMvpRulesCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.background900,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.background800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Remix.information_line,
                size: 16,
                color: context.colors.primary400,
              ),
              const SizedBox(width: 6),
              const Text(
                'Règles MVP & Éligibilité',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• Éligibilité : au moins N-1 séances jouées dans le mois (max 1 séance manquée).\n'
            '• Match : Victoire (+10 pts), Nul (+3 pts), Défaite (0 pt).\n'
            '• Actions : But (+2 pts), Passe décisive (+1 pt).\n'
            '• Fair-play : Carton jaune (-0.5 pt), Carton rouge (-1 pt).',
            style: TextStyle(
              color: context.colors.foreground400,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMvpCard(BuildContext context, MvpEntry entry) {
    final avatarColor = _getPlayerColor(context, entry.playerId);
    final isTopEligible = entry.rank == 1 && entry.isEligible;
    final cardBorderColor = isTopEligible
        ? const Color(0xFFFFD700)
        : entry.isEligible
        ? context.colors.background700
        : context.colors.background800;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => context.push('/joueurs/${entry.playerId}'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: isTopEligible
                ? const Color(0xFFFFD700).withValues(alpha: 0.08)
                : context.colors.background900,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: cardBorderColor,
              width: isTopEligible ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isTopEligible) ...[
                const Row(
                  children: [
                    Icon(
                      Remix.trophy_fill,
                      color: Color(0xFFFFD700),
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Joueur du mois',
                      style: TextStyle(
                        color: Color(0xFFFFD700),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ] else if (!entry.isEligible) ...[
                Row(
                  children: [
                    Icon(
                      Remix.information_line,
                      color: context.colors.warning,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Non éligible · ${entry.missingMatches} match(s) manquant(s)',
                      style: TextStyle(
                        color: context.colors.warning,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isTopEligible
                          ? const Color(0xFFFFD700).withValues(alpha: 0.2)
                          : context.colors.background800,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${entry.rank}',
                      style: TextStyle(
                        color: isTopEligible
                            ? const Color(0xFFFFD700)
                            : context.colors.foreground400,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  InitialAvatar(
                    initial: entry.name.isNotEmpty
                        ? entry.name[0].toUpperCase()
                        : '?',
                    baseColor: avatarColor,
                    size: 36,
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
                                  fontSize: 15,
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
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          '${entry.matchesPlayed}/${entry.totalSessions} MJ · ${entry.wins}V ${entry.draws}N ${entry.losses}D',
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
                        '${entry.score.toStringAsFixed(2)} pts',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: isTopEligible
                              ? const Color(0xFFFFD700)
                              : context.colors.primary400,
                        ),
                      ),
                      Text(
                        '${entry.goals} B · ${entry.assists} P · ${entry.yellowCards}J/${entry.redCards}R',
                        style: TextStyle(
                          color: context.colors.foreground500,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _getPlayerColor(BuildContext context, String playerId) {
  final palette = [
    context.colors.primary500,
    context.colors.secondary500,
    context.colors.accent500,
    context.colors.card,
    context.colors.primary400,
    context.colors.secondary400,
    context.colors.accent400,
  ];
  final hash = playerId.codeUnits.fold(0, (sum, elem) => sum + elem);
  return palette[hash % palette.length];
}

Widget _buildRankBadge(BuildContext context, int rank) {
  if (rank == 1) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.colors.card.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(Remix.medal_fill, color: context.colors.card, size: 16),
    );
  } else if (rank == 2) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.colors.foreground300.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Remix.medal_fill,
        color: context.colors.foreground300,
        size: 16,
      ),
    );
  } else if (rank == 3) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.colors.secondary500.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Remix.medal_fill,
        color: context.colors.secondary500,
        size: 16,
      ),
    );
  }
  return Container(
    width: 28,
    alignment: Alignment.center,
    child: Text(
      '$rank',
      style: TextStyle(
        color: context.colors.foreground500,
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
    ),
  );
}

Widget _buildEmptyState(BuildContext context, String message) {
  return LayoutBuilder(
    builder: (context, constraints) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Container(
            height: constraints.maxHeight > 0 ? constraints.maxHeight : 300,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Remix.trophy_line,
                  size: 56,
                  color: context.colors.foreground500,
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.colors.foreground400,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

Widget _buildErrorState(
  BuildContext context,
  String error,
  VoidCallback onRetry,
) {
  return LayoutBuilder(
    builder: (context, constraints) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Container(
            height: constraints.maxHeight > 0 ? constraints.maxHeight : 300,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Remix.error_warning_line,
                  size: 48,
                  color: context.colors.danger,
                ),
                const SizedBox(height: 12),
                Text(
                  'Erreur lors du chargement',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: context.colors.foreground100,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.foreground500,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Remix.refresh_line, size: 16),
                  label: const Text('Réessayer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.primary500,
                    foregroundColor: context.colors.background950,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}
