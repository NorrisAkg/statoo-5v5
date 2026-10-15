import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../domain/participation.dart';
import '../domain/session.dart';
import '../domain/team_appearance.dart';

class TeamAppearanceEditor extends StatefulWidget {
  const TeamAppearanceEditor({
    required this.type,
    required this.names,
    required this.colors,
    required this.onNameChanged,
    required this.onColorChanged,
    required this.onReset,
    this.editableNames = true,
    super.key,
  });

  final SessionType type;
  final bool editableNames;
  final Map<String, String> names;
  final Map<String, int> colors;
  final void Function(Team team, String name) onNameChanged;
  final void Function(Team team, int color) onColorChanged;
  final void Function(Team team) onReset;

  @override
  State<TeamAppearanceEditor> createState() => _TeamAppearanceEditorState();
}

class _TeamAppearanceEditorState extends State<TeamAppearanceEditor> {
  final Map<Team, TextEditingController> _nameControllers = {};
  SessionType get type => widget.type;
  Map<String, String> get names => widget.names;
  Map<String, int> get colors => widget.colors;
  void Function(Team, String) get onNameChanged => widget.onNameChanged;
  void Function(Team, int) get onColorChanged => widget.onColorChanged;
  void Function(Team) get onReset => widget.onReset;

  @override
  void initState() {
    super.initState();
    for (final team in Team.values) {
      _nameControllers[team] = TextEditingController(
        text: names[teamKey(team)] ?? '',
      );
    }
  }

  @override
  void didUpdateWidget(TeamAppearanceEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    for (final team in Team.values) {
      final value = names[teamKey(team)] ?? '';
      if (_nameControllers[team]!.text != value) {
        _nameControllers[team]!.text = value;
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _nameControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teams = type == SessionType.tournament3
        ? Team.values
        : [Team.a, Team.b];
    final error = teamAppearanceError(type, names, colors);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.editableNames
              ? 'Personnaliser les équipes'
              : 'Équipes & couleurs',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          widget.editableNames
              ? 'Facultatif · Conservez les noms et couleurs par défaut ou choisissez les vôtres.'
              : 'Noms attribués au hasard · Choisissez les couleurs.',
          style: TextStyle(color: context.colors.foreground400, fontSize: 12),
        ),
        for (final team in teams) ...[
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Remix.shield_fill,
                      color: Color(
                        colors[teamKey(team)] ?? defaultTeamColor(team),
                      ),
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        effectiveTeamName(team, names),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Réinitialiser ${defaultTeamName(team)}',
                      onPressed: () => onReset(team),
                      icon: const Icon(Remix.refresh_line, size: 18),
                    ),
                  ],
                ),
                if (widget.editableNames) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    key: ValueKey('team-name-${teamKey(team)}'),
                    controller: _nameControllers[team],
                    maxLength: 30,
                    decoration: InputDecoration(
                      labelText: 'Nom de ${defaultTeamName(team)}',
                      hintText: defaultTeamName(team),
                      counterText: '',
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (name) => onNameChanged(team, name),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final entry in sessionTeamPalette.entries)
                      Semantics(
                        selected:
                            (colors[teamKey(team)] ?? defaultTeamColor(team)) ==
                            entry.value,
                        child: IconButton(
                          key: ValueKey(
                            'team-color-${teamKey(team)}-${entry.key}',
                          ),
                          tooltip: '${entry.key} · ${defaultTeamName(team)}',
                          onPressed: () => onColorChanged(team, entry.value),
                          icon: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: Color(entry.value),
                              shape: BoxShape.circle,
                            ),
                            child:
                                (colors[teamKey(team)] ??
                                        defaultTeamColor(team)) ==
                                    entry.value
                                ? const Icon(
                                    Remix.check_line,
                                    color: Colors.black,
                                    size: 20,
                                  )
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(
            error,
            key: const ValueKey('team-appearance-error'),
            style: TextStyle(color: context.colors.danger),
          ),
        ],
      ],
    );
  }
}
