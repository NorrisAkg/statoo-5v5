import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/initial_avatar.dart';
import 'new_player_bottom_sheet.dart';

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
            child: Text('12 actifs', style: TextStyle(color: context.colors.foreground400, fontSize: 14)),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSearchBar(context),
          const SizedBox(height: 24),
          Text('ACTIFS (12)', style: TextStyle(color: context.colors.foreground400, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildPlayerCard(context, 'Adil Chraibi', 'Dida', 'A', context.colors.primary500, 7, 6),
          _buildPlayerCard(context, 'Anas Berrada', 'Nono', 'A', context.colors.secondary500, 6, 15),
          _buildPlayerCard(context, 'Hamza Sekkat', '', 'H', context.colors.danger, 6, 12),
          _buildPlayerCard(context, 'Karim Benali', 'Kaka', 'K', context.colors.primary400, 8, 18),
          _buildPlayerCard(context, 'Mehdi Ouali', '', 'M', context.colors.danger, 7, 15),
          const SizedBox(height: 16),
          _buildArchivedSection(context),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const NewPlayerBottomSheet(),
          );
        },
        backgroundColor: context.colors.primary500,
        foregroundColor: context.colors.background950,
        child: const Icon(Remix.add_line),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.background900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.background700),
      ),
      child: Row(
        children: [
          Icon(Remix.search_line, color: context.colors.foreground500),
          const SizedBox(width: 12),
          Text('Rechercher un joueur', style: TextStyle(color: context.colors.foreground500, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildPlayerCard(BuildContext context, String name, String nickname, String initial, Color color, int games, int pts) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => context.push('/joueurs/p1'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colors.background900,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.colors.background700),
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
                    if (nickname.isNotEmpty) Text(nickname, style: TextStyle(color: context.colors.foreground500, fontSize: 14)),
                  ],
                ),
              ),
              Text('J $games · $pts pts', style: TextStyle(color: context.colors.foreground400, fontSize: 14)),
              const SizedBox(width: 8),
              Icon(Remix.arrow_right_s_line, color: context.colors.foreground500),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArchivedSection(BuildContext context) {
    return Row(
      children: [
        Icon(Remix.arrow_right_s_line, color: context.colors.foreground500),
        const SizedBox(width: 8),
        Text('ARCHIVÉS (2)', style: TextStyle(color: context.colors.foreground400, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
