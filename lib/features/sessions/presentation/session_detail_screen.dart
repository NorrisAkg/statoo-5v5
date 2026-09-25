import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/initial_avatar.dart';

class SessionDetailScreen extends StatelessWidget {
  final String sessionId;

  const SessionDetailScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Remix.arrow_left_line),
          onPressed: () => context.pop(),
        ),
        title: const Text('Détail séance'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(context),
          const SizedBox(height: 32),
          Text('Composition', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          _buildCompositions(context),
          const SizedBox(height: 32),
          Text('Statistiques joueurs', style: Theme.of(context).textTheme.titleMedium),
          Text('buts · passes · cartons', style: TextStyle(color: context.colors.foreground500, fontSize: 12)),
          const SizedBox(height: 16),
          _buildPlayerStats(context),
          const SizedBox(height: 32),
          _buildUnassignedGoals(context),
          const SizedBox(height: 32),
          _buildActions(context),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const StatusBadge(status: BadgeStatus.closed),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: context.colors.background800, borderRadius: BorderRadius.circular(9999)),
              child: const Text('5v5', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text('mer. 9 sept. 2026 · 20h30', style: TextStyle(color: context.colors.foreground400, fontSize: 14)),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildTeamScore('Équipe A', 5, context.colors.accent500),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text('-', style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: context.colors.foreground600)),
            ),
            _buildTeamScore('Équipe B', 3, context.colors.secondary500),
          ],
        ),
      ],
    );
  }

  Widget _buildTeamScore(String name, int score, Color color) {
    return Column(
      children: [
        Text(name, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('$score', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildCompositions(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildTeamList(context, 'Équipe A', context.colors.accent500, ['Lucas', 'Karim', 'Sofiane', 'Mehdi', 'Hugo'])),
        const SizedBox(width: 16),
        Expanded(child: _buildTeamList(context, 'Équipe B', context.colors.secondary500, ['Yassine', 'Théo', 'Benjamin', 'Nicolas', 'Enzo'])),
      ],
    );
  }

  Widget _buildTeamList(BuildContext context, String title, Color color, List<String> players) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Text('${players.length} joueurs', style: TextStyle(color: context.colors.foreground500, fontSize: 12)),
          const SizedBox(height: 16),
          ...players.map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                InitialAvatar(initial: p[0], baseColor: context.colors.foreground300, size: 24),
                const SizedBox(width: 8),
                Text(p, style: const TextStyle(fontSize: 14)),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildPlayerStats(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _buildStatRow(context, 'Lucas', context.colors.accent500, 2, 1, 0, 0),
          Divider(color: context.colors.background700, height: 1),
          _buildStatRow(context, 'Mehdi', context.colors.accent500, 1, 0, 1, 0),
          Divider(color: context.colors.background700, height: 1),
          _buildStatRow(context, 'Yassine', context.colors.secondary500, 3, 0, 0, 0),
        ],
      ),
    );
  }

  Widget _buildStatRow(BuildContext context, String name, Color teamColor, int goals, int assists, int yellows, int reds) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: teamColor, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w500))),
          if (goals > 0) _buildStatPill(context, '$goals', Remix.football_line, context.colors.foreground200),
          if (assists > 0) _buildStatPill(context, '$assists', Remix.arrow_right_up_line, context.colors.accent400),
          if (yellows > 0) _buildStatPill(context, '$yellows', null, context.colors.card, isCard: true),
          if (reds > 0) _buildStatPill(context, '$reds', null, context.colors.danger, isCard: true),
        ],
      ),
    );
  }

  Widget _buildStatPill(BuildContext context, String val, IconData? icon, Color color, {bool isCard = false}) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Row(
        children: [
          Text(val, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(width: 4),
          if (icon != null) Icon(icon, color: color, size: 14),
          if (isCard) Container(width: 10, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        ],
      ),
    );
  }

  Widget _buildUnassignedGoals(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Buts non attribués', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: AppCard(padding: EdgeInsets.all(16), child: Center(child: Text('Équipe A : 2', style: TextStyle(color: context.colors.accent400))))),
            const SizedBox(width: 16),
            Expanded(child: AppCard(padding: EdgeInsets.all(16), child: Center(child: Text('Équipe B : 0', style: TextStyle(color: context.colors.secondary400))))),
          ],
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              foregroundColor: context.colors.foreground50,
              side: BorderSide(color: context.colors.background700),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
            ),
            child: const Text('Rouvrir la séance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              foregroundColor: context.colors.danger,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Supprimer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}
