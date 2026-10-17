import 'package:flutter/material.dart';

/// Equal-width columns chosen from the space and the requested text size.
/// Children retain their natural height and never scale their contents down.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    required this.children,
    this.maxColumns = 2,
    this.minItemWidth = 144,
    this.spacing = 12,
    super.key,
  });

  final List<Widget> children;
  final int maxColumns;
  final double minItemWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
      final columns =
          ((constraints.maxWidth + spacing) /
                  (minItemWidth * textScale + spacing))
              .floor()
              .clamp(1, maxColumns);
      final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}
