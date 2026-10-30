import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/player_sort.dart';
import '../../../core/widgets/app_bar_subtitle.dart';
import '../../../core/widgets/initial_avatar.dart';
import '../../../core/widgets/player_avatar.dart';
import '../../ranking/application/ranking_providers.dart';
import '../../ranking/domain/standing_entry.dart';
import '../../shared/application/shared_providers.dart';
import '../../team/application/team_provider.dart';
import '../../team/presentation/team_switcher_bottom_sheet.dart';
import '../application/players_provider.dart';
import '../domain/player.dart';
import 'edit_player_bottom_sheet.dart';
import 'new_player_bottom_sheet.dart';

class PlayersScreen extends ConsumerStatefulWidget {
  const PlayersScreen({super.key});

  @override
  ConsumerState<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends ConsumerState<PlayersScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final query = _searchController.text.trim().toLowerCase();
      if (query != _searchQuery) {
        setState(() {
          _searchQuery = query;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final writable = ref.watch(canWriteProvider('members'));
    final playersAsync = ref.watch(playersListProvider);
    final deletableIdsAsync = ref.watch(deletablePlayerIdsProvider);
    final deletableIds = deletableIdsAsync.value ?? const <String>{};
    final activeTeam = ref.watch(activeTeamProvider).value;
    final standingsAsync = ref.watch(standingsProvider);
    final standingsMap = {
      for (final s in standingsAsync.value ?? const <StandingEntry>[])
        s.playerId: s,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Joueurs'),
        actions: [
          IconButton(
            icon: const Icon(Remix.arrow_left_right_line),
            tooltip: 'Changer de groupe',
            onPressed: () => showTeamSwitcher(context),
          ),
        ],
        bottom: playersAsync.hasValue
            ? buildAppBarSubtitle(
                context,
                '${playersAsync.value!.where((p) => p.isActive).length} actifs${activeTeam != null ? ' · ${activeTeam.name}' : ''}',
              )
            : null,
      ),
      body: playersAsync.when(
        data: (players) {
          final query = _searchQuery;
          bool matchesQuery(Player p) {
            if (query.isEmpty) return true;
            final nameMatch = p.name.toLowerCase().contains(query);
            final nickMatch =
                p.nickname?.toLowerCase().contains(query) ?? false;
            return nameMatch || nickMatch;
          }

          final activePlayers =
              players.where((p) => p.isActive && matchesQuery(p)).toList()
                ..sort(comparePlayersAlphabetically);
          final archivedPlayers =
              players.where((p) => !p.isActive && matchesQuery(p)).toList()
                ..sort(comparePlayersAlphabetically);
          final hasNoResults =
              query.isNotEmpty &&
              activePlayers.isEmpty &&
              archivedPlayers.isEmpty;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSearchBar(context),
              const SizedBox(height: 24),
              if (hasNoResults)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Remix.user_search_line,
                          size: 48,
                          color: context.colors.foreground600,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Aucun joueur trouvé pour "$_searchQuery"',
                          style: TextStyle(
                            color: context.colors.foreground400,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                Text(
                  'ACTIFS (${activePlayers.length})',
                  style: TextStyle(
                    color: context.colors.foreground400,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (activePlayers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'Aucun joueur actif',
                        style: TextStyle(color: context.colors.foreground500),
                      ),
                    ),
                  )
                else
                  ...activePlayers.map(
                    (p) => _buildPlayerCard(
                      context,
                      p,
                      deletableIds.contains(p.id),
                      standing: standingsMap[p.id],
                    ),
                  ),
                const SizedBox(height: 16),
                if (archivedPlayers.isNotEmpty)
                  _buildArchivedSection(
                    context,
                    archivedPlayers,
                    deletableIds,
                    standingsMap,
                  ),
              ],
            ],
          );
        },
        loading: () => Center(
          child: CircularProgressIndicator(color: context.colors.primary500),
        ),
        error: (err, _) => Center(
          child: Text(
            'Erreur: $err',
            style: TextStyle(color: context.colors.danger),
          ),
        ),
      ),
      floatingActionButton: writable
          ? FloatingActionButton(
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
            )
          : null,
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return TextField(
      controller: _searchController,
      style: TextStyle(color: context.colors.foreground50, fontSize: 15),
      decoration: InputDecoration(
        hintText: 'Rechercher un joueur…',
        hintStyle: TextStyle(color: context.colors.foreground500, fontSize: 15),
        prefixIcon: Icon(
          Remix.search_line,
          color: context.colors.foreground500,
          size: 20,
        ),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: Icon(
                  Remix.close_circle_fill,
                  color: context.colors.foreground500,
                  size: 18,
                ),
                onPressed: _searchController.clear,
              )
            : null,
        filled: true,
        fillColor: context.colors.background900,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colors.background700),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colors.background700),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colors.primary500),
        ),
      ),
    );
  }

  Widget _buildPlayerCard(
    BuildContext context,
    Player player,
    bool deletable, {
    StandingEntry? standing,
  }) {
    final writable = ref.watch(canWriteProvider('members'));
    final canDelete = deletable && writable;
    final initial = player.name.isNotEmpty ? player.name[0].toUpperCase() : '?';
    final color = InitialAvatar.colorForName(player.name);

    final cardContent = Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => unawaited(context.push('/joueurs/${player.id}')),
        onLongPress: writable
            ? () => unawaited(_showPlayerOptions(player, canDelete))
            : null,
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
              PlayerAvatar(source: player.avatarUrl, initial: initial, baseColor: color, size: 48),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (player.nickname != null && player.nickname!.isNotEmpty)
                      Text(
                        player.nickname!,
                        style: TextStyle(
                          color: context.colors.foreground500,
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
              ),
              if (canDelete) ...[
                IconButton(
                  icon: Icon(
                    Remix.delete_bin_line,
                    size: 20,
                    color: context.colors.danger,
                  ),
                  tooltip: 'Supprimer ce joueur',
                  onPressed: () => unawaited(_confirmDeletePlayer(player)),
                ),
              ] else ...[
                Text(
                  standing != null && standing.matchesPlayed > 0
                      ? 'J ${standing.matchesPlayed} · ${standing.points} pts'
                      : '-',
                  style: TextStyle(
                    color: context.colors.foreground400,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Remix.arrow_right_s_line,
                  color: context.colors.foreground500,
                ),
              ],
            ],
          ),
        ),
      ),
    );

    final renderedCard = player.isActive
        ? cardContent
        : Opacity(opacity: 0.65, child: cardContent);

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
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        confirmDismiss: (_) => _confirmDeletePlayer(player),
        child: renderedCard,
      );
    }

    return renderedCard;
  }

  Widget _buildArchivedSection(
    BuildContext context,
    List<Player> archivedPlayers,
    Set<String> deletableIds,
    Map<String, StandingEntry> standingsMap,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Remix.archive_drawer_line,
              color: context.colors.foreground500,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              'ARCHIVÉS (${archivedPlayers.length})',
              style: TextStyle(
                color: context.colors.foreground400,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...archivedPlayers.map(
          (p) => _buildPlayerCard(
            context,
            p,
            deletableIds.contains(p.id),
            standing: standingsMap[p.id],
          ),
        ),
      ],
    );
  }

  Future<bool> _confirmDeletePlayer(Player player) async {
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
              child: Text(
                'Annuler',
                style: TextStyle(color: context.colors.foreground400),
              ),
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
      final success = await ref
          .read(playersListProvider.notifier)
          .removePlayer(player.id);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Le joueur "${player.name}" a été supprimé.'),
            ),
          );
          return true;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Impossible de supprimer ce joueur : il a déjà participé à une séance.',
              ),
            ),
          );
        }
      }
    }
    return false;
  }

  Future<void> _showPlayerOptions(Player player, bool canDelete) async {
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
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Remix.pencil_line),
                title: const Text('Modifier le joueur'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  unawaited(
                    showModalBottomSheet<bool>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => EditPlayerBottomSheet(player: player),
                    ),
                  );
                },
              ),
              if (canDelete)
                ListTile(
                  leading: Icon(
                    Remix.delete_bin_line,
                    color: context.colors.danger,
                  ),
                  title: Text(
                    'Supprimer définitivement',
                    style: TextStyle(color: context.colors.danger),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    unawaited(_confirmDeletePlayer(player));
                  },
                )
              else
                ListTile(
                  leading: Icon(
                    player.isActive
                        ? Remix.archive_drawer_line
                        : Remix.check_line,
                  ),
                  title: Text(
                    player.isActive
                        ? 'Archiver le joueur'
                        : 'Activer le joueur',
                  ),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    if (player.isActive) {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dCtx) => AlertDialog(
                          backgroundColor: context.colors.background900,
                          title: Text('Archiver ${player.name} ?'),
                          content: Text(
                            "Le joueur n'apparaîtra plus dans la sélection des séances. Son historique et ses statistiques restent intégralement conservés.",
                            style: TextStyle(
                              color: context.colors.foreground300,
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(dCtx).pop(false),
                              child: Text(
                                'Annuler',
                                style: TextStyle(
                                  color: context.colors.foreground400,
                                ),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.of(dCtx).pop(true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: context.colors.warning,
                                foregroundColor: context.colors.background950,
                              ),
                              child: const Text('Archiver'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true || !mounted) return;
                    }
                    await ref
                        .read(playersListProvider.notifier)
                        .togglePlayerActive(
                          id: player.id,
                          isActive: !player.isActive,
                        );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            player.isActive
                                ? 'Le joueur "${player.name}" a été archivé.'
                                : 'Le joueur "${player.name}" a été réactivé.',
                          ),
                        ),
                      );
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
