import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/initial_avatar.dart';
import '../../players/application/players_provider.dart';
import '../../players/presentation/new_player_bottom_sheet.dart';
import '../application/team_provider.dart';

class AddTeamPlayersScreen extends ConsumerStatefulWidget {
  const AddTeamPlayersScreen({super.key});

  @override
  ConsumerState<AddTeamPlayersScreen> createState() => _AddTeamPlayersScreenState();
}

class _AddTeamPlayersScreenState extends ConsumerState<AddTeamPlayersScreen> {
  final _nameController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _formKey = GlobalKey<FormState>();
  bool _isAdding = false;

  @override
  void dispose() {
    _nameController.dispose();
    _nicknameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _addPlayer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isAdding = true);
    try {
      await ref.read(playersListProvider.notifier).addPlayer(
        name: _nameController.text.trim(),
        nickname: _nicknameController.text.trim().isNotEmpty
            ? _nicknameController.text.trim()
            : null,
      );

      _nameController.clear();
      _nicknameController.clear();
      _nameFocusNode.requestFocus();
    } finally {
      if (mounted) {
        setState(() => _isAdding = false);
      }
    }
  }

  void _finish() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Remix.checkbox_circle_line, color: Colors.white),
            SizedBox(width: 10),
            Text('Bienvenue sur Statoo ! Votre effectif est prêt.'),
          ],
        ),
        backgroundColor: context.colors.primary500,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      ),
    );
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final teamAsync = ref.watch(teamInfoProvider);
    final playersAsync = ref.watch(playersListProvider);
    final teamName = teamAsync.value?.name ?? 'Mon Équipe';

    return Scaffold(
      backgroundColor: context.colors.background950,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: context.colors.foreground50,
        iconTheme: IconThemeData(color: context.colors.foreground50),
        systemOverlayStyle: AppTheme.pageOverlayStyle(Theme.of(context).brightness),
        elevation: 0,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Remix.arrow_left_s_line),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        centerTitle: true,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: context.colors.primary500.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(9999),
            border: Border.all(
              color: context.colors.primary500.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            'Étape 2 sur 2 · Effectif',
            style: TextStyle(
              color: context.colors.primary400,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _finish,
            child: Text(
              'Passer',
              style: TextStyle(
                color: context.colors.foreground400,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Team Chip Badge
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: context.colors.background900,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.colors.background700),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Remix.shield_star_line, size: 18, color: context.colors.primary400),
                            const SizedBox(width: 8),
                            Text(
                              teamName,
                              style: TextStyle(
                                color: context.colors.foreground100,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Header
                    Center(
                      child: Text(
                        'Ajoutez vos joueurs',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: context.colors.foreground50,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        "Enregistrez les joueurs de votre groupe pour générer vos compositions d'équipes et enregistrer vos scores.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: context.colors.foreground400,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Quick Add Player Card Form
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: context.colors.background900,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: context.colors.background700),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ajout rapide de joueur',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: context.colors.foreground100,
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _nameController,
                              focusNode: _nameFocusNode,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              style: TextStyle(color: context.colors.foreground50),
                              decoration: InputDecoration(
                                hintText: 'Nom ou prénom (ex: Lucas, Karim...) *',
                                hintStyle: TextStyle(color: context.colors.foreground600),
                                prefixIcon: Icon(
                                  Remix.user_3_line,
                                  color: context.colors.primary400,
                                  size: 20,
                                ),
                                filled: true,
                                fillColor: context.colors.background800,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                                  borderSide: BorderSide(color: context.colors.primary500, width: 2),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Veuillez saisir le prénom ou nom du joueur';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _nicknameController,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) {
                                if (!_isAdding) {
                                  unawaited(_addPlayer());
                                }
                              },
                              style: TextStyle(color: context.colors.foreground50),
                              decoration: InputDecoration(
                                hintText: 'Surnom (facultatif, ex: Lulu)',
                                hintStyle: TextStyle(color: context.colors.foreground600),
                                prefixIcon: Icon(
                                  Remix.at_line,
                                  color: context.colors.foreground500,
                                  size: 20,
                                ),
                                filled: true,
                                fillColor: context.colors.background800,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                                  borderSide: BorderSide(color: context.colors.primary500, width: 2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _isAdding ? null : _addPlayer,
                                    icon: const Icon(Remix.add_line, size: 18),
                                    label: const Text('Ajouter ce joueur'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: context.colors.primary500,
                                      foregroundColor: context.colors.background950,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: TextButton.icon(
                                onPressed: () {
                                  unawaited(
                                    showModalBottomSheet<void>(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (context) => const NewPlayerBottomSheet(),
                                    ).then((_) {
                                      ref.invalidate(playersListProvider);
                                    }),
                                  );
                                },
                                icon: Icon(
                                  Remix.camera_line,
                                  size: 16,
                                  color: context.colors.foreground400,
                                ),
                                label: Text(
                                  'Formulaire avec photo ou avatar',
                                  style: TextStyle(
                                    color: context.colors.foreground400,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Player Roster Section
                    playersAsync.when(
                      data: (players) {
                        final count = players.length;
                        const target = 10;
                        final progress = (count / target).clamp(0.0, 1.0);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'EFFECTIF ACTUEL ($count)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: context.colors.foreground400,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  count >= 10 ? 'Effectif complet (10+)' : 'Objectif : 10 joueurs',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: count >= 10
                                        ? context.colors.primary400
                                        : context.colors.warning,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(9999),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 6,
                                backgroundColor: context.colors.background800,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  count >= 10
                                      ? context.colors.primary500
                                      : context.colors.warning,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (players.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(24),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: context.colors.background900,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: context.colors.background700),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Remix.group_line,
                                      size: 36,
                                      color: context.colors.foreground500,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Aucun joueur ajouté pour le moment',
                                      style: TextStyle(
                                        color: context.colors.foreground400,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: players.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final player = players[index];
                                  final initial = player.name.isNotEmpty
                                      ? player.name[0].toUpperCase()
                                      : '?';

                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: context.colors.background900,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: context.colors.background700),
                                    ),
                                    child: Row(
                                      children: [
                                        InitialAvatar(
                                          initial: initial,
                                          baseColor: context.colors.primary500,
                                          size: 38,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                player.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              if (player.nickname != null &&
                                                  player.nickname!.isNotEmpty)
                                                Text(
                                                  '« ${player.nickname} »',
                                                  style: TextStyle(
                                                    color: context.colors.foreground500,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            Remix.delete_bin_line,
                                            size: 18,
                                            color: context.colors.foreground500,
                                          ),
                                          onPressed: () {
                                            unawaited(
                                              ref
                                                  .read(playersListProvider.notifier)
                                                  .removePlayer(player.id),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                          ],
                        );
                      },
                      loading: () => Center(
                        child: CircularProgressIndicator(color: context.colors.primary500),
                      ),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Bottom CTA
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: context.colors.background950,
                border: Border(top: BorderSide(color: context.colors.background800)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _finish,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.primary500,
                    foregroundColor: context.colors.background950,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Terminer et aller à l'Accueil",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Remix.arrow_right_line, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
