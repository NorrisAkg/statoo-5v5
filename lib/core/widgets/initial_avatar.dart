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
