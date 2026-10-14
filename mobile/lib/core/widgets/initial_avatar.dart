import 'package:flutter/material.dart';

class InitialAvatar extends StatelessWidget {
  const InitialAvatar({
    required this.initial,
    required this.baseColor,
    this.size = 32,
    super.key,
  });

  final String initial;
  final Color baseColor;
  final double size;

  static Color colorForName(String name) {
    const palette = [
      Color(0xFF3B82F6), // blue
      Color(0xFF10B981), // emerald
      Color(0xFFF59E0B), // amber
      Color(0xFF8B5CF6), // violet
      Color(0xFFEC4899), // pink
      Color(0xFF06B6D4), // cyan
      Color(0xFFF97316), // orange
      Color(0xFF14B8A6), // teal
    ];
    if (name.isEmpty) return palette[0];
    var hash = 0;
    for (var i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return palette[hash.abs() % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Text(
        initial.toUpperCase(),
        style: TextStyle(
          color: baseColor,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.45,
        ),
      ),
    );
  }
}
