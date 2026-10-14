import 'package:flutter/material.dart';

/// Un widget vectoriel représentant une chaussure unique de football à crampons.
class SoccerShoeIcon extends StatelessWidget {
  const SoccerShoeIcon({
    super.key,
    this.size = 14,
    this.color,
    this.semanticLabel,
  });

  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? IconTheme.of(context).color ?? Colors.white;
    final widget = CustomPaint(
      size: Size(size, size),
      painter: _SoccerShoePainter(color: iconColor),
    );
    if (semanticLabel != null) {
      return Semantics(
        label: semanticLabel,
        child: widget,
      );
    }
    return widget;
  }
}

class _SoccerShoePainter extends CustomPainter {
  const _SoccerShoePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final s = size.width / 24.0;
    final path = Path()
      ..moveTo(s * 21.0, s * 8.0)
      ..cubicTo(s * 20.76, s * 8.0, s * 20.53, s * 8.0, s * 20.3, s * 8.0)
      ..lineTo(s * 20.25, s * 7.97)
      ..cubicTo(s * 18.14, s * 7.84, s * 16.38, s * 7.17, s * 15.53, s * 6.23)
      ..lineTo(s * 14.0, s * 7.0)
      ..cubicTo(s * 13.95, s * 7.1, s * 13.89, s * 7.19, s * 13.84, s * 7.28)
      ..cubicTo(s * 14.55, s * 7.89, s * 15.0, s * 8.65, s * 15.0, s * 9.5)
      ..cubicTo(s * 15.0, s * 9.83, s * 14.91, s * 10.14, s * 14.79, s * 10.45)
      ..lineTo(s * 12.92, s * 8.58)
      ..cubicTo(s * 12.7, s * 8.83, s * 12.47, s * 9.07, s * 12.22, s * 9.29)
      ..lineTo(s * 14.25, s * 11.32)
      ..cubicTo(s * 14.04, s * 11.57, s * 13.8, s * 11.79, s * 13.5, s * 12.0)
      ..lineTo(s * 11.43, s * 9.91)
      ..cubicTo(s * 11.14, s * 10.11, s * 10.85, s * 10.28, s * 10.55, s * 10.45)
      ..lineTo(s * 12.58, s * 12.5)
      ..cubicTo(s * 12.25, s * 12.63, s * 11.89, s * 12.74, s * 11.5, s * 12.82)
      ..lineTo(s * 9.59, s * 10.91)
      ..cubicTo(s * 9.25, s * 11.05, s * 8.91, s * 11.18, s * 8.56, s * 11.29)
      ..lineTo(s * 10.26, s * 13.0)
      ..cubicTo(s * 10.17, s * 13.0, s * 10.09, s * 13.0, s * 10.0, s * 13.0)
      ..cubicTo(s * 8.5, s * 13.0, s * 7.2, s * 12.54, s * 6.28, s * 11.82)
      ..cubicTo(s * 5.46, s * 11.95, s * 4.68, s * 12.0, s * 4.0, s * 12.0)
      ..cubicTo(s * 2.0, s * 12.0, s * 2.0, s * 15.0, s * 2.0, s * 15.0)
      ..cubicTo(s * 2.0, s * 16.11, s * 2.89, s * 17.0, s * 4.0, s * 17.0)
      ..lineTo(s * 4.0, s * 18.0)
      ..cubicTo(s * 4.0, s * 18.55, s * 4.45, s * 19.0, s * 5.0, s * 19.0)
      ..cubicTo(s * 5.55, s * 19.0, s * 6.0, s * 18.55, s * 6.0, s * 18.0)
      ..lineTo(s * 6.0, s * 17.0)
      ..lineTo(s * 7.0, s * 17.0)
      ..lineTo(s * 7.0, s * 18.0)
      ..cubicTo(s * 7.0, s * 18.55, s * 7.45, s * 19.0, s * 8.0, s * 19.0)
      ..cubicTo(s * 8.55, s * 19.0, s * 9.0, s * 18.55, s * 9.0, s * 18.0)
      ..lineTo(s * 9.0, s * 17.0)
      ..lineTo(s * 10.0, s * 17.0)
      ..lineTo(s * 10.0, s * 18.0)
      ..cubicTo(s * 10.0, s * 18.55, s * 10.45, s * 19.0, s * 11.0, s * 19.0)
      ..cubicTo(s * 11.55, s * 19.0, s * 12.0, s * 18.55, s * 12.0, s * 18.0)
      ..lineTo(s * 12.0, s * 17.0)
      ..lineTo(s * 15.0, s * 17.0)
      ..lineTo(s * 15.0, s * 18.0)
      ..cubicTo(s * 15.0, s * 18.55, s * 15.45, s * 19.0, s * 16.0, s * 19.0)
      ..cubicTo(s * 16.55, s * 19.0, s * 17.0, s * 18.55, s * 17.0, s * 18.0)
      ..lineTo(s * 17.0, s * 17.0)
      ..lineTo(s * 18.0, s * 17.0)
      ..lineTo(s * 18.0, s * 18.0)
      ..cubicTo(s * 18.0, s * 18.55, s * 18.45, s * 19.0, s * 19.0, s * 19.0)
      ..cubicTo(s * 19.55, s * 19.0, s * 20.0, s * 18.55, s * 20.0, s * 18.0)
      ..lineTo(s * 20.0, s * 17.0)
      ..lineTo(s * 21.0, s * 17.0)
      ..cubicTo(s * 21.0, s * 17.0, s * 22.0, s * 17.0, s * 22.0, s * 12.5)
      ..cubicTo(s * 22.0, s * 9.0, s * 21.0, s * 8.0, s * 21.0, s * 8.0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SoccerShoePainter oldDelegate) =>
      color != oldDelegate.color;
}
