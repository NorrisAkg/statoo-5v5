import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A step badge that reserves its wrapped height instead of inheriting the
/// app bar's single-line ellipsis.
PreferredSizeWidget buildAppStepTitle(
  BuildContext context,
  String text, {
  required bool hasLeading,
  String? actionLabel,
}) {
  final scaler = MediaQuery.textScalerOf(context);
  final style = Theme.of(context).textTheme.labelLarge!.copyWith(
    color: context.colors.primary400,
    fontSize: 12,
    fontWeight: FontWeight.bold,
  );
  double actionWidth = 0;
  if (actionLabel != null) {
    final painter = TextPainter(
      text: TextSpan(
        text: actionLabel,
        style: Theme.of(context).textTheme.labelLarge!
            .copyWith(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      textDirection: Directionality.of(context),
      textScaler: scaler,
    )..layout();
    actionWidth = painter.width + 32;
    painter.dispose();
  }
  final double width = math.max(
    1,
    MediaQuery.sizeOf(context).width -
        32 -
        (hasLeading ? kToolbarHeight : 0) -
        actionWidth -
        26,
  );
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: scaler,
  )..layout(maxWidth: width);
  final double height = math.max(kToolbarHeight, painter.height + 16);
  painter.dispose();
  return PreferredSize(
    preferredSize: Size.fromHeight(height),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: context.colors.primary500.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(
          color: context.colors.primary500.withValues(alpha: .3),
        ),
      ),
      child: DefaultTextStyle(
        style: style,
        overflow: TextOverflow.visible,
        child: Text(text),
      ),
    ),
  );
}
