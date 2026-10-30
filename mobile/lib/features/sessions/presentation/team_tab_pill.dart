import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Onglet pilule représentant une équipe dans l'écran de détail et le panel live stats.
class TeamTabPill extends StatelessWidget {
  const TeamTabPill({
    required this.title,
    required this.playerCount,
    required this.color,
    required this.isSelected,
    required this.onTap,
    this.textColor,
    super.key,
  });

  final String title;
  final int playerCount;
  final Color color;
  final Color? textColor;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final effectiveTextColor = textColor ?? color;
    return Semantics(
      selected: isSelected,
      button: true,
      label: '$title, $playerCount joueurs',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.16)
                : context.colors.background900,
            borderRadius: BorderRadius.circular(9999),
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    style: TextStyle(
                      color: context.colors.foreground50,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.28)
                      : context.colors.background800,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(
                  '$playerCount',
                  style: TextStyle(
                    color: isSelected
                        ? effectiveTextColor
                        : context.colors.foreground500,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
