import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/features/shared/presentation/decision_details.dart';

void main() {
  testWidgets(
    'D02-03 additions and removals differ from zero; unchanged values are expandable',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: DecisionDetails(
                rows: {
                  'Dépense · terrain': 'Terrain : 0 F',
                  'Cotisation · Alice (a)': '100 F',
                },
                others: [
                  {
                    'Dépense · eau': 'Eau : 80 F',
                    'Cotisation · Alice (a)': '100 F',
                  },
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.textContaining('Terrain : 0 F'), findsOneWidget);
      expect(find.textContaining('Absent de cette version'), findsOneWidget);
      expect(find.textContaining('Alice'), findsNothing);
      await tester.tap(find.textContaining('Détails inchangés'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Alice (a) : 100 F'), findsOneWidget);
    },
  );
  testWidgets('D02-04 compares with every candidate, not only the first', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DecisionDetails(
            rows: {'Score A': '1'},
            others: [
              {'Score A': '1'},
              {'Score A': '2'},
            ],
          ),
        ),
      ),
    );
    expect(find.text('Différence · Score A : 1'), findsOneWidget);
  });
}
