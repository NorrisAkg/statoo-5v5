import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statoo/core/widgets/app_form_dialog.dart';

void main() {
  for (final cancel in [false, true]) {
    testWidgets(
      'controllers remain alive through dialog dismissal (cancel: $cancel)',
      (tester) async {
        var disposed = false;
        bool? result;
        final controller = TextEditingController();
        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, update) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await showAppFormDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        content: TextField(controller: controller),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, !cancel),
                            child: const Text('Fermer'),
                          ),
                        ],
                      ),
                    );
                    controller.dispose();
                    disposed = true;
                    update(() {});
                  },
                  child: Text(disposed ? 'Fermé' : 'Ouvrir'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Ouvrir'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '1000');
        await tester.tap(find.text('Fermer'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(disposed, isFalse);
        expect(controller.text, '1000');
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();
        expect(disposed, isTrue);
        expect(result, !cancel);
        expect(find.text('Fermé'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
