import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Reserve the actual height of a wrapping subtitle, including text scaling.
PreferredSizeWidget buildAppBarSubtitle(BuildContext context, String text) {
  final style = Theme.of(context).textTheme.bodyMedium!
      .copyWith(color: context.colors.onHeader, fontSize: 14);
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout(maxWidth: math.max(1, MediaQuery.sizeOf(context).width - 32));
  final height = painter.height;
  painter.dispose();
  return PreferredSize(
    preferredSize: Size.fromHeight(height + 8),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(text, style: style),
      ),
    ),
  );
}
