import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/participation.dart';
import '../domain/session.dart';
import '../domain/team_appearance.dart';

extension SessionTeamColors on Session {
  Color teamColor(BuildContext context, Team team) {
    final custom = teamColors[teamKey(team)];
    if (custom != null) return Color(custom);
    return switch (team) {
      Team.a => context.colors.accent500,
      Team.b => context.colors.secondary500,
      Team.c => context.colors.primary500,
    };
  }
}
