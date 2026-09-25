import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:remixicon/remixicon.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../players/application/players_provider.dart';
import '../../players/presentation/new_player_bottom_sheet.dart';
import '../../settings/application/settings_provider.dart';
import '../application/sessions_provider.dart';

class NewSessionScreen extends ConsumerStatefulWidget {
  const NewSessionScreen({super.key});

  @override
  ConsumerState<NewSessionScreen> createState() => _NewSessionScreenState();
}

class _NewSessionScreenState extends ConsumerState<NewSessionScreen> {
  int _currentStep = 1;

  // Step 1 State: Date, Time & Options
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isRanked = true;
  bool _allowUnevenTeams = false;

  // Step 2 State: Player team assignments (playerId -> 'A' or 'B')
  final Set<String> _selectedPlayerIds = {};
  final Map<String, String> _playerTeamAssignments = {};
  bool _isSubmitting = false;

  void _nextStep() {
    if (_currentStep == 1) {
      setState(() => _currentStep = 2);
    } else {
      unawaited(_startSession());
    }
  }

  void _prevStep() {
    if (_currentStep > 1) {
      setState(() => _currentStep--);
    } else {
      context.pop();
    }
  }

  Future<void> _startSession() async {
    final minPlayers = ref.read(minPlayersPerSessionProvider);
    if (_selectedPlayerIds.length < minPlayers) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sélectionnez au moins $minPlayers joueurs pour débuter la séance (défini dans les réglages).',
          ),
        ),
      );
      return;
    }

    final countA = _playerTeamAssignments.values.where((v) => v == 'A').length;
    final countB = _playerTeamAssignments.values.where((v) => v == 'B').length;

    if (countA + countB != _selectedPlayerIds.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tous les joueurs présents doivent être assignés à l'équipe A ou B.")),
      );
      return;
    }

    if (!_allowUnevenTeams && (countA - countB).abs() > 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("L'écart d'effectif entre les équipes ne peut dépasser 1 (activez l'option sinon).")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final playedAt = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final activeDraft = ref.read(activeDraftSessionProvider).value;
      final startImmediately = activeDraft == null;

      final sessionId = await ref.read(sessionsControllerProvider).createDraftSession(
        playedAt: playedAt,
        isRanked: _isRanked,
        allowUnevenTeams: _allowUnevenTeams,
        playerTeamAssignments: _playerTeamAssignments,
        startImmediately: startImmediately,
      );

      if (mounted) {
        if (!startImmediately) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Séance enregistrée en brouillon. Clôturez ou annulez la séance en cours pour débuter celle-ci.',
              ),
            ),
          );
        }
        context.go('/seances/$sessionId');
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la création de la séance: $e')),
        );
      }
    }
  }

  Future<void> _pickDate() async {
    final colors = context.colors;
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.dark(
              primary: colors.primary500,
              onPrimary: colors.background950,
              surface: colors.background800,
              onSurface: colors.foreground50,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _pickTime() async {
    final colors = context.colors;
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.dark(
              primary: colors.primary500,
              onPrimary: colors.background950,
              surface: colors.background800,
              onSurface: colors.foreground50,
            ),
          ),
          child: child!,
        );
      },
    );
    if (time != null) {
      setState(() => _selectedTime = time);
    }
  }

  void _setToNow() {
    setState(() {
      _selectedDate = DateTime.now();
      _selectedTime = TimeOfDay.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Remix.arrow_left_line),
          onPressed: _prevStep,
        ),
        title: const Text('Nouvelle séance'),
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          _buildStepper(),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                if (_currentStep == 1) _buildStep1(),
                if (_currentStep == 2) _buildStep2(),
              ],
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildStepper() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStepCircle(1, 'Date & Options', _currentStep >= 1),
        Container(
          width: 48,
          height: 2,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          color: _currentStep >= 2 ? context.colors.primary500 : context.colors.background800,
        ),
        _buildStepCircle(2, 'Composition', _currentStep >= 2),
      ],
    );
  }

  Widget _buildStepCircle(int step, String label, bool isActive) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? context.colors.primary500 : context.colors.background800,
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? context.colors.primary500 : context.colors.foreground600,
            ),
          ),
          child: Text(
            '$step',
            style: TextStyle(
              color: isActive ? context.colors.background950 : context.colors.foreground500,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: isActive ? context.colors.foreground50 : context.colors.foreground500,
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.background950,
        border: Border(top: BorderSide(color: context.colors.background800)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_currentStep > 1) ...[
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Remix.arrow_left_line, size: 18),
                  label: const Text('Précédent'),
                  onPressed: _isSubmitting ? null : _prevStep,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.colors.foreground300,
                    side: BorderSide(color: context.colors.background700),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: 2,
              child: Builder(
                builder: (context) {
                  final activeDraft = ref.watch(activeDraftSessionProvider).value;
                  String label = 'Continuer';
                  IconData icon = Remix.arrow_right_line;
                  if (_currentStep == 2) {
                    if (activeDraft != null) {
                      label = 'Enregistrer en brouillon';
                      icon = Remix.file_list_line;
                    } else {
                      label = 'Débuter la séance';
                      icon = Remix.play_fill;
                    }
                  }
                  return PrimaryButton(
                    label: label,
                    icon: icon,
                    onPressed: _isSubmitting ? null : _nextStep,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1() {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final formattedDate = dateFormat.format(_selectedDate);
    final formattedTime = _selectedTime.format(context);
    final summaryFormat = DateFormat('EEE d MMM yyyy', 'fr_FR');
    final summaryText = '${summaryFormat.format(_selectedDate)} · $formattedTime';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quand joue-t-on ?',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          "Définissez la date, l'heure et les paramètres de la séance.",
          style: TextStyle(color: context.colors.foreground400),
        ),
        const SizedBox(height: 20),
        AppCard(
          child: Column(
            children: [
              _buildInputField('Date', formattedDate, Remix.calendar_line, _pickDate),
              const SizedBox(height: 16),
              _buildInputField('Heure', formattedTime, Remix.time_line, _pickTime),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _setToNow,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.colors.foreground50,
                    side: BorderSide(color: context.colors.background700),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Maintenant', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.colors.primary500.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.colors.primary500.withValues(alpha: 0.2)),
          ),
          child: Center(
            child: Text(
              summaryText,
              style: TextStyle(color: context.colors.primary500, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Options du match',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: context.colors.primary500,
                title: const Text('Match classé', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Compte pour le classement général et les statistiques.', style: TextStyle(color: context.colors.foreground400, fontSize: 13)),
                value: _isRanked,
                onChanged: (val) => setState(() => _isRanked = val),
              ),
              Divider(color: context.colors.background700, height: 24),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: context.colors.primary500,
                title: const Text('Autoriser équipes inégales', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Autorise un écart supérieur à 1 joueur entre A et B.', style: TextStyle(color: context.colors.foreground400, fontSize: 13)),
                value: _allowUnevenTeams,
                onChanged: (val) => setState(() => _allowUnevenTeams = val),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputField(String label, String value, IconData icon, [VoidCallback? onTap]) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: context.colors.background800,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.colors.background700),
              ),
              child: Row(
                children: [
                  Text(value, style: const TextStyle(fontSize: 15)),
                  const SizedBox(width: 24),
                  Icon(icon, color: context.colors.foreground500, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2() {
    final playersAsync = ref.watch(playersListProvider);
    final minPlayers = ref.watch(minPlayersPerSessionProvider);
    final activeDraft = ref.watch(activeDraftSessionProvider).value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Composition des équipes', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(
          "Sélectionnez les joueurs présents (minimum $minPlayers) et assignez-les à l'équipe A ou B.",
          style: TextStyle(color: context.colors.foreground400),
        ),
        const SizedBox(height: 16),
        if (activeDraft != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colors.warning.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Icon(Remix.information_line, color: context.colors.warning, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Une séance est déjà en cours. Cette séance sera sauvegardée en brouillon.',
                    style: TextStyle(color: context.colors.warning, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        playersAsync.when(
          data: (players) {
            final activePlayers = players.where((p) => p.isActive).toList();

            if (activePlayers.isEmpty) {
              return AppCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Remix.group_line, size: 64, color: context.colors.primary500.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text(
                        "Il n'y a pas encore de joueurs dans l'effectif",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.colors.foreground300, fontSize: 16),
                      ),
                      const SizedBox(height: 24),
                      PrimaryButton(
                        label: 'Ajouter un joueur',
                        icon: Remix.user_add_line,
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
                ),
              );
            }

            final countA = _playerTeamAssignments.values.where((v) => v == 'A').length;
            final countB = _playerTeamAssignments.values.where((v) => v == 'B').length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          color: context.colors.accent500.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.colors.accent500.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: context.colors.accent500, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Text('Équipe A: $countA', style: TextStyle(color: context.colors.accent400, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          color: context.colors.secondary500.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.colors.secondary500.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: context.colors.secondary500, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Text('Équipe B: $countB', style: TextStyle(color: context.colors.secondary400, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (_selectedPlayerIds.isNotEmpty)
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Remix.shuffle_line, size: 16),
                          label: const Text('Tirer au sort'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: context.colors.primary400,
                            side: BorderSide(color: context.colors.primary500.withValues(alpha: 0.5)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            setState(() {
                              final selected = _selectedPlayerIds.toList()..shuffle();
                              _playerTeamAssignments.clear();
                              for (int i = 0; i < selected.length; i++) {
                                _playerTeamAssignments[selected[i]] = i.isEven ? 'A' : 'B';
                              }
                            });
                          },
                        ),
                      ),
                    if (_selectedPlayerIds.isNotEmpty) const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Remix.user_add_line),
                      tooltip: 'Nouveau joueur',
                      color: context.colors.primary500,
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
                const SizedBox(height: 16),
                ...activePlayers.map((player) {
                  final isSelected = _selectedPlayerIds.contains(player.id);
                  final team = _playerTeamAssignments[player.id];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: context.colors.primary500.withValues(alpha: 0.2),
                            backgroundImage: player.avatarUrl != null ? NetworkImage(player.avatarUrl!) : null,
                            child: player.avatarUrl == null
                                ? Text(player.name.substring(0, 1).toUpperCase(), style: TextStyle(color: context.colors.primary500, fontWeight: FontWeight.bold, fontSize: 13))
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(player.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                if (player.nickname != null)
                                  Text('« ${player.nickname} »', style: TextStyle(color: context.colors.foreground500, fontSize: 12)),
                              ],
                            ),
                          ),
                          if (!isSelected)
                            TextButton.icon(
                              icon: const Icon(Remix.add_line, size: 16),
                              label: const Text('Présent'),
                              style: TextButton.styleFrom(
                                foregroundColor: context.colors.primary400,
                                backgroundColor: context.colors.primary500.withValues(alpha: 0.1),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () {
                                setState(() {
                                  _selectedPlayerIds.add(player.id);
                                  final aCount = _playerTeamAssignments.values.where((v) => v == 'A').length;
                                  final bCount = _playerTeamAssignments.values.where((v) => v == 'B').length;
                                  _playerTeamAssignments[player.id] = aCount <= bCount ? 'A' : 'B';
                                });
                              },
                            )
                          else
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SegmentedButton<String>(
                                  segments: const [
                                    ButtonSegment(value: 'A', label: Text('A', style: TextStyle(fontWeight: FontWeight.bold))),
                                    ButtonSegment(value: 'B', label: Text('B', style: TextStyle(fontWeight: FontWeight.bold))),
                                  ],
                                  selected: team != null ? {team} : <String>{},
                                  emptySelectionAllowed: true,
                                  style: SegmentedButton.styleFrom(
                                    backgroundColor: context.colors.background800,
                                    selectedBackgroundColor: team == 'A'
                                        ? context.colors.accent500.withValues(alpha: 0.3)
                                        : context.colors.secondary500.withValues(alpha: 0.3),
                                    selectedForegroundColor: team == 'A'
                                        ? context.colors.accent400
                                        : context.colors.secondary400,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  onSelectionChanged: (newSelection) {
                                    setState(() {
                                      if (newSelection.isEmpty) {
                                        _playerTeamAssignments.remove(player.id);
                                      } else {
                                        _playerTeamAssignments[player.id] = newSelection.first;
                                      }
                                    });
                                  },
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  icon: const Icon(Remix.close_circle_line),
                                  color: context.colors.foreground500,
                                  iconSize: 20,
                                  tooltip: 'Retirer',
                                  onPressed: () {
                                    setState(() {
                                      _selectedPlayerIds.remove(player.id);
                                      _playerTeamAssignments.remove(player.id);
                                    });
                                  },
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Erreur: $err')),
        ),
      ],
    );
  }
}
