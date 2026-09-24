import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/initial_avatar.dart';

class PlayersScreen extends StatelessWidget {
  const PlayersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Joueurs'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const Text('12 actifs', style: TextStyle(color: AppColors.foreground400, fontSize: 14)),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSearchBar(),
          const SizedBox(height: 24),
          const Text('ACTIFS (12)', style: TextStyle(color: AppColors.foreground400, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildPlayerCard(context, 'Adil Chraibi', 'Dida', 'A', AppColors.primary500, 7, 6),
          _buildPlayerCard(context, 'Anas Berrada', 'Nono', 'A', AppColors.secondary500, 6, 15),
          _buildPlayerCard(context, 'Hamza Sekkat', '', 'H', AppColors.danger, 6, 12),
          _buildPlayerCard(context, 'Karim Benali', 'Kaka', 'K', AppColors.primary400, 8, 18),
          _buildPlayerCard(context, 'Mehdi Ouali', '', 'M', AppColors.danger, 7, 15),
          const SizedBox(height: 16),
          _buildArchivedSection(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: AppColors.primary500,
        foregroundColor: AppColors.background950,
        child: const Icon(Remix.add_line),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.background700),
      ),
      child: const Row(
        children: [
          Icon(Remix.search_line, color: AppColors.foreground500),
          SizedBox(width: 12),
          Text('Rechercher un joueur', style: TextStyle(color: AppColors.foreground500, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildPlayerCard(BuildContext context, String name, String nickname, String initial, Color color, int games, int pts) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => context.go('/joueurs/p1'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.background900,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.background700),
          ),
          child: Row(
            children: [
              InitialAvatar(initial: initial, baseColor: color, size: 48),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    if (nickname.isNotEmpty) Text(nickname, style: const TextStyle(color: AppColors.foreground500, fontSize: 14)),
                  ],
                ),
              ),
              Text('J $games · $pts pts', style: const TextStyle(color: AppColors.foreground400, fontSize: 14)),
              const SizedBox(width: 8),
              const Icon(Remix.arrow_right_s_line, color: AppColors.foreground500),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArchivedSection() {
    return Row(
      children: [
        const Icon(Remix.arrow_right_s_line, color: AppColors.foreground500),
        const SizedBox(width: 8),
        const Text('ARCHIVÉS (2)', style: TextStyle(color: AppColors.foreground400, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
