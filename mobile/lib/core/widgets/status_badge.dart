import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum BadgeStatus { closed, win, draw, loss, friendly }

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    required this.status,
    super.key,
  });

  final BadgeStatus status;

  @override
  Widget build(BuildContext context) {
    final (String label, Color color) = switch (status) {
      BadgeStatus.closed => ('Clôturée', context.colors.primary500),
      BadgeStatus.win => ('Victoire', context.colors.primary500),
      BadgeStatus.draw => ('Nul', context.colors.foreground400),
      BadgeStatus.loss => ('Défaite', context.colors.danger),
      BadgeStatus.friendly => ('Amical', context.colors.warning),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
