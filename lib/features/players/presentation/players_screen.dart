import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/initial_avatar.dart';
import '../application/players_provider.dart';
import '../domain/player.dart';
import 'edit_player_bottom_sheet.dart';
import 'new_player_bottom_sheet.dart';

class PlayersScreen extends ConsumerWidget {
  const PlayersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playersAsync = ref.watch(playersListProvider);
    final deletableIdsAsync = ref.watch(deletablePlayerIdsProvider);
    final deletableIds = deletableIdsAsync.value ?? const <String>{};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Joueurs'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: playersAsync.when(
              data: (players) => Text(
                '${players.where((p) => p.isActive).length} actifs',
                style: TextStyle(color: context.colors.foreground400, fontSize: 14),
              ),
              loading: () => const SizedBox(),
              error: (_, _) => const SizedBox(),
            ),
          ),
        ),
      ),
      body: playersAsync.when(
        data: (players) {
          final activePlayers = players.where((p) => p.isActive).toList();
          final archivedPlayers = players.where((p) => !p.isActive).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSearchBar(context),
              const SizedBox(height: 24),
              Text(
                'ACTIFS (${activePlayers.length})',
                style: TextStyle(color: context.colors.foreground400, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (activePlayers.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text('Aucun joueur actif', style: TextStyle(color: context.colors.foreground500)),
                  ),
                )
              else
                ...activePlayers.map((p) => _buildPlayerCard(context, ref, p, deletableIds.contains(p.id))),
              const SizedBox(height: 16),
              if (archivedPlayers.isNotEmpty)
                _buildArchivedSection(context, ref, archivedPlayers, deletableIds),
            ],
          );
        },
        loading: () => Center(child: CircularProgressIndicator(color: context.colors.primary500)),
        error: (err, _) => Center(child: Text('Erreur: $err', style: TextStyle(color: context.colors.danger))),
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

  Widget _buildPlayerCard(BuildContext context, WidgetRef ref, Player player, bool canDelete) {
    final initial = player.name.isNotEmpty ? player.name[0].toUpperCase() : '?';
    final color = context.colors.primary500;

    final cardContent = Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => unawaited(context.push('/joueurs/${player.id}')),
        onLongPress: () => unawaited(_showPlayerOptions(context, ref, player, canDelete)),
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
                    Text(player.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    if (player.nickname != null && player.nickname!.isNotEmpty)
                      Text(player.nickname!, style: TextStyle(color: context.colors.foreground500, fontSize: 14)),
                  ],
                ),
              ),
              if (canDelete) ...[
                IconButton(
                  icon: Icon(Remix.delete_bin_line, size: 20, color: context.colors.danger),
                  tooltip: 'Supprimer ce joueur',
                  onPressed: () => unawaited(_confirmDeletePlayer(context, ref, player)),
                ),
              ] else ...[
                Text('-', style: TextStyle(color: context.colors.foreground400, fontSize: 14)),
                const SizedBox(width: 8),
                Icon(Remix.arrow_right_s_line, color: context.colors.foreground500),
              ],
            ],
          ),
        ),
      ),
    );

    if (canDelete) {
      return Dismissible(
        key: ValueKey('dismiss_player_${player.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          margin: const EdgeInsets.only(bottom: 8),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: context.colors.danger,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(Remix.delete_bin_line, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text(
                'Supprimer',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        confirmDismiss: (_) => _confirmDeletePlayer(context, ref, player),
        child: cardContent,
      );
    }

    return cardContent;
  }

  Widget _buildArchivedSection(
    BuildContext context,
    WidgetRef ref,
    List<Player> archivedPlayers,
    Set<String> deletableIds,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Remix.archive_drawer_line, color: context.colors.foreground500, size: 16),
            const SizedBox(width: 8),
            Text(
              'ARCHIVÉS (${archivedPlayers.length})',
              style: TextStyle(color: context.colors.foreground400, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...archivedPlayers.map(
          (p) => _buildPlayerCard(context, ref, p, deletableIds.contains(p.id)),
        ),
      ],
    );
  }

  Future<bool> _confirmDeletePlayer(BuildContext context, WidgetRef ref, Player player) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: context.colors.background900,
          title: Text('Supprimer ${player.name} ?'),
          content: Text(
            "Ce joueur n'a participé à aucune séance. Sa suppression sera immédiate et définitive.",
            style: TextStyle(color: context.colors.foreground300),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Annuler', style: TextStyle(color: context.colors.foreground400)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.danger,
                foregroundColor: Colors.white,
              ),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final success = await ref.read(playersListProvider.notifier).removePlayer(player.id);
      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Le joueur "${player.name}" a été supprimé.')),
          );
          return true;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Impossible de supprimer ce joueur : il a déjà participé à une séance.'),
            ),
          );
        }
      }
    }
    return false;
  }

  Future<void> _showPlayerOptions(
    BuildContext context,
    WidgetRef ref,
    Player player,
    bool canDelete,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colors.background900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  player.name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(Remix.pencil_line),
                title: const Text('Modifier le joueur'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  unawaited(showModalBottomSheet<bool>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => EditPlayerBottomSheet(player: player),
                  ));
                },
              ),
              if (canDelete)
                ListTile(
                  leading: Icon(Remix.delete_bin_line, color: context.colors.danger),
                  title: Text(
                    'Supprimer définitivement',
                    style: TextStyle(color: context.colors.danger),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    unawaited(_confirmDeletePlayer(context, ref, player));
                  },
                )
              else
                ListTile(
                  leading: Icon(
                    player.isActive ? Remix.archive_drawer_line : Remix.check_line,
                  ),
                  title: Text(player.isActive ? 'Archiver le joueur' : 'Activer le joueur'),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await ref.read(playersListProvider.notifier).togglePlayerActive(
                      id: player.id,
                      isActive: !player.isActive,
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
