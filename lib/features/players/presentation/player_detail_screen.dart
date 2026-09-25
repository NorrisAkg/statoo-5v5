import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/initial_avatar.dart';

class PlayerDetailScreen extends StatelessWidget {
  final String playerId;

  const PlayerDetailScreen({super.key, required this.playerId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Remix.arrow_left_s_line),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/joueurs');
            }
          },
        ),
        title: const Text('Karim Benali'),
        actions: [
          IconButton(
            icon: const Icon(Remix.pencil_line),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildProfileHeader(context),
          const SizedBox(height: 32),
          _buildSynthesis(context),
          const SizedBox(height: 24),
          _buildRawStats(context),
          const SizedBox(height: 32),
          Text('HISTORIQUE (10)', style: TextStyle(color: context.colors.foreground400, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildHistoryList(context),
          const SizedBox(height: 24),
          _buildActionButtons(context),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    return Row(
      children: [
        InitialAvatar(initial: 'KB', baseColor: context.colors.primary500, size: 80),
        SizedBox(width: 24),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Karim Benali', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text('Kaka', style: TextStyle(color: context.colors.foreground400, fontSize: 16)),
          ],
        ),
      ],
    );
  }

  Widget _buildSynthesis(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.background900,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.background700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SYNTHÈSE', style: TextStyle(color: context.colors.foreground400, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildSynthesisItem(context, 'MATCHS (J)', '8')),
              Expanded(child: _buildSynthesisItem(context, 'V / N / D', '6 / 0 / 2')),
              Expanded(child: _buildSynthesisItem(context, 'POINTS', '18')),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildSynthesisItem(context, 'PTS/MATCH', '2.25')),
              Expanded(child: _buildSynthesisItem(context, '% VICTOIRES', '75 %')),
              Expanded(child: _buildSynthesisItem(context, 'APPARITIONS', '9')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSynthesisItem(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: context.colors.foreground400, fontSize: 10)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: context.colors.foreground50, fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildRawStats(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.background900,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.background700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('STATISTIQUES BRUTES', style: TextStyle(color: context.colors.foreground400, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildSynthesisItem(context, 'BUTS', '11')),
              Expanded(child: _buildSynthesisItem(context, 'PASSES', '2')),
              Expanded(child: _buildSynthesisItem(context, 'JAUNES', '2')),
              Expanded(child: _buildSynthesisItem(context, 'ROUGES', '1')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(BuildContext context) {
    return Column(
      children: [
        _buildHistoryItem(context, 'Aujourd\'hui', '4 - 3', 'Victoire', context.colors.primary500, context.colors.primary500.withValues(alpha: 0.1), '2', '0'),
        const SizedBox(height: 8),
        _buildHistoryItem(context, 'mar. 22', '7 - 2', 'Victoire', context.colors.primary500, context.colors.primary500.withValues(alpha: 0.1), '2', '0'),
        const SizedBox(height: 8),
        _buildHistoryItem(context, 'mar. 15 sept.', '7 - 4', 'Victoire', context.colors.primary500, context.colors.primary500.withValues(alpha: 0.1), '0', '0'),
        const SizedBox(height: 8),
        _buildHistoryItem(context, 'mar. 8 sept.', '4 - 1', 'Victoire', context.colors.primary500, context.colors.primary500.withValues(alpha: 0.1), '1', '0'),
        const SizedBox(height: 8),
        _buildHistoryItem(context, 'mar. 1 sept.', '6 - 4', 'Victoire', context.colors.primary500, context.colors.primary500.withValues(alpha: 0.1), '2', '0'),
        const SizedBox(height: 8),
        _buildHistoryItem(context, 'mar. 25 août.', '4 - 2', 'Victoire', context.colors.primary500, context.colors.primary500.withValues(alpha: 0.1), '2', '0'),
        const SizedBox(height: 8),
        _buildHistoryItem(context, 'mar. 18 août.', '6 - 6', 'Nul', context.colors.foreground300, context.colors.background800, '2', '2'),
        const SizedBox(height: 8),
        _buildHistoryItem(context, 'mar. 11 août.', '5 - 2', 'Victoire', context.colors.primary500, context.colors.primary500.withValues(alpha: 0.1), '0', '0'),
        const SizedBox(height: 8),
        _buildHistoryItem(context, 'mar. 4 août.', '5 - 6', 'Défaite', context.colors.danger, context.colors.danger.withValues(alpha: 0.1), '0', '0'),
        const SizedBox(height: 8),
        _buildHistoryItem(context, 'mar. 28 juil.', '3 - 4', 'Défaite', context.colors.danger, context.colors.danger.withValues(alpha: 0.1), '2', '0'),
      ],
    );
  }

  Widget _buildHistoryItem(BuildContext context, String date, String score, String statusText, Color statusColor, Color statusBgColor, String goals, String assists) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.background900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.background700),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: context.colors.accent500, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: const Text('A', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(date, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Remix.football_line, size: 14, color: context.colors.foreground400),
                    const SizedBox(width: 4),
                    Text(goals, style: TextStyle(color: context.colors.foreground400, fontSize: 12)),
                    const SizedBox(width: 8),
                    Text('·', style: TextStyle(color: context.colors.foreground400, fontSize: 12)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: context.colors.background700,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('A', style: TextStyle(color: context.colors.foreground400, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 4),
                    Text(assists, style: TextStyle(color: context.colors.foreground400, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          Text(score, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusBgColor,
              borderRadius: BorderRadius.circular(9999),
            ),
            child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Remix.pencil_line, size: 18),
            label: const Text('Éditer'),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.colors.foreground50,
              side: BorderSide(color: context.colors.background700),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Remix.archive_drawer_line, size: 18),
            label: const Text('Archiver'),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.colors.foreground50,
              side: BorderSide(color: context.colors.background700),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}
