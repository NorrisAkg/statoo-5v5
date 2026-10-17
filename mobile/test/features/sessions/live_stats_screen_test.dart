import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/features/sessions/application/sessions_provider.dart';
import 'package:statoo/features/sessions/domain/session.dart';
import 'package:statoo/features/sessions/domain/participation.dart';
import 'package:statoo/features/sessions/domain/session_summary.dart';
import 'package:statoo/features/sessions/presentation/session_detail_screen.dart';
import 'package:statoo/features/shared/application/shared_providers.dart';

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('fr_FR');
  });
  for (final width in [320.0, 393.0])
    for (final scale in [1.0, 1.3, 2.0])
      for (final dark in [false, true]) {
        testWidgets('INT-15 populated tournament $width/$scale/$dark', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 852);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                liveJournalProvider('s').overrideWith((ref) async => []),
                sessionDetailProvider('s').overrideWith(
                  (ref) async => Session(
                    id: 's',
                    playedAt: DateTime(2026),
                    sessionType: SessionType.tournament3,
                    teamNames: const {
                      'A': 'Racing du grand quartier',
                      'B': 'Union des Cèdres',
                      'C': 'Sporting du Port',
                    },
                  ),
                ),
                sessionParticipantsProvider('s').overrideWith(
                  (ref) async => [
                    for (final t in Team.values)
                      SessionParticipantDetail(
                        participation: Participation(
                          id: t.name,
                          sessionId: 's',
                          playerId: t.name,
                          team: t,
                          goals: 12,
                          assists: 4,
                          yellowCards: 2,
                        ),
                        playerName: 'Jean-Baptiste de La Roche Saint-André',
                      ),
                  ],
                ),
                activeSessionIdProvider.overrideWith((ref) async => 's'),
                canWriteSessionProvider((domain: 'sport', sessionId: 's'))
                    .overrideWith((ref) async => true),
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
          final goal = find.text('Ajouter un but');
          await tester.dragUntilVisible(
            goal.hitTestable(),
            find.byType(ListView).first,
            const Offset(0, -250),
          );
          await tester.pumpAndSettle();
          await tester.tap(goal);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(
            find.text('Jean-Baptiste de La Roche Saint-André').last,
          );
          await tester.tap(
            find.widgetWithText(
              TextButton,
              'Jean-Baptiste de La Roche Saint-André',
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.text('Annuler le but'));
          await tester.tap(find.text('Annuler le but'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
  for (final writable in [true, false]) {
    testWidgets('INT-11/12 live goal picker and consultation $writable', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            liveJournalProvider('s').overrideWith((ref) async => []),
            sessionDetailProvider('s').overrideWith(
              (ref) async => Session(
                id: 's',
                playedAt: DateTime(2026, 10, 17),
                scoreA: 0,
                scoreB: 0,
              ),
            ),
            sessionParticipantsProvider('s').overrideWith(
              (ref) async => [
                for (final id in ['p', 'q'])
                  SessionParticipantDetail(
                    participation: Participation(
                      id: id,
                      sessionId: 's',
                      playerId: id,
                      team: Team.a,
                    ),
                    playerName: id == 'p' ? 'Karim' : 'Youssef',
                  ),
              ],
            ),
            activeSessionIdProvider.overrideWith((ref) async => 's'),
            canWriteSessionProvider((domain: 'sport', sessionId: 's'))
                .overrideWith((ref) async => writable),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const SessionDetailScreen(sessionId: 's'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final goal = find.text('Ajouter un but');
      if (!writable) {
        expect(goal, findsNothing);
        return;
      }
      expect(goal, findsOneWidget);
      expect(find.byIcon(Remix.check_line), findsOneWidget);
      await tester.scrollUntilVisible(
        goal,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .getSize(find.widgetWithText(FilledButton, 'Ajouter un but'))
            .height,
        greaterThanOrEqualTo(48),
      );
      await tester.tap(goal);
      await tester.pumpAndSettle();
      expect(find.text('Qui a marqué ?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Karim'));
      await tester.pumpAndSettle();
      expect(find.text('But de Karim'), findsOneWidget);
      expect(find.text('Aucun passeur'), findsOneWidget);
      expect(find.text('Retour au buteur'), findsOneWidget);
      await tester.tap(find.text('Retour au buteur'));
      await tester.pumpAndSettle();
      expect(find.text('Qui a marqué ?'), findsOneWidget);
      await tester.tap(find.text('Annuler le but'));
      await tester.pumpAndSettle();
      expect(find.text('Qui a marqué ?'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
