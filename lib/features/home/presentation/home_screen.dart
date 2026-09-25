import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/primary_button.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
          _buildLastSession(context),
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
          _buildTiles(context),
          const SizedBox(height: 32),
          _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildLastSession(BuildContext context) {
    return AppCard(
      onTap: () => context.push('/seances/s9'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('9 sept.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.colors.foreground400)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: context.colors.primary500.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text('Clôturée', style: TextStyle(color: context.colors.primary500, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTeamDot(context.colors.accent500),
              const SizedBox(width: 12),
              const Text('5', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('-', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: context.colors.foreground600)),
              ),
              const Text('3', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900)),
              const SizedBox(width: 12),
              _buildTeamDot(context.colors.secondary500),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: context.colors.background700, height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: context.colors.background800,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: const Text('5v5', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Text('10 joueurs', style: TextStyle(color: context.colors.foreground400, fontSize: 12)),
              const Spacer(),
              Icon(Remix.arrow_right_s_line, color: context.colors.foreground400, size: 20),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTeamDot(Color color) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _buildRankingRow(context, 1, 'L', 'Lucas', 'Lulu', 30, 14, context.colors.card),
          Divider(color: context.colors.background700, height: 1),
          _buildRankingRow(context, 2, 'Y', 'Yassine', 'Yass', 30, 14, context.colors.foreground300),
          Divider(color: context.colors.background700, height: 1),
          _buildRankingRow(context, 3, 'M', 'Mehdi', 'Didi', 29, 12, context.colors.secondary500),
        ],
      ),
    );
  }

  Widget _buildRankingRow(BuildContext context, int rank, String initial, String name, String nickname, int pts, int games, Color medalColor) {
    return InkWell(
      onTap: () => context.push('/joueurs/p$rank'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 24,
              alignment: Alignment.center,
              child: Text('$rank', style: TextStyle(color: medalColor, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.colors.primary500.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Text(initial, style: TextStyle(color: context.colors.primary500, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('« $nickname »', style: TextStyle(color: context.colors.foreground500, fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$pts pts', style: TextStyle(fontWeight: FontWeight.bold, color: context.colors.primary400)),
                Text('J $games', style: TextStyle(color: context.colors.foreground500, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTiles(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _buildTile(context, Remix.user_line, 'Joueurs', '14')),
        const SizedBox(width: 12),
        Expanded(child: _buildTile(context, Remix.calendar_event_line, 'Séances', '7')),
        const SizedBox(width: 12),
        Expanded(child: _buildTile(context, Remix.pie_chart_line, 'Stats', '')),
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
        Text('Sauvegardé il y a 2 h', style: TextStyle(color: context.colors.foreground500, fontSize: 12)),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {},
          child: Text('Sauvegarder', style: TextStyle(color: context.colors.primary400, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
