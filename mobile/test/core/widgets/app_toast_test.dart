import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remixicon/remixicon.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/core/widgets/app_toast.dart';

void main() {
  Widget buildApp({required Widget home}) => MaterialApp(
        theme: AppTheme.darkTheme,
        home: home,
      );

  group('AppToast & showTopToast', () {
    testWidgets('affiche un toast en haut avec message et icone de type error', (tester) async {
      await tester.pumpWidget(
        buildApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showTopToast(
                    context,
                    message: 'Erreur de connexion',
                    type: ToastType.error,
                  );
                },
                child: const Text('Ouvrir Toast'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Ouvrir Toast'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Erreur de connexion'), findsOneWidget);
      expect(find.byIcon(Remix.error_warning_line), findsOneWidget);

      final toastFinder = find.text('Erreur de connexion');
      final toastTop = tester.getTopLeft(toastFinder).dy;
      expect(toastTop, lessThan(150.0));
    });

    testWidgets('affiche le toast au-dessus d une ModalBottomSheet via rootOverlay', (tester) async {
      await tester.pumpWidget(
        buildApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  unawaited(
                    showModalBottomSheet<void>(
                      context: context,
                      builder: (sheetContext) => Container(
                        height: 300,
                        color: Colors.blue,
                        child: ElevatedButton(
                          onPressed: () {
                            showTopToast(
                              sheetContext,
                              message: 'Toast par dessus la feuille',
                              type: ToastType.warning,
                            );
                          },
                          child: const Text('Declencher depuis sheet'),
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Ouvrir Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Ouvrir Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Declencher depuis sheet'), findsOneWidget);

      await tester.tap(find.text('Declencher depuis sheet'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Toast par dessus la feuille'), findsOneWidget);
    });

    testWidgets('ferme le toast lors du tap sur le bouton fermer / dismiss', (tester) async {
      await tester.pumpWidget(
        buildApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showTopToast(
                    context,
                    message: 'A fermer manuellement',
                  );
                },
                child: const Text('Ouvrir Toast'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Ouvrir Toast'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('A fermer manuellement'), findsOneWidget);

      final closeButton = find.byIcon(Remix.close_line);
      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('A fermer manuellement'), findsNothing);
    });

    testWidgets('ferme automatiquement le toast apres la duree specifiee', (tester) async {
      await tester.pumpWidget(
        buildApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showTopToast(
                    context,
                    message: 'Temporaire',
                    duration: const Duration(seconds: 2),
                  );
                },
                child: const Text('Ouvrir Toast'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Ouvrir Toast'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Temporaire'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2, milliseconds: 100));
      await tester.pumpAndSettle();
      expect(find.text('Temporaire'), findsNothing);
    });
  });
}
