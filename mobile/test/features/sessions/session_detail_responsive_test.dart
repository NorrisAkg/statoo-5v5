import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/features/sessions/application/sessions_provider.dart';
import 'package:statoo/features/sessions/domain/session.dart';
import 'package:statoo/features/sessions/presentation/session_detail_screen.dart';
import 'package:statoo/features/shared/application/shared_providers.dart';

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('fr_FR');
  });
  for (final width in [320.0, 393.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      for (final dark in [false, true]) {
        for (final mode in ['waiting', 'active', 'readonly']) {
          testWidgets(
            'D04-01/02/03/04/05/06 $mode fits $width dp scale=$scale dark=$dark',
            (tester) async {
              tester.view.physicalSize = Size(width, 852);
              tester.view.devicePixelRatio = 1;
              addTearDown(tester.view.resetPhysicalSize);
              addTearDown(tester.view.resetDevicePixelRatio);
              await tester.pumpWidget(
                ProviderScope(
                  overrides: [
                    sessionDetailProvider('s').overrideWith(
                      (ref) async => Session(
                        id: 's',
                        playedAt: DateTime(2026, 10, 15),
                        status: mode == 'readonly'
                            ? SessionStatus.closed
                            : SessionStatus.draft,
                        teamNames: const {
                          'A': 'Les Lions du quartier et leurs amis',
                          'B': 'Les Aigles de la grande ville',
                        },
                      ),
                    ),
                    sessionParticipantsProvider('s')
                        .overrideWith((ref) async => []),
                    activeSessionIdProvider.overrideWith(
                      (ref) async => mode == 'active' ? 's' : 'other',
                    ),
                    canWriteSessionProvider((domain: 'sport', sessionId: 's'))
                        .overrideWith((ref) async => mode != 'readonly'),
                  ],
                  child: MaterialApp(
                    theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(textScaler: TextScaler.linear(scale)),
                      child: child!,
                    ),
                    home: const SessionDetailScreen(sessionId: 's'),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              final action = find.widgetWithText(
                TextButton,
                'Ajouter un joueur',
              );
              if (mode == 'readonly') {
                expect(action, findsNothing);
                return;
              }
              await tester.scrollUntilVisible(
                action,
                200,
                scrollable: find.byType(Scrollable).first,
              );
              await tester.pumpAndSettle();
              final bounds = tester.getRect(action);
              expect(bounds.left, greaterThanOrEqualTo(0));
              expect(bounds.right, lessThanOrEqualTo(width));
              expect(action.hitTestable(), findsOneWidget);
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  }
}
