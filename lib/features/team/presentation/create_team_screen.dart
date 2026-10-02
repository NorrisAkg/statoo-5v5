import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../players/application/players_provider.dart';
import '../../ranking/application/ranking_providers.dart';
import '../../sessions/application/sessions_provider.dart';
import '../../settings/application/settings_provider.dart';
import '../../settings/data/backup_service.dart';
import '../../stats/application/stats_providers.dart';
import '../application/team_provider.dart';
import '../domain/team_info.dart';

class CreateTeamScreen extends ConsumerStatefulWidget {
  const CreateTeamScreen({super.key});

  @override
  ConsumerState<CreateTeamScreen> createState() => _CreateTeamScreenState();
}

class _CreateTeamScreenState extends ConsumerState<CreateTeamScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  String _selectedFormat = '5v5';
  bool _isLoading = false;

  final List<String> _formats = const ['4v4', '5v5', '6v6', '7v7'];

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final team = TeamInfo(
        id: 'team_${DateTime.now().millisecondsSinceEpoch}',
        name: _nameController.text.trim(),
        format: _selectedFormat,
        location: _locationController.text.trim().isNotEmpty
            ? _locationController.text.trim()
            : null,
        createdAt: DateTime.now(),
      );

      await ref.read(teamInfoProvider.notifier).saveTeam(team);

      if (mounted) {
        context.go('/ajouter-joueurs-initiaux');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _restoreFromBackup() async {
    try {
      final payload = await ref.read(backupServiceProvider).pickBackupFile();
      if (payload == null || !mounted) return;

      setState(() => _isLoading = true);
      final result = await ref.read(backupServiceProvider).restoreBackup(payload, merge: false);

      await ref.read(hasTeamProvider.notifier).reloadFromDb();
      await ref.read(activeTeamIdProvider.notifier).reloadFromDb();
      await ref.read(minPlayersPerSessionProvider.notifier).reload();

      ref
        ..invalidate(teamInfoProvider)
        ..invalidate(allTeamsProvider)
        ..invalidate(playersListProvider)
        ..invalidate(allSessionsProvider)
        ..invalidate(sessionsListProvider)
        ..invalidate(activeSessionIdProvider)
        ..invalidate(activeDraftSessionProvider)
        ..invalidate(groupTotalsProvider)
        ..invalidate(standingsProvider)
        ..invalidate(standingsPerMatchProvider)
        ..invalidate(topScorersProvider)
        ..invalidate(topAssistsProvider)
        ..invalidate(topCardsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Restauration réussie : ${result.importedPlayersCount} joueurs et ${result.importedSessionsCount} séances restaurés.',
            ),
          ),
        );
        context.go('/');
      }
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la restauration : $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasTeam = ref.watch(hasTeamProvider);

    return Scaffold(
      backgroundColor: context.colors.background950,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: context.colors.foreground50,
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
            hasTeam ? 'Nouveau groupe' : 'Étape 1 sur 2 · Votre équipe',
            style: TextStyle(
              color: context.colors.primary400,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: context.colors.primary500.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: context.colors.primary500.withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Remix.shield_user_line,
                      size: 46,
                      color: context.colors.primary400,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    'Créez votre équipe',
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
                    "Donnez un nom et une identité à votre groupe d'amis pour lancer vos séances et suivre vos classements.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.colors.foreground400,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Team Name Input
                Text(
                  "Nom de l'équipe ou du groupe *",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.colors.foreground200,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  style: TextStyle(color: context.colors.foreground50),
                  decoration: InputDecoration(
                    hintText: 'ex: FC Urban, Les Galactiques...',
                    hintStyle: TextStyle(color: context.colors.foreground600),
                    prefixIcon: Icon(
                      Remix.team_line,
                      color: context.colors.primary400,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: context.colors.background900,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: context.colors.background700),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: context.colors.background700),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: context.colors.primary500, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Veuillez renseigner le nom de votre équipe';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Format Selector
                Text(
                  'Format de jeu habituel',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.colors.foreground200,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: _formats.map((format) {
                    final isSelected = _selectedFormat == format;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: InkWell(
                          onTap: () {
                            setState(() => _selectedFormat = format);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? context.colors.primary500.withValues(alpha: 0.18)
                                  : context.colors.background900,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? context.colors.primary500
                                    : context.colors.background700,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              format,
                              style: TextStyle(
                                color: isSelected
                                    ? context.colors.primary400
                                    : context.colors.foreground400,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Location Input
                Text(
                  'Complexe ou terrain habituel (facultatif)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.colors.foreground200,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _locationController,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(color: context.colors.foreground50),
                  decoration: InputDecoration(
                    hintText: 'ex: Urban Soccer, Le Five...',
                    hintStyle: TextStyle(color: context.colors.foreground600),
                    prefixIcon: Icon(
                      Remix.map_pin_2_line,
                      color: context.colors.foreground500,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: context.colors.background900,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: context.colors.background700),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: context.colors.background700),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: context.colors.primary500, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colors.primary500,
                      foregroundColor: AppColors.onPrimaryDark,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: context.colors.background950,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Continuer vers l'effectif",
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
                const SizedBox(height: 16),
                Center(
                  child: TextButton.icon(
                    icon: Icon(Remix.download_cloud_2_line, size: 18, color: context.colors.foreground400),
                    label: Text(
                      "J'ai déjà une sauvegarde Statoo",
                      style: TextStyle(color: context.colors.foreground300, fontSize: 13),
                    ),
                    onPressed: _isLoading ? null : _restoreFromBackup,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
