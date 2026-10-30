import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/player_sort.dart';
import '../../../core/widgets/player_avatar.dart';
import '../../../core/widgets/primary_button.dart';
import '../../players/application/players_provider.dart';
import '../../players/domain/player.dart';
import '../../players/presentation/new_player_bottom_sheet.dart';
import '../../shared/application/shared_providers.dart';
import '../application/sessions_provider.dart';
import '../domain/participation.dart';

class AddLatePlayersBottomSheet extends ConsumerStatefulWidget {
  const AddLatePlayersBottomSheet({
    required this.sessionId,
    required this.currentTeamACount,
    required this.currentTeamBCount,
    required this.alreadyAssignedPlayerIds,
    this.allowUnevenTeams = false,
    this.currentTeamCCount,
    super.key,
  });

  final String sessionId;
  final int currentTeamACount;
  final int currentTeamBCount;
  final int? currentTeamCCount;
  final Set<String> alreadyAssignedPlayerIds;
  final bool allowUnevenTeams;

  bool get isTournament => currentTeamCCount != null;

  @override
  ConsumerState<AddLatePlayersBottomSheet> createState() => _AddLatePlayersBottomSheetState();
}

class _AddLatePlayersBottomSheetState extends ConsumerState<AddLatePlayersBottomSheet> {
  final Set<String> _selectedPlayerIds = {};
  final Map<String, Team> _assignments = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _drawTeams() async {
    if (_selectedPlayerIds.isEmpty) return;

    if (_assignments.isNotEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: context.colors.background900,
          title: const Text('Tirer au sort ?'),
          content: Text(
            'Le tirage au sort va remplacer la répartition actuelle de ces joueurs.',
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
                backgroundColor: context.colors.primary500,
                foregroundColor: context.colors.background950,
              ),
              child: const Text('Confirmer'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
    }

    final rng = Random();
    final selectedList = _selectedPlayerIds.toList()..shuffle(rng);

    final newAssignments = <String, Team>{};

    if (widget.isTournament) {
      int countA = widget.currentTeamACount;
      int countB = widget.currentTeamBCount;
      int countC = widget.currentTeamCCount!;

      for (final pid in selectedList) {
        final minCount = [countA, countB, countC].reduce((a, b) => a < b ? a : b);
        final eligible = <Team>[
          if (countA == minCount) Team.a,
          if (countB == minCount) Team.b,
          if (countC == minCount) Team.c,
        ];
        final chosen = eligible[rng.nextInt(eligible.length)];
        newAssignments[pid] = chosen;
        if (chosen == Team.a) countA++;
        if (chosen == Team.b) countB++;
        if (chosen == Team.c) countC++;
      }
    } else {
      int countA = widget.currentTeamACount;
      int countB = widget.currentTeamBCount;

      for (final pid in selectedList) {
        if (countA < countB) {
          newAssignments[pid] = Team.a;
          countA++;
        } else if (countB < countA) {
          newAssignments[pid] = Team.b;
          countB++;
        } else {
          final chooseA = rng.nextBool();
          if (chooseA) {
            newAssignments[pid] = Team.a;
            countA++;
          } else {
            newAssignments[pid] = Team.b;
            countB++;
          }
        }
      }
    }

    setState(() {
      _assignments
        ..clear()
        ..addAll(newAssignments);
    });
  }

  Future<void> _submit() async {
    if (_selectedPlayerIds.isEmpty) return;

    if (_assignments.length != _selectedPlayerIds.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Tous les joueurs sélectionnés doivent être assignés à l'équipe A ou B."),
        ),
      );
      return;
    }

    final assignedToA = _assignments.values.where((t) => t == Team.a).length;
    final assignedToB = _assignments.values.where((t) => t == Team.b).length;
    final totalA = widget.currentTeamACount + assignedToA;
    final totalB = widget.currentTeamBCount + assignedToB;

    if (!widget.allowUnevenTeams && (totalA - totalB).abs() > 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "L'écart d'effectif dépasserait 1 joueur ($totalA vs $totalB). Rééquilibrez les équipes.",
          ),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ref.read(sessionsControllerProvider).addLatePlayers(
            sessionId: widget.sessionId,
            playerTeamAssignments: _assignments,
          );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_selectedPlayerIds.length} joueur${_selectedPlayerIds.length > 1 ? 's' : ''} ajouté${_selectedPlayerIds.length > 1 ? 's' : ''} à la séance !',
            ),
          ),
        );
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de l'ajout des joueurs : $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final playersAsync = ref.watch(playersListProvider);

    final assignedToA = _assignments.values.where((t) => t == Team.a).length;
    final assignedToB = _assignments.values.where((t) => t == Team.b).length;
    final assignedToC = _assignments.values.where((t) => t == Team.c).length;
    final totalA = widget.currentTeamACount + assignedToA;
    final totalB = widget.currentTeamBCount + assignedToB;
    final totalC = (widget.currentTeamCCount ?? 0) + assignedToC;
    final unassignedCount = _selectedPlayerIds.length - _assignments.length;

    return Container(
      decoration: BoxDecoration(
        color: context.colors.background950,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: context.colors.background700,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ajouter un retardataire',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tirage au sort ou choix manuel par équipe',
                      style: TextStyle(color: context.colors.foreground400, fontSize: 13),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Remix.close_line),
                tooltip: 'Fermer',
                color: context.colors.foreground400,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Current team counts banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: context.colors.background900,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colors.background700),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: context.colors.accent500, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Équipe A : ',
                        style: TextStyle(color: context.colors.foreground300, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '$totalA j.',
                        style: TextStyle(color: context.colors.accent400, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      if (assignedToA > 0)
                        Text(
                          ' (+$assignedToA)',
                          style: TextStyle(color: context.colors.accent300, fontSize: 11),
                        ),
                    ],
                  ),
                ),
                Container(width: 1, height: 20, color: context.colors.background700),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: context.colors.secondary500, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Équipe B : ',
                        style: TextStyle(color: context.colors.foreground300, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '$totalB j.',
                        style: TextStyle(color: context.colors.secondary400, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      if (assignedToB > 0)
                        Text(
                          ' (+$assignedToB)',
                          style: TextStyle(color: context.colors.secondary400, fontSize: 11),
                        ),
                    ],
                  ),
                ),
                if (widget.isTournament) ...[
                  Container(width: 1, height: 20, color: context.colors.background700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(color: context.colors.primary500, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Équipe C : ',
                          style: TextStyle(color: context.colors.foreground300, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '$totalC j.',
                          style: TextStyle(color: context.colors.primary400, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        if (assignedToC > 0)
                          Text(
                            ' (+$assignedToC)',
                            style: TextStyle(color: context.colors.primary300, fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Action row : Tirage au sort / Nouveau joueur
          Row(
            children: [
              if (_selectedPlayerIds.isNotEmpty) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Remix.shuffle_line, size: 16),
                    label: const Text('Tirer au sort'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.colors.primary400,
                      side: BorderSide(color: context.colors.primary500.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _drawTeams,
                  ),
                ),
                if (_assignments.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Remix.refresh_line),
                    tooltip: 'Réinitialiser',
                    color: context.colors.foreground500,
                    onPressed: () => setState(_assignments.clear),
                  ),
                ],
                const SizedBox(width: 8),
              ],
              if (ref.watch(canWriteProvider('members'))) OutlinedButton.icon(
                icon: const Icon(Remix.user_add_line, size: 16),
                label: const Text('Créer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.colors.foreground200,
                  side: BorderSide(color: context.colors.background700),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  unawaited(
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => const NewPlayerBottomSheet(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Search bar
          TextField(
            controller: _searchController,
            style: TextStyle(color: context.colors.foreground50, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Rechercher un joueur...',
              hintStyle: TextStyle(color: context.colors.foreground500, fontSize: 14),
              prefixIcon: Icon(Remix.search_line, size: 18, color: context.colors.foreground400),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Remix.close_circle_fill, size: 18),
                      color: context.colors.foreground500,
                      tooltip: 'Effacer la recherche',
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: context.colors.background900,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
          const SizedBox(height: 10),

          // List of available players
          Expanded(
            child: playersAsync.when(
              data: (players) {
                final availablePlayers = players
                    .where((p) => p.isActive && !widget.alreadyAssignedPlayerIds.contains(p.id))
                    .toList()
                  ..sort(comparePlayersAlphabetically);

                if (availablePlayers.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Remix.checkbox_circle_line, size: 48, color: context.colors.primary500),
                          const SizedBox(height: 12),
                          Text(
                            'Tous les joueurs actifs participent déjà à cette séance.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: context.colors.foreground300, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final filtered = availablePlayers.where((p) {
                  if (_searchQuery.isEmpty) return true;
                  final q = _searchQuery.toLowerCase();
                  return p.name.toLowerCase().contains(q) ||
                      (p.nickname != null && p.nickname!.toLowerCase().contains(q));
                }).toList();
                sortPlayersSelectedFirst(filtered, selectedIds: _selectedPlayerIds);

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      'Aucun joueur trouvé pour « $_searchQuery »',
                      style: TextStyle(color: context.colors.foreground400, fontSize: 13),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final player = filtered[index];
                    final isSelected = _selectedPlayerIds.contains(player.id);
                    final team = _assignments[player.id];

                    return _buildPlayerItem(context, player, isSelected, team);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Erreur: $err')),
            ),
          ),
          const SizedBox(height: 12),

          // Bottom submit button
          PrimaryButton(
            label: _selectedPlayerIds.isEmpty
                ? 'Sélectionnez un joueur'
                : unassignedCount > 0
                    ? 'Attribuez une équipe ($unassignedCount restant${unassignedCount > 1 ? 's' : ''})'
                    : (!widget.allowUnevenTeams && (totalA - totalB).abs() > 1)
                        ? 'Écart > 1 interdit ($totalA vs $totalB)'
                        : "Valider l'entrée (${_selectedPlayerIds.length} joueur${_selectedPlayerIds.length > 1 ? 's' : ''})",
            icon: Remix.check_line,
            onPressed: (_selectedPlayerIds.isNotEmpty &&
                    unassignedCount == 0 &&
                    (widget.allowUnevenTeams || (totalA - totalB).abs() <= 1) &&
                    !_isSubmitting)
                ? _submit
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerItem(
    BuildContext context,
    Player player,
    bool isSelected,
    Team? team,
  ) {
    Color avatarBg;
    Color avatarFg;
    if (team == Team.a) {
      avatarBg = context.colors.accent500.withValues(alpha: 0.2);
      avatarFg = context.colors.accent400;
    } else if (team == Team.b) {
      avatarBg = context.colors.secondary500.withValues(alpha: 0.2);
      avatarFg = context.colors.secondary400;
    } else if (team == Team.c) {
      avatarBg = context.colors.primary500.withValues(alpha: 0.2);
      avatarFg = context.colors.primary400;
    } else if (isSelected) {
      avatarBg = context.colors.warning.withValues(alpha: 0.2);
      avatarFg = context.colors.warning;
    } else {
      avatarBg = context.colors.primary500.withValues(alpha: 0.15);
      avatarFg = context.colors.primary400;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: team == Team.a
              ? context.colors.accent500.withValues(alpha: 0.05)
              : team == Team.b
                  ? context.colors.secondary500.withValues(alpha: 0.05)
                  : team == Team.c
                      ? context.colors.primary500.withValues(alpha: 0.05)
                      : isSelected
                          ? context.colors.warning.withValues(alpha: 0.05)
                          : context.colors.background900,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: team == Team.a
                ? context.colors.accent500.withValues(alpha: 0.35)
                : team == Team.b
                    ? context.colors.secondary500.withValues(alpha: 0.35)
                    : team == Team.c
                        ? context.colors.primary500.withValues(alpha: 0.35)
                        : isSelected
                            ? context.colors.warning.withValues(alpha: 0.35)
                            : context.colors.background700,
          ),
        ),
        child: Row(
          children: [
            PlayerAvatar(source: player.avatarUrl, initial: player.name.isEmpty ? '?' : player.name[0], baseColor: avatarFg, backgroundColor: avatarBg, size: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(player.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  if (player.nickname != null)
                    Text('« ${player.nickname} »', style: TextStyle(color: context.colors.foreground500, fontSize: 11))
                  else if (isSelected && team == null)
                    Text(
                      'Choisir A ou B ou Tirage',
                      style: TextStyle(color: context.colors.warning, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                ],
              ),
            ),
            if (!isSelected)
              TextButton.icon(
                icon: const Icon(Remix.add_line, size: 14),
                label: const Text('Présent'),
                style: TextButton.styleFrom(
                  foregroundColor: context.colors.primary400,
                  backgroundColor: context.colors.primary500.withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  setState(() {
                    _selectedPlayerIds.add(player.id);
                  });
                },
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SegmentedButton<Team>(
                    segments: [
                      const ButtonSegment(value: Team.a, label: Text('A', style: TextStyle(fontWeight: FontWeight.bold))),
                      const ButtonSegment(value: Team.b, label: Text('B', style: TextStyle(fontWeight: FontWeight.bold))),
                      if (widget.isTournament)
                        const ButtonSegment(value: Team.c, label: Text('C', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    selected: team != null ? {team} : <Team>{},
                    emptySelectionAllowed: true,
                    style: SegmentedButton.styleFrom(
                      backgroundColor: context.colors.background800,
                      selectedBackgroundColor: team == Team.a
                          ? context.colors.accent500.withValues(alpha: 0.3)
                          : team == Team.b
                              ? context.colors.secondary500.withValues(alpha: 0.3)
                              : context.colors.primary500.withValues(alpha: 0.3),
                      selectedForegroundColor: team == Team.a
                          ? context.colors.accent400
                          : team == Team.b
                              ? context.colors.secondary400
                              : context.colors.primary400,
                      visualDensity: VisualDensity.compact,
                    ),
                    onSelectionChanged: (newSelection) {
                      setState(() {
                        if (newSelection.isEmpty) {
                          _assignments.remove(player.id);
                        } else {
                          _assignments[player.id] = newSelection.first;
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Remix.close_circle_line),
                    color: context.colors.foreground500,
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Retirer',
                    onPressed: () {
                      setState(() {
                        _selectedPlayerIds.remove(player.id);
                        _assignments.remove(player.id);
                      });
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
