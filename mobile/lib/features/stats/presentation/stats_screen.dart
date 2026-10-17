import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/responsive_grid.dart';
import '../application/stats_providers.dart';
import '../domain/group_totals.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalsAsync = ref.watch(groupTotalsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Statistiques'), centerTitle: false),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(groupTotalsProvider);
        },
        color: context.colors.primary500,
        backgroundColor: context.colors.background900,
        child: totalsAsync.when(
          data: (totals) => _buildDashboard(context, totals),
          loading: () => Center(
            child: CircularProgressIndicator(color: context.colors.primary500),
          ),
          error: (err, stack) => _buildErrorState(context, err.toString(), () {
            ref.invalidate(groupTotalsProvider);
          }),
        ),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, GroupTotals totals) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        _buildHeroOverview(context, totals),
        const SizedBox(height: 24),
        _buildSectionTitle(
          context,
          'ATTAQUE & EFFICACITÉ',
          Remix.football_line,
        ),
        const SizedBox(height: 12),
        _buildOffenseGrid(context, totals),
        const SizedBox(height: 24),
        _buildSectionTitle(
          context,
          'DISCIPLINE & ARBITRAGE',
          Remix.shield_line,
        ),
        const SizedBox(height: 12),
        _buildDisciplineRow(context, totals),
        const SizedBox(height: 24),
        _buildSectionTitle(
          context,
          'INTÉGRITÉ DES DONNÉES',
          Remix.shield_check_line,
        ),
        const SizedBox(height: 12),
        _buildConsistencyCard(context, totals),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: context.colors.primary400),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: context.colors.foreground400,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroOverview(BuildContext context, GroupTotals totals) {
    return ResponsiveGrid(
      children: [
        _KpiCard(
          title: 'Séances jouées',
          value: '${totals.totalSessions}',
          subtitle:
              '${totals.rankedSessions} classées${totals.friendlySessions > 0 ? " · ${totals.friendlySessions} amicales" : ""}',
          icon: Remix.calendar_event_line,
          iconColor: context.colors.primary500,
        ),
        _KpiCard(
          title: 'Joueurs actifs',
          value: '${totals.activePlayers}',
          subtitle: 'Sur ${totals.totalPlayers} inscrits au total',
          icon: Remix.team_line,
          iconColor: context.colors.accent400,
        ),
      ],
    );
  }

  Widget _buildOffenseGrid(BuildContext context, GroupTotals totals) {
    return Column(
      children: [
        ResponsiveGrid(
          children: [
            _KpiCard(
              title: 'Buts totaux',
              value: '${totals.totalGoals}',
              subtitle: 'Score global des séances',
              icon: Remix.football_line,
              iconColor: context.colors.primary400,
            ),
            _KpiCard(
              title: 'Moyenne / séance',
              value: totals.avgGoalsPerSession.toStringAsFixed(1),
              subtitle: 'Buts par rencontre',
              icon: Remix.speed_line,
              iconColor: context.colors.primary500,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _KpiCard(
          title: 'Passes décisives',
          value: '${totals.totalAssists}',
          subtitle: 'Enregistrées lors des séances',
          icon: Remix.magic_line,
          iconColor: context.colors.accent400,
          isFullWidth: true,
        ),
      ],
    );
  }

  Widget _buildDisciplineRow(BuildContext context, GroupTotals totals) {
    return ResponsiveGrid(
      children: [
        _KpiCard(
          title: 'Cartons jaunes',
          value: '${totals.totalYellowCards}',
          subtitle: 'Avertissements',
          icon: Remix.file_warning_line,
          iconColor: context.colors.card,
        ),
        _KpiCard(
          title: 'Cartons rouges',
          value: '${totals.totalRedCards}',
          subtitle: 'Expulsions',
          icon: Remix.alarm_warning_line,
          iconColor: context.colors.danger,
        ),
      ],
    );
  }

  Widget _buildConsistencyCard(BuildContext context, GroupTotals totals) {
    final hasDifference = totals.unassignedGoalsDifference > 0;

    if (hasDifference) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.colors.warning.withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.colors.warning.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Remix.error_warning_fill,
                    color: context.colors.warning,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Écart de buts détecté',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: context.colors.foreground50,
                        ),
                      ),
                      Text(
                        '${totals.unassignedGoalsDifference} but(s) non attribué(s)',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Le score total des séances (${totals.totalGoals} buts) dépasse la somme des buts individuels (${totals.totalPlayerGoals} buts). Cet écart correspond aux buts contre leur camp (CSC) ou non attribués.',
              style: TextStyle(
                fontSize: 12,
                color: context.colors.foreground300,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.primary500.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.colors.primary500.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.colors.primary500.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Remix.checkbox_circle_fill,
              color: context.colors.primary400,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cohérence parfaite',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: context.colors.foreground50,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '100% des buts marqués sont correctement attribués aux joueurs (${totals.totalGoals} buts au total).',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.foreground400,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    String error,
    VoidCallback onRetry,
  ) {
    return Center(
      child: Padding(
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
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    this.isFullWidth = false,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: isFullWidth
          ? Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.colors.foreground400,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.colors.foreground500,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: context.colors.foreground50,
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: iconColor, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: context.colors.foreground50,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: context.colors.foreground200,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colors.foreground500,
                  ),
                ),
              ],
            ),
    );
  }
}
