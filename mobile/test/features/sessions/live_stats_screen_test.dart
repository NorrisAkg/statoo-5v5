import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:remixicon/remixicon.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/core/widgets/app_card.dart';
import 'package:statoo/core/widgets/soccer_shoe_icon.dart';
import 'package:statoo/features/sessions/application/sessions_provider.dart';
import 'package:statoo/features/sessions/domain/participation.dart';
import 'package:statoo/features/sessions/domain/session.dart';
import 'package:statoo/features/sessions/domain/session_summary.dart';
import 'package:statoo/features/sessions/presentation/session_detail_screen.dart';
import 'package:statoo/features/shared/application/shared_providers.dart';

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('fr_FR');
  });

  testWidgets(
    'LIVE-ICONS: player stats in active session display icons for goals, assists, yellow and red cards instead of text',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            liveJournalProvider('s').overrideWith((ref) async => []),
            sessionDetailProvider('s').overrideWith(
              (ref) async => Session(
                id: 's',
                playedAt: DateTime(2026, 10, 30),
                scoreA: 3,
                scoreB: 0,
              ),
            ),
            sessionParticipantsProvider('s').overrideWith(
              (ref) async => [
                const SessionParticipantDetail(
                  participation: Participation(
                    id: 'p1',
                    sessionId: 's',
                    playerId: 'p1',
                    team: Team.a,
                    goals: 3,
                    assists: 2,
                    yellowCards: 1,
                    redCards: 1,
                  ),
                  playerName: 'Karim',
                ),
                const SessionParticipantDetail(
                  participation: Participation(
                    id: 'p2',
                    sessionId: 's',
                    playerId: 'p2',
                    team: Team.a,
                  ),
                  playerName: 'Youssef',
                ),
              ],
            ),
            activeSessionIdProvider.overrideWith((ref) async => 's'),
            canWriteSessionProvider((domain: 'sport', sessionId: 's'))
                .overrideWith((ref) async => true),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const SessionDetailScreen(sessionId: 's'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify players are displayed
      expect(find.text('Karim'), findsWidgets);
      expect(find.text('Youssef'), findsOneWidget);

      // Under player names, raw text labels "buts", "passes", "jaune", "rouge" must be replaced by icons
      final rosterCard = find.byType(AppCard);
      expect(find.descendant(of: rosterCard, matching: find.textContaining('buts')), findsNothing);
      expect(find.descendant(of: rosterCard, matching: find.textContaining('passes')), findsNothing);
      expect(find.descendant(of: rosterCard, matching: find.textContaining('jaune')), findsNothing);
      expect(find.descendant(of: rosterCard, matching: find.textContaining('rouge')), findsNothing);

      // Verify the icons are present for the players
      // For each player (Karim and Youssef), there should be football_line and SoccerShoeIcon
      expect(find.descendant(of: rosterCard, matching: find.byIcon(Remix.football_line)), findsNWidgets(2));
      expect(find.descendant(of: rosterCard, matching: find.byType(SoccerShoeIcon)), findsNWidgets(2));

      // Verify counts are displayed
      expect(find.descendant(of: rosterCard, matching: find.text('3')), findsOneWidget); // Karim's goals
      expect(find.descendant(of: rosterCard, matching: find.text('2')), findsOneWidget); // Karim's assists
      expect(find.descendant(of: rosterCard, matching: find.text('1')), findsNWidgets(2)); // Karim's yellow and red cards
      expect(find.descendant(of: rosterCard, matching: find.text('0')), findsNWidgets(4)); // Youssef's 0s

      // Verify accessible semantics are retained
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label ==
                  'Karim: 3 buts, 2 passes, 1 cartons jaunes, 1 cartons rouges',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label ==
                  'Youssef: 0 buts, 0 passes, 0 cartons jaunes, 0 cartons rouges',
        ),
        findsOneWidget,
      );
    },
  );
  for (final width in [320.0, 393.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
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
          final goal = find.byTooltip('Ajouter un but');
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
    }
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
      final goal = find.byTooltip('Ajouter un but');
      if (!writable) {
        expect(goal, findsNothing);
        return;
      }
      expect(goal, findsOneWidget);
      expect(find.byIcon(Remix.check_line), findsNothing);
      expect(find.text('Actif'), findsNothing);
      await tester.scrollUntilVisible(
        goal,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .getSize(find.byTooltip('Ajouter un but'))
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

  testWidgets(
    'LIVE-PILL-TABS: LiveStatsPanel renders full capsule pill tabs with dot, name, badge count and no square OutlinedButton or Actif label',
    (tester) async {
      const colorA = Color(0xFF3B82F6);
      const colorB = Color(0xFFEF4444);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            liveJournalProvider('s_pill').overrideWith((ref) async => []),
            sessionDetailProvider('s_pill').overrideWith(
              (ref) async => Session(
                id: 's_pill',
                playedAt: DateTime(2026, 10, 30),
                teamNames: const {'A': 'Galactiques', 'B': 'Invincibles'},
                teamColors: const {'A': 0xFF3B82F6, 'B': 0xFFEF4444},
              ),
            ),
            sessionParticipantsProvider('s_pill').overrideWith(
              (ref) async => [
                const SessionParticipantDetail(
                  participation: Participation(
                    id: 'p1',
                    sessionId: 's_pill',
                    playerId: 'p1',
                    team: Team.a,
                  ),
                  playerName: 'Zidane',
                ),
                const SessionParticipantDetail(
                  participation: Participation(
                    id: 'p2',
                    sessionId: 's_pill',
                    playerId: 'p2',
                    team: Team.a,
                  ),
                  playerName: 'Ronaldo',
                ),
                const SessionParticipantDetail(
                  participation: Participation(
                    id: 'p3',
                    sessionId: 's_pill',
                    playerId: 'p3',
                    team: Team.b,
                  ),
                  playerName: 'Henry',
                ),
              ],
            ),
            activeSessionIdProvider.overrideWith((ref) async => 's_pill'),
            canWriteSessionProvider((domain: 'sport', sessionId: 's_pill'))
                .overrideWith((ref) async => true),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const SessionDetailScreen(sessionId: 's_pill'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify custom team names appear on pill tabs
      expect(find.text('Galactiques'), findsWidgets);
      expect(find.text('Invincibles'), findsWidgets);

      // Verify NO 'Actif' or check icons on the tabs
      expect(find.text('Actif'), findsNothing);
      expect(find.byIcon(Remix.check_line), findsNothing);

      // Verify NO OutlinedButton is used for the tabs
      expect(find.widgetWithText(OutlinedButton, 'Galactiques'), findsNothing);
      expect(find.widgetWithText(OutlinedButton, 'Invincibles'), findsNothing);

      // Verify Team A pill tab container has capsule border radius (9999) and selected border color
      final tabAContainer = tester.widget<AnimatedContainer>(
        find.widgetWithText(AnimatedContainer, 'Galactiques'),
      );
      final tabADeco = tabAContainer.decoration! as BoxDecoration;
      expect(tabADeco.borderRadius, BorderRadius.circular(9999));
      expect(tabADeco.border?.top.color, colorA);

      // Verify Team B pill tab container has capsule border radius and transparent border when unselected
      final tabBContainer = tester.widget<AnimatedContainer>(
        find.widgetWithText(AnimatedContainer, 'Invincibles'),
      );
      final tabBDeco = tabBContainer.decoration! as BoxDecoration;
      expect(tabBDeco.borderRadius, BorderRadius.circular(9999));
      expect(tabBDeco.border?.top.color, Colors.transparent);

      // Verify player count badges (2 for Team A, 1 for Team B)
      final counterAText = tester.widget<Text>(find.descendant(
        of: find.widgetWithText(AnimatedContainer, 'Galactiques'),
        matching: find.text('2'),
      ));
      expect(counterAText.style?.color, colorA);

      final counterBText = tester.widget<Text>(find.descendant(
        of: find.widgetWithText(AnimatedContainer, 'Invincibles'),
        matching: find.text('1'),
      ));
      expect(counterBText.style?.color, isNot(colorB));

      // Verify team A players are visible initially
      expect(find.text('Zidane'), findsOneWidget);
      expect(find.text('Ronaldo'), findsOneWidget);
      expect(find.text('Henry'), findsNothing);

      // Tap on Team B tab
      await tester.tap(find.widgetWithText(AnimatedContainer, 'Invincibles'));
      await tester.pumpAndSettle();

      // Now Team B is selected: its border is colorB, Team A border is transparent
      final tabBAfter = tester.widget<AnimatedContainer>(
        find.widgetWithText(AnimatedContainer, 'Invincibles'),
      );
      final tabBDecoAfter = tabBAfter.decoration! as BoxDecoration;
      expect(tabBDecoAfter.border?.top.color, colorB);

      final tabAAfter = tester.widget<AnimatedContainer>(
        find.widgetWithText(AnimatedContainer, 'Galactiques'),
      );
      final tabADecoAfter = tabAAfter.decoration! as BoxDecoration;
      expect(tabADecoAfter.border?.top.color, Colors.transparent);

      // And Henry (Team B player) is visible, Zidane is not
      expect(find.text('Henry'), findsOneWidget);
      expect(find.text('Zidane'), findsNothing);
    },
  );
}
