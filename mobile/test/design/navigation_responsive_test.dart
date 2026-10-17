import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:statoo/core/router/app_scaffold.dart';
import 'package:statoo/core/theme/app_theme.dart';

void main() {
  for (final width in [320.0, 393.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('RSP06 navigation width=$width scale=$scale', (tester) async {
        tester.view.physicalSize = Size(width, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final router = GoRouter(
          initialLocation: '/a',
          routes: [
            StatefulShellRoute.indexedStack(
              builder: (context, state, shell) =>
                  AppScaffold(navigationShell: shell),
              branches: [
                for (final route in ['a', 'b', 'c', 'd', 'e'])
                  StatefulShellBranch(
                    routes: [
                      GoRoute(
                        path: '/$route',
                        builder: (context, state) =>
                            Scaffold(body: Text('Page $route')),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (final label in [
          'Accueil',
          'Séances',
          'Joueurs',
          'Classement',
          'Stats',
        ]) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(label),
          );
          expect(paragraph.didExceedMaxLines, isFalse);
          expect(
            paragraph.textScaler.scale(12),
            closeTo(12 * scale, .01),
            reason: 'respect requested text size',
          );
          await tester.ensureVisible(find.text(label));
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        expect(find.text('Page e'), findsOneWidget);
      });
    }
  }
}
