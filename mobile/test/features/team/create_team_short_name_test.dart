import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statoo/core/theme/app_colors.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/features/team/presentation/create_team_screen.dart';

void main() {
  testWidgets('CreateTeamScreen champ Nom court a le style conforme au Design System', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const CreateTeamScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final labelFinder = find.text('Nom court (facultatif)');
    expect(labelFinder, findsOneWidget);
    final labelWidget = tester.widget<Text>(labelFinder);
    expect(labelWidget.style?.fontSize, 13);
    expect(labelWidget.style?.fontWeight, FontWeight.w700);

    final textFieldFinder = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText != null &&
          widget.decoration!.hintText!.contains('LI'),
    );
    expect(textFieldFinder, findsOneWidget);

    final textField = tester.widget<TextField>(textFieldFinder);
    final decoration = textField.decoration;
    expect(decoration, isNotNull);

    expect(decoration!.filled, isTrue);
    final element = tester.element(textFieldFinder);
    expect(decoration.fillColor, element.colors.background900);

    expect(decoration.border, isA<OutlineInputBorder>());
    final border = decoration.border! as OutlineInputBorder;
    expect(border.borderRadius, BorderRadius.circular(16));

    expect(decoration.focusedBorder, isA<OutlineInputBorder>());
    final focusedBorder = decoration.focusedBorder! as OutlineInputBorder;
    expect(focusedBorder.borderRadius, BorderRadius.circular(16));
    expect(focusedBorder.borderSide.color, element.colors.primary500);
    expect(focusedBorder.borderSide.width, 2.0);

    expect(decoration.prefixIcon, isNotNull);
    expect(find.descendant(of: textFieldFinder, matching: find.byType(Icon)), findsOneWidget);
  });
}
