import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:remixicon/remixicon.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/app_card.dart';
import '../../players/application/players_provider.dart';
import '../../ranking/application/ranking_providers.dart';
import '../../sessions/application/sessions_provider.dart';
import '../../team/application/team_provider.dart';
import '../../team/presentation/team_switcher_bottom_sheet.dart';
import '../application/settings_provider.dart';
import '../data/backup_service.dart';
import '../domain/backup_payload.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final minPlayers = ref.watch(minPlayersPerSessionProvider);

    final formatEstimate = minPlayers.isEven
        ? '${minPlayers ~/ 2}v${minPlayers ~/ 2}'
        : '${minPlayers ~/ 2}v${minPlayers ~/ 2} (+1)';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Remix.arrow_left_s_line),
          onPressed: () => context.pop(),
        ),
        title: const Text('Réglages'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle(context, 'Groupe & Équipes'),
          _buildTeamSection(context, ref),
          const SizedBox(height: 24),
          _buildSectionTitle(context, 'Séances & Matchs'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Remix.team_line, color: context.colors.primary500, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Joueurs minimum requis',
                            style: TextStyle(
                              color: context.colors.foreground50,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Format estimé : $formatEstimate (défaut : 6 pour 3v3)',
                            style: TextStyle(
                              color: context.colors.foreground400,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Remix.subtract_line, size: 18),
                          color: minPlayers > 2 ? context.colors.foreground200 : context.colors.foreground600,
                          onPressed: minPlayers > 2
                              ? () {
                                  unawaited(ref.read(minPlayersPerSessionProvider.notifier).setMinPlayers(minPlayers - 1));
                                }
                              : null,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: context.colors.background800,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: context.colors.background700),
                          ),
                          child: Text(
                            '$minPlayers',
                            style: TextStyle(
                              color: context.colors.primary500,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Remix.add_line, size: 18),
                          color: minPlayers < 30 ? context.colors.primary500 : context.colors.foreground600,
                          onPressed: minPlayers < 30
                              ? () {
                                  unawaited(ref.read(minPlayersPerSessionProvider.notifier).setMinPlayers(minPlayers + 1));
                                }
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _buildSectionTitle(context, 'Apparence'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Remix.palette_line, color: context.colors.foreground50),
              title: Text('Thème', style: TextStyle(color: context.colors.foreground50)),
              trailing: DropdownButton<ThemeMode>(
                value: themeMode,
                underline: const SizedBox(),
                dropdownColor: context.colors.background900,
                iconEnabledColor: context.colors.foreground50,
                items: [
                  DropdownMenuItem(value: ThemeMode.system, child: Text('Système', style: TextStyle(color: context.colors.foreground50))),
                  DropdownMenuItem(value: ThemeMode.light, child: Text('Clair', style: TextStyle(color: context.colors.foreground50))),
                  DropdownMenuItem(value: ThemeMode.dark, child: Text('Sombre', style: TextStyle(color: context.colors.foreground50))),
                ],
                onChanged: (mode) {
                  if (mode != null) {
                    unawaited(ref.read(themeModeProvider.notifier).setThemeMode(mode));
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 32),
          _buildSectionTitle(context, 'Données'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Remix.upload_cloud_2_line, color: context.colors.foreground50),
                  title: Text('Sauvegarder les données', style: TextStyle(color: context.colors.foreground50)),
                  subtitle: Text(
                    'Exporter un fichier JSON partageable',
                    style: TextStyle(color: context.colors.foreground400, fontSize: 12),
                  ),
                  onTap: () => unawaited(_handleBackup(context, ref)),
                ),
                Divider(color: context.colors.background700, height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Remix.download_cloud_2_line, color: context.colors.foreground50),
                  title: Text('Restaurer une sauvegarde', style: TextStyle(color: context.colors.foreground50)),
                  subtitle: Text(
                    'Importer et fusionner ou remplacer',
                    style: TextStyle(color: context.colors.foreground400, fontSize: 12),
                  ),
                  onTap: () => unawaited(_handleRestore(context, ref)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _buildSectionTitle(context, 'À propos'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Remix.information_line, color: context.colors.foreground50),
                  title: Text('Version', style: TextStyle(color: context.colors.foreground50)),
                  trailing: Text('1.0.0', style: TextStyle(color: context.colors.foreground400)),
                ),
                Divider(color: context.colors.background700, height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Remix.file_text_line, color: context.colors.foreground50),
                  title: Text('Mentions légales', style: TextStyle(color: context.colors.foreground50)),
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleBackup(BuildContext context, WidgetRef ref) async {
    final colors = context.colors;
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colors.background900,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.background700),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: colors.primary500),
                const SizedBox(height: 16),
                Text(
                  'Création de la sauvegarde...',
                  style: TextStyle(color: colors.foreground50, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final payload = await ref.read(backupServiceProvider).exportAndShareBackup();
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: colors.background900,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colors.primary500.withValues(alpha: 0.4)),
          ),
          content: Row(
            children: [
              Icon(Remix.checkbox_circle_fill, color: colors.primary500, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Sauvegarde exportée (${payload.players.length} joueurs, ${payload.sessions.length} séances)',
                  style: TextStyle(color: colors.foreground50),
                ),
              ),
            ],
          ),
        ),
      );
    } on Object catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: colors.background900,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colors.danger.withValues(alpha: 0.4)),
          ),
          content: Row(
            children: [
              Icon(Remix.error_warning_fill, color: colors.danger, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Erreur lors de la sauvegarde : $e',
                  style: TextStyle(color: colors.foreground50),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _handleRestore(BuildContext context, WidgetRef ref) async {
    final colors = context.colors;
    try {
      final payload = await ref.read(backupServiceProvider).pickBackupFile();
      if (payload == null || !context.mounted) return;

      await _showRestoreDialog(context, ref, payload);
    } on Object catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: colors.background900,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colors.danger.withValues(alpha: 0.4)),
          ),
          content: Row(
            children: [
              Icon(Remix.error_warning_fill, color: colors.danger, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  e is FormatException ? e.message : 'Erreur de lecture : $e',
                  style: TextStyle(color: colors.foreground50),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _showRestoreDialog(
    BuildContext context,
    WidgetRef ref,
    BackupPayload payload,
  ) async {
    final colors = context.colors;
    var isMerge = true;

    final teamName = payload.team?['name'] as String? ?? 'Équipe inconnue';
    final dateFormatted = DateFormat('dd/MM/yyyy à HH:mm').format(payload.exportedAt);

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (_, setState) {
          return Dialog(
            backgroundColor: colors.background900,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: colors.background700),
            ),
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colors.primary500.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Remix.download_cloud_2_line, color: colors.primary500, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Restaurer une sauvegarde',
                              style: TextStyle(
                                color: colors.foreground50,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Fichier valide détecté',
                              style: TextStyle(color: colors.primary500, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.background800,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.background700),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          teamName,
                          style: TextStyle(
                            color: colors.foreground50,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Exporté le $dateFormatted',
                          style: TextStyle(color: colors.foreground400, fontSize: 12),
                        ),
                        const Divider(height: 18),
                        Row(
                          children: [
                            Icon(Remix.user_3_line, size: 16, color: colors.foreground400),
                            const SizedBox(width: 6),
                            Text(
                              '${payload.players.length} joueurs',
                              style: TextStyle(color: colors.foreground200, fontSize: 13),
                            ),
                            const SizedBox(width: 20),
                            Icon(Remix.football_line, size: 16, color: colors.foreground400),
                            const SizedBox(width: 6),
                            Text(
                              '${payload.sessions.length} séances',
                              style: TextStyle(color: colors.foreground200, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'CHOISIR LE MODE DE RESTAURATION',
                    style: TextStyle(
                      color: colors.foreground400,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Option 1 : Fusionner
                  GestureDetector(
                    onTap: () => setState(() => isMerge = true),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isMerge
                            ? colors.primary500.withValues(alpha: 0.1)
                            : colors.background800,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isMerge ? colors.primary500 : colors.background700,
                          width: isMerge ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isMerge ? Remix.checkbox_circle_fill : Remix.checkbox_blank_circle_line,
                            color: isMerge ? colors.primary500 : colors.foreground400,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Fusionner',
                                      style: TextStyle(
                                        color: colors.foreground50,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: colors.primary500.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        'Recommandé',
                                        style: TextStyle(
                                          color: colors.primary400,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Conserve vos données actuelles et ajoute les joueurs et séances manquants sans doublon.',
                                  style: TextStyle(
                                    color: colors.foreground400,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Option 2 : Écraser
                  GestureDetector(
                    onTap: () => setState(() => isMerge = false),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: !isMerge
                            ? colors.danger.withValues(alpha: 0.1)
                            : colors.background800,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: !isMerge ? colors.danger : colors.background700,
                          width: !isMerge ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            !isMerge ? Remix.checkbox_circle_fill : Remix.checkbox_blank_circle_line,
                            color: !isMerge ? colors.danger : colors.foreground400,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Remplacer tout',
                                  style: TextStyle(
                                    color: colors.foreground50,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Efface les données actuelles de l'appareil et applique le contenu exact du fichier.",
                                  style: TextStyle(
                                    color: colors.foreground400,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                        child: Text(
                          'Annuler',
                          style: TextStyle(color: colors.foreground400),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isMerge ? colors.primary500 : colors.danger,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        ),
                        onPressed: () {
                          Navigator.of(dialogCtx).pop();
                          unawaited(_executeRestore(context, ref, payload, isMerge));
                        },
                        child: Text(
                          isMerge ? 'Fusionner les données' : 'Remplacer les données',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _executeRestore(
    BuildContext context,
    WidgetRef ref,
    BackupPayload payload,
    bool isMerge,
  ) async {
    final colors = context.colors;

    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colors.background900,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.background700),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: colors.primary500),
                const SizedBox(height: 16),
                Text(
                  'Restauration en cours...',
                  style: TextStyle(color: colors.foreground50, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final result = await ref.read(backupServiceProvider).restoreBackup(
            payload,
            merge: isMerge,
          );

      // Invalidation de tous les providers pour synchronisation immédiate de l'UI
      ref
        ..invalidate(teamInfoProvider)
        ..invalidate(hasTeamProvider)
        ..invalidate(playersListProvider)
        ..invalidate(allSessionsProvider)
        ..invalidate(sessionsListProvider)
        ..invalidate(activeSessionIdProvider)
        ..invalidate(activeDraftSessionProvider)
        ..invalidate(minPlayersPerSessionProvider)
        ..invalidate(standingsProvider)
        ..invalidate(standingsPerMatchProvider)
        ..invalidate(topScorersProvider)
        ..invalidate(topAssistsProvider)
        ..invalidate(topCardsProvider);

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // dismiss loading

      final message = isMerge
          ? 'Fusion réussie : +${result.importedPlayersCount} joueurs, +${result.importedSessionsCount} séances (${result.reusedPlayersCount} joueurs réconciliés)'
          : 'Restauration réussie : ${result.importedPlayersCount} joueurs et ${result.importedSessionsCount} séances restaurés';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: colors.background900,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colors.primary500.withValues(alpha: 0.4)),
          ),
          content: Row(
            children: [
              Icon(Remix.checkbox_circle_fill, color: colors.primary500, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: colors.foreground50),
                ),
              ),
            ],
          ),
        ),
      );
    } on Object catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: colors.background900,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colors.danger.withValues(alpha: 0.4)),
          ),
          content: Row(
            children: [
              Icon(Remix.error_warning_fill, color: colors.danger, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Erreur lors de la restauration : $e',
                  style: TextStyle(color: colors.foreground50),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildTeamSection(BuildContext context, WidgetRef ref) {
    final activeTeam = ref.watch(activeTeamProvider).value;
    final allTeams = ref.watch(allTeamsProvider).value ?? const [];
    final countsAsync = activeTeam != null ? ref.watch(teamCountsProvider(activeTeam.id)) : null;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.colors.primary500.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: context.colors.primary500.withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: Text(
                    activeTeam?.name.isNotEmpty == true ? activeTeam!.name.substring(0, 1).toUpperCase() : 'E',
                    style: TextStyle(
                      color: context.colors.primary500,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            activeTeam?.name ?? 'Aucun groupe sélectionné',
                            style: TextStyle(
                              color: context.colors.foreground50,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: context.colors.primary500.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Actif',
                            style: TextStyle(
                              color: context.colors.primary400,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${activeTeam?.format ?? "5v5"}${activeTeam?.location != null ? " · ${activeTeam!.location}" : ""}',
                      style: TextStyle(color: context.colors.foreground400, fontSize: 13),
                    ),
                    if (countsAsync != null)
                      countsAsync.maybeWhen(
                        data: (counts) => Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '${counts['players'] ?? 0} joueurs · ${counts['sessions'] ?? 0} séances enregistrées',
                            style: TextStyle(color: context.colors.foreground500, fontSize: 12),
                          ),
                        ),
                        orElse: () => const SizedBox.shrink(),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: context.colors.background700, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Remix.arrow_left_right_line, size: 16),
                  label: Text(allTeams.length > 1 ? 'Changer (${allTeams.length})' : 'Changer'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.colors.primary400,
                    side: BorderSide(color: context.colors.primary500.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => unawaited(showTeamSwitcher(context)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Remix.add_line, size: 16),
                  label: const Text('Nouveau'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: context.colors.background950,
                    backgroundColor: context.colors.primary500,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => unawaited(context.push('/creer-equipe')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(color: context.colors.foreground400, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}
