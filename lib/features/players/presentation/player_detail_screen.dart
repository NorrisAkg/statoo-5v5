import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/initial_avatar.dart';
import '../../../core/widgets/status_badge.dart';

class PlayerDetailScreen extends StatelessWidget {
  final String playerId;

  const PlayerDetailScreen({super.key, required this.playerId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Remix.arrow_left_line),
          onPressed: () => context.pop(),
        ),
        title: const Text('Lucas'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildProfileHeader(context),
          const SizedBox(height: 32),
          Text('Synthèse', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          _buildSynthesis(context),
          const SizedBox(height: 32),
          Text('Statistiques brutes', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          _buildRawStats(context),
          const SizedBox(height: 32),
          Text('Historique des séances', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          _buildHistoryList(context),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    return Column(
      children: [
        const InitialAvatar(initial: 'L', baseColor: AppColors.primary500, size: 80),
        const SizedBox(height: 16),
        const Text('Lucas', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const Text('« Lulu »', style: TextStyle(color: AppColors.foreground400, fontSize: 16)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildPill('J 14', AppColors.background800),
            const SizedBox(width: 8),
            _buildPill('30 pts', AppColors.primary500.withOpacity(0.15), textColor: AppColors.primary400),
            const SizedBox(width: 8),
            _buildPill('9 buts', AppColors.background800),
          ],
        ),
      ],
    );
  }

  Widget _buildPill(String text, Color bgColor, {Color? textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(9999)),
      child: Text(text, style: TextStyle(color: textColor ?? AppColors.foreground50, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSynthesis(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildSynthesisItem('Matchs joués', '14')),
              Expanded(child: _buildSynthesisItem('V / N / D', '9 / 3 / 2')),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.background700, height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildSynthesisItem('Points', '30', valueColor: AppColors.primary400)),
              Expanded(child: _buildSynthesisItem('Pts / match', '2.14')),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.background700, height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildSynthesisItem('% victoires', '64 %')),
              Expanded(child: _buildSynthesisItem('Format préféré', '5v5')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSynthesisItem(String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.foreground400, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: valueColor ?? AppColors.foreground50, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildRawStats(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              _buildStatTile(Remix.football_line, 'Buts', '9', AppColors.foreground50),
              const SizedBox(height: 12),
              _buildStatTile(Remix.file_warning_line, 'C. Jaunes', '1', AppColors.card),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              _buildStatTile(Remix.arrow_right_up_line, 'Passes déc.', '11', AppColors.accent400),
              const SizedBox(height: 12),
              _buildStatTile(Remix.alarm_warning_line, 'C. Rouges', '0', AppColors.danger),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatTile(IconData icon, String label, String value, Color color) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(color: AppColors.foreground400, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildHistoryList(BuildContext context) {
    return Column(
      children: [
        _buildHistoryItem(context, '9 sept.', BadgeStatus.win, '5v5', '5', '3', '2 buts, 1 passe', AppColors.primary500),
        const SizedBox(height: 12),
        _buildHistoryItem(context, '5 sept.', BadgeStatus.draw, '5v5', '4', '4', '1 but', AppColors.foreground400),
        const SizedBox(height: 12),
        _buildHistoryItem(context, '2 sept.', BadgeStatus.draw, '4v4', '0', '0', '', AppColors.foreground400),
        const SizedBox(height: 12),
        _buildHistoryItem(context, '29 août', BadgeStatus.win, '5v5', '6', '4', '3 buts', AppColors.primary500),
        const SizedBox(height: 12),
        _buildHistoryItem(context, '22 août', BadgeStatus.loss, '5v5', '2', '3', '1 passe, 1 jaune', AppColors.danger),
        const SizedBox(height: 12),
        _buildHistoryItem(context, '15 août', BadgeStatus.friendly, '6v6', '7', '6', '3 buts, 2 passes', AppColors.warning),
        const SizedBox(height: 12),
        _buildHistoryItem(context, '8 août', BadgeStatus.draw, '5v5', '5', '5', '2 buts', AppColors.foreground400),
      ],
    );
  }

  Widget _buildHistoryItem(BuildContext context, String date, BadgeStatus status, String format, String score1, String score2, String stats, Color statusColor) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background900,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.background700, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(width: 4, color: statusColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(date, style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          StatusBadge(status: status),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.background800, borderRadius: BorderRadius.circular(4)),
                            child: Text(format, style: const TextStyle(fontSize: 10, color: AppColors.foreground400)),
                          ),
                          const SizedBox(height: 8),
                          Text('$score1 - $score2', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: statusColor)),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (stats.isNotEmpty)
                            Text(stats, textAlign: TextAlign.right, style: const TextStyle(color: AppColors.foreground400, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
