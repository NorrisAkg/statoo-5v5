import 'package:flutter/material.dart';

class InitialAvatar extends StatelessWidget {
  final String initial;
  final Color baseColor;
  final double size;

  const InitialAvatar({
    super.key,
    required this.initial,
    required this.baseColor,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: baseColor.withOpacity(0.15),
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
