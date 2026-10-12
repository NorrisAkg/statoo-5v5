import 'participation.dart';
import 'session.dart';

const sessionTeamPalette = <String, int>{
  'Bleu': 0xFF3B82F6,
  'Orange': 0xFFF97316,
  'Vert': 0xFF22C55E,
  'Rouge': 0xFFEF4444,
  'Violet': 0xFF8B5CF6,
  'Rose': 0xFFEC4899,
  'Jaune': 0xFFFACC15,
  'Turquoise': 0xFF06B6D4,
};

String teamKey(Team team) => team.name.toUpperCase();
String defaultTeamName(Team team) => 'Équipe ${teamKey(team)}';
int defaultTeamColor(Team team) => switch (team) {
  Team.a => sessionTeamPalette['Bleu']!,
  Team.b => sessionTeamPalette['Orange']!,
  Team.c => sessionTeamPalette['Vert']!,
};

String effectiveTeamName(Team team, Map<String, String> names) {
  final name = names[teamKey(team)]?.trim();
  return name == null || name.isEmpty ? defaultTeamName(team) : name;
}

String? teamAppearanceError(
  SessionType type,
  Map<String, String> names,
  Map<String, int> colors,
) {
  final teams = type == SessionType.tournament3
      ? Team.values
      : [Team.a, Team.b];
  final seenNames = <String>{};
  final seenColors = <int>{};
  for (final team in teams) {
    if (!seenNames.add(effectiveTeamName(team, names).toLowerCase())) {
      return 'Chaque équipe doit avoir un nom différent.';
    }
    final color = colors[teamKey(team)] ?? defaultTeamColor(team);
    if (!sessionTeamPalette.containsValue(color)) {
      return 'Choisissez une couleur dans la palette.';
    }
    if (!seenColors.add(color)) {
      return 'Chaque équipe doit avoir une couleur différente.';
    }
  }
  return null;
}

extension SessionTeamAppearance on Session {
  String teamName(Team team) => effectiveTeamName(team, teamNames);
}
