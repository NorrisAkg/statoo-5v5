import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:remixicon/remixicon.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../players/application/players_provider.dart';
import '../../sessions/application/sessions_provider.dart';
import '../../sessions/domain/session.dart';
import '../../sessions/domain/session_summary.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeDraftAsync = ref.watch(activeDraftSessionProvider);
    final sessionsAsync = ref.watch(sessionsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accueil'),
        actions: [
          IconButton(
            icon: const Icon(Remix.settings_4_line),
            onPressed: () => context.push('/reglages'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSessionHeader(context, activeDraftAsync.value, sessionsAsync.value),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Nouvelle séance',
            icon: Remix.add_line,
            onPressed: () => context.push('/seances/nouvelle'),
          ),
          const SizedBox(height: 32),
          _buildSectionHeader(context, 'Classement', '/classement'),
          const SizedBox(height: 16),
          _buildRanking(context),
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
      final playedAtStr = DateFormat("EEE d MMM · HH'h'mm", 'fr_FR').format(activeDraft.playedAt);

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
                  style: TextStyle(color: context.colors.foreground400, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Équipe A', style: TextStyle(color: context.colors.accent400, fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                Text('${activeDraft.scoreA ?? 0}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('-', style: TextStyle(fontSize: 28, color: context.colors.foreground600)),
                ),
                Text('${activeDraft.scoreB ?? 0}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
                const SizedBox(width: 12),
                Text('Équipe B', style: TextStyle(color: context.colors.secondary400, fontWeight: FontWeight.bold)),
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
                  side: BorderSide(color: context.colors.warning.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  Icon(Remix.check_double_line, size: 16, color: context.colors.primary500),
                  const SizedBox(width: 6),
                  Text('Dernière séance', style: TextStyle(color: context.colors.primary400, fontWeight: FontWeight.bold, fontSize: 13)),
                  const Spacer(),
                  Text(recentClosed.formattedDateTime, style: TextStyle(color: context.colors.foreground400, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Équipe A', style: TextStyle(color: context.colors.accent400, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 12),
                  Text('${s.scoreA ?? 0}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('-', style: TextStyle(fontSize: 24, color: context.colors.foreground600)),
                  ),
                  Text('${s.scoreB ?? 0}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                  const SizedBox(width: 12),
                  Text('Équipe B', style: TextStyle(color: context.colors.secondary400, fontWeight: FontWeight.w600)),
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
          Icon(Remix.football_line, size: 48, color: context.colors.primary500.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'Aucune séance pour le moment',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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

  Widget _buildSectionHeader(BuildContext context, String title, String route) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        GestureDetector(
          onTap: () => context.go(route),
          child: Text('Voir tout', style: TextStyle(color: context.colors.primary400, fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildRanking(BuildContext context) {
    return AppCard(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(Remix.medal_line, size: 32, color: context.colors.foreground600),
              const SizedBox(height: 8),
              Text(
                'Le classement est vide',
                style: TextStyle(color: context.colors.foreground400, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                "Clôturez une séance classée pour l'alimenter.",
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.foreground500, fontSize: 12),
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

    return Row(
      children: [
        Expanded(child: _buildTile(context, Remix.user_line, 'Joueurs', playersCount)),
        const SizedBox(width: 12),
        Expanded(child: _buildTile(context, Remix.calendar_event_line, 'Séances', sessionsCount)),
        const SizedBox(width: 12),
        Expanded(child: _buildTile(context, Remix.pie_chart_line, 'Stats', '-')),
      ],
    );
  }

  Widget _buildTile(BuildContext context, IconData icon, String title, String value) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: context.colors.primary500, size: 24),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(color: context.colors.foreground400, fontSize: 12)),
          if (value.isNotEmpty) Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Remix.cloud_windy_line, color: context.colors.foreground500, size: 16),
        const SizedBox(width: 8),
        Text('Aucune sauvegarde cloud', style: TextStyle(color: context.colors.foreground500, fontSize: 12)),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => context.push('/reglages'),
          child: Text('Sauvegarder', style: TextStyle(color: context.colors.primary400, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
