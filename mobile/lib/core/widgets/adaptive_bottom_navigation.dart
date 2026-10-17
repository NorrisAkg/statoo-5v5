import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Destinations keep their full label and requested text size. On narrow
/// screens the row scrolls instead of shrinking or clipping the labels.
class AdaptiveBottomNavigation extends StatefulWidget {
  const AdaptiveBottomNavigation({
    required this.items,
    required this.currentIndex,
    required this.onTap,
    required this.backgroundColor,
    required this.selectedItemColor,
    required this.unselectedItemColor,
    super.key,
  });
  final List<BottomNavigationBarItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Color backgroundColor;
  final Color selectedItemColor;
  final Color unselectedItemColor;

  @override
  State<AdaptiveBottomNavigation> createState() =>
      _AdaptiveBottomNavigationState();
}

class _AdaptiveBottomNavigationState extends State<AdaptiveBottomNavigation> {
  final GlobalKey _selectedKey = GlobalKey();

  @override
  void didUpdateWidget(covariant AdaptiveBottomNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = _selectedKey.currentContext;
        if (mounted && context != null) {
          Scrollable.ensureVisible(context, alignment: .5);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => Material(
    color: widget.backgroundColor,
    child: SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scaler = MediaQuery.textScalerOf(context);
          final style = Theme.of(context).textTheme.labelMedium!
              .copyWith(fontSize: 12, fontWeight: FontWeight.w600);
          final widths = widget.items.map((item) {
            final painter = TextPainter(
              text: TextSpan(text: item.label, style: style),
              textDirection: Directionality.of(context),
              textScaler: scaler,
            )..layout();
            final double width = math.max(
              constraints.maxWidth / widget.items.length,
              math.max(64, painter.width + 8),
            );
            painter.dispose();
            return width;
          }).toList();
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < widget.items.length; i++)
                  SizedBox(
                    width: widths[i],
                    child: Semantics(
                      selected: i == widget.currentIndex,
                      button: true,
                      child: InkWell(
                        key: i == widget.currentIndex ? _selectedKey : null,
                        onTap: () => widget.onTap(i),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 56),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 8,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconTheme(
                                  data: IconThemeData(
                                    color: i == widget.currentIndex
                                        ? widget.selectedItemColor
                                        : widget.unselectedItemColor,
                                    size: 24,
                                  ),
                                  child: i == widget.currentIndex
                                      ? widget.items[i].activeIcon
                                      : widget.items[i].icon,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.items[i].label ?? '',
                                  style: style.copyWith(
                                    color: i == widget.currentIndex
                                        ? widget.selectedItemColor
                                        : widget.unselectedItemColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    ),
  );
}
