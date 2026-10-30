import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/initial_avatar.dart';
import '../../shared/application/shared_providers.dart';
import '../../team/application/team_provider.dart';
import '../application/players_provider.dart';
import '../domain/player.dart';
import '../domain/player_detail_data.dart';
import 'edit_player_bottom_sheet.dart';

class PlayerDetailScreen extends ConsumerWidget {
  const PlayerDetailScreen({required this.playerId, super.key});

  final String playerId;

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(activeTeamProvider);
    final writable = ref.watch(canWriteProvider('members'));
    final playerAsync = ref.watch(playerDetailProvider(playerId));
    final statsAsync = ref.watch(playerStatsProvider(playerId));
    final historyAsync = ref.watch(playerMatchHistoryProvider(playerId));
    final canDeleteAsync = ref.watch(canDeletePlayerProvider(playerId));

    return playerAsync.when(
      data: (player) {
        if (player == null) {
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
              title: const Text('Joueur introuvable'),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Remix.user_unfollow_line, size: 48, color: context.colors.foreground500),
                  const SizedBox(height: 16),
                  Text(
                    "Ce joueur n'existe pas ou a été supprimé.",
                    style: TextStyle(color: context.colors.foreground400, fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => context.go('/joueurs'),
                    child: const Text('Retour à la liste des joueurs'),
                  ),
                ],
              ),
            ),
          );
        }

        final stats = statsAsync.value ?? const PlayerDetailStats.empty();
        final history = historyAsync.value ?? const [];
        final canDelete = canDeleteAsync.value ?? (history.isEmpty && stats.appearances == 0);

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
            title: Text(player.name),
            actions: [if (writable) ...[
              IconButton(
                icon: const Icon(Remix.pencil_line),
                tooltip: 'Modifier le joueur',
                onPressed: () => unawaited(_showEditPlayerSheet(context, player)),
              ),
              if (canDelete)
                IconButton(
                  icon: const Icon(Remix.delete_bin_line),
                  tooltip: 'Supprimer le joueur',
                  onPressed: () => unawaited(_confirmDelete(context, ref, player)),
                ),
            ]],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildProfileHeader(context, player, stats),
              const SizedBox(height: 32),
              _buildSynthesis(context, stats),
              const SizedBox(height: 24),
              _buildRawStats(context, stats),
              const SizedBox(height: 32),
              Text(
                'HISTORIQUE (${history.length})',
                style: TextStyle(color: context.colors.foreground400, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildHistorySection(context, history),
              const SizedBox(height: 24),
              if (writable) _buildActionButtons(context, ref, player, canDelete),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Remix.arrow_left_s_line),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: const Text('Chargement...'),
        ),
        body: Center(
          child: CircularProgressIndicator(color: context.colors.primary500),
        ),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Remix.arrow_left_s_line),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: const Text('Erreur'),
        ),
        body: Center(
          child: Text('Erreur: $err', style: TextStyle(color: context.colors.danger)),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, Player player, PlayerDetailStats stats) {
    final initials = _getInitials(player.name);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InitialAvatar(initial: initials, baseColor: context.colors.primary500, size: 76),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                player.name,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, height: 1.2),
              ),
              if (player.nickname != null && player.nickname!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  '« ${player.nickname} »',
                  style: TextStyle(color: context.colors.foreground400, fontSize: 15),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildHeaderPill(context, 'J ${stats.matchesPlayed}', context.colors.foreground200, context.colors.background800),
                  _buildHeaderPill(context, '${stats.points} pts', context.colors.primary500, context.colors.primary500.withValues(alpha: 0.15)),
                  _buildHeaderPill(context, '${stats.goals} buts', context.colors.accent500, context.colors.accent500.withValues(alpha: 0.15)),
                  if (!player.isActive)
                    _buildHeaderPill(context, 'Archivé', context.colors.warning, context.colors.warning.withValues(alpha: 0.15)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderPill(BuildContext context, String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: textColor.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildSynthesis(BuildContext context, PlayerDetailStats stats) {
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
              Expanded(child: _buildSynthesisItem(context, 'MATCHS (J)', '${stats.matchesPlayed}')),
              Expanded(child: _buildSynthesisItem(context, 'V / N / D', '${stats.wins} / ${stats.draws} / ${stats.losses}')),
              Expanded(child: _buildSynthesisItem(context, 'POINTS', '${stats.points}', valueColor: context.colors.primary500)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildSynthesisItem(context, 'PTS/MATCH', stats.pointsPerMatch.toStringAsFixed(2))),
              Expanded(child: _buildSynthesisItem(context, '% VICTOIRES', '${(stats.winRate * 100).round()} %')),
              Expanded(child: _buildSynthesisItem(context, 'APPARITIONS', '${stats.appearances}')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSynthesisItem(BuildContext context, String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: context.colors.foreground400, fontSize: 10, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? context.colors.foreground50,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildRawStats(BuildContext context, PlayerDetailStats stats) {
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
              Expanded(child: _buildSynthesisItem(context, 'BUTS', '${stats.goals}')),
              Expanded(child: _buildSynthesisItem(context, 'PASSES', '${stats.assists}')),
              Expanded(child: _buildSynthesisItem(context, 'JAUNES', '${stats.yellowCards}')),
              Expanded(child: _buildSynthesisItem(context, 'ROUGES', '${stats.redCards}')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection(BuildContext context, List<PlayerMatchHistoryItem> history) {
    if (history.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        decoration: BoxDecoration(
          color: context.colors.background900,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.colors.background700),
        ),
        child: Column(
          children: [
            Icon(Remix.football_line, size: 40, color: context.colors.foreground600),
            const SizedBox(height: 12),
            Text(
              'Aucun match joué',
              style: TextStyle(color: context.colors.foreground100, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Les séances terminées auxquelles ce joueur participe apparaîtront ici.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.foreground500, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Column(
      children: history.map((item) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _buildHistoryCard(context, item),
      )).toList(),
    );
  }

  Widget _buildHistoryCard(BuildContext context, PlayerMatchHistoryItem item) {
    final (statusColor, statusBgColor) = switch (item.outcomeText) {
      'Victoire' => (context.colors.primary500, context.colors.primary500.withValues(alpha: 0.15)),
      'Défaite' => (context.colors.danger, context.colors.danger.withValues(alpha: 0.15)),
      'Nul' => (context.colors.foreground300, context.colors.background800),
      'Amical' => (context.colors.foreground200, context.colors.background700),
      _ => (context.colors.accent500, context.colors.accent500.withValues(alpha: 0.15)),
    };

    final teamColor = item.team == 'A' ? context.colors.accent500 : context.colors.primary500;

    return InkWell(
      onTap: () => unawaited(context.push('/seances/${item.sessionId}')),
      borderRadius: BorderRadius.circular(12),
      child: Container(
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
              decoration: BoxDecoration(color: teamColor, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(
                item.team,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.formattedDate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Remix.football_line, size: 14, color: context.colors.foreground400),
                      const SizedBox(width: 4),
                      Text('${item.goals}', style: TextStyle(color: context.colors.foreground400, fontSize: 12)),
                      const SizedBox(width: 8),
                      Text('·', style: TextStyle(color: context.colors.foreground400, fontSize: 12)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: context.colors.background700,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('P', style: TextStyle(color: context.colors.foreground400, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 4),
                      Text('${item.assists}', style: TextStyle(color: context.colors.foreground400, fontSize: 12)),
                      if (item.yellowCards > 0 || item.redCards > 0) ...[
                        const SizedBox(width: 8),
                        Text('·', style: TextStyle(color: context.colors.foreground400, fontSize: 12)),
                        const SizedBox(width: 8),
                        if (item.yellowCards > 0)
                          Container(
                            width: 10,
                            height: 13,
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(2)),
                          ),
                        if (item.redCards > 0)
                          Container(
                            width: 10,
                            height: 13,
                            decoration: BoxDecoration(color: context.colors.danger, borderRadius: BorderRadius.circular(2)),
                          ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Text(item.scoreText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusBgColor,
                borderRadius: BorderRadius.circular(9999),
              ),
              child: Text(
                item.outcomeText,
                style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref, Player player, bool canDelete) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => unawaited(_showEditPlayerSheet(context, player)),
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
            if (canDelete)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => unawaited(_confirmDelete(context, ref, player)),
                  icon: Icon(Remix.delete_bin_line, size: 18, color: context.colors.danger),
                  label: const Text('Supprimer'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.colors.danger,
                    side: BorderSide(color: context.colors.danger.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              )
            else
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => unawaited(_confirmToggleActive(context, ref, player)),
                  icon: Icon(
                    player.isActive ? Remix.archive_drawer_line : Remix.check_line,
                    size: 18,
                    color: player.isActive ? context.colors.foreground200 : context.colors.primary500,
                  ),
                  label: Text(player.isActive ? 'Archiver' : 'Activer'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: player.isActive ? context.colors.foreground50 : context.colors.primary500,
                    side: BorderSide(
                      color: player.isActive ? context.colors.background700 : context.colors.primary500.withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (canDelete)
          Text(
            "Ce joueur n'a participé à aucune séance et peut être supprimé définitivement.",
            style: TextStyle(color: context.colors.foreground500, fontSize: 12),
            textAlign: TextAlign.center,
          )
        else
          Text(
            "Ce joueur a un historique de matchs et ne peut être qu'archivé pour préserver les statistiques.",
            style: TextStyle(color: context.colors.foreground500, fontSize: 12),
            textAlign: TextAlign.center,
          ),
      ],
    );
  }

  Future<void> _showEditPlayerSheet(BuildContext context, Player player) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EditPlayerBottomSheet(player: player),
    );
  }

  Future<void> _confirmToggleActive(BuildContext context, WidgetRef ref, Player player) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: context.colors.background900,
          title: Text(player.isActive ? 'Archiver le joueur ?' : 'Activer le joueur ?'),
          content: Text(
            player.isActive
                ? 'Le joueur ne sera plus proposé lors de la création des séances, mais son historique et ses statistiques restent intégralement conservés.'
                : 'Le joueur sera à nouveau actif et disponible pour les séances futures.',
            style: TextStyle(color: context.colors.foreground300),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Annuler', style: TextStyle(color: context.colors.foreground400)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await ref.read(playersListProvider.notifier).togglePlayerActive(
                  id: player.id,
                  isActive: !player.isActive,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: player.isActive ? context.colors.warning : context.colors.primary500,
                foregroundColor: context.colors.background950,
              ),
              child: Text(player.isActive ? 'Archiver' : 'Activer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Player player) async {
    await showDialog<void>(
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
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Annuler', style: TextStyle(color: context.colors.foreground400)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                final deleted = await ref.read(playersListProvider.notifier).removePlayer(player.id);
                if (context.mounted) {
                  if (deleted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Le joueur "${player.name}" a été supprimé.')),
                    );
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/joueurs');
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Impossible de supprimer ce joueur : il a déjà participé à une séance.'),
                      ),
                    );
                  }
                }
              },
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
  }
}
