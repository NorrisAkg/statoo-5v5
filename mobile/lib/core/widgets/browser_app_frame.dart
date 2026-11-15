import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'focus_ring.dart';

/// The browser's PWA menu has its own strip above every product screen.
/// Keep Flutter's full-page embedding so native keyboard metrics still apply.
/// Also hosts the app-wide keyboard focus ring (A11Y-001), above every route.
class BrowserAppFrame extends StatelessWidget {
  const BrowserAppFrame({
    required this.child,
    this.enabled = kIsWeb,
    super.key,
  });

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return FocusRing(child: child);
    // Shell: 14px label at 1.5 line height, 22px padding/border and 16px gap.
    final double stripHeight = math.max(
      64,
      MediaQuery.textScalerOf(context).scale(14) * 1.5 + 38,
    );
    return FocusRing(
      child: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Padding(
          padding: EdgeInsets.only(top: stripHeight),
          child: child,
        ),
      ),
    );
  }
}
