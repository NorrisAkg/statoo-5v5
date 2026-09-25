import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum BadgeStatus { closed, win, draw, loss, friendly }

class StatusBadge extends StatelessWidget {
  final BadgeStatus status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;

    switch (status) {
      case BadgeStatus.closed:
        label = 'Clôturée';
        color = context.colors.primary500;
        break;
      case BadgeStatus.win:
        label = 'Victoire';
        color = context.colors.primary500;
        break;
      case BadgeStatus.draw:
        label = 'Nul';
        color = context.colors.foreground400;
        break;
      case BadgeStatus.loss:
        label = 'Défaite';
        color = context.colors.danger;
        break;
      case BadgeStatus.friendly:
        label = 'Amical';
        color = context.colors.warning;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
