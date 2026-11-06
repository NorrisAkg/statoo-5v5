import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:remixicon/remixicon.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/features/home/presentation/home_screen.dart';
import 'package:statoo/features/home/presentation/home_session_result.dart';
import 'package:statoo/features/sessions/application/sessions_provider.dart';
import 'package:statoo/features/sessions/domain/participation.dart';
import 'package:statoo/features/sessions/domain/session.dart';
import 'package:statoo/features/sessions/domain/session_summary.dart';

Session game({
  bool tournament = false,
  bool active = false,
  String id = 's',
  int unassigned = 0,
}) => Session(
  id: id,
  playedAt: DateTime(2026, 10, 15),
  status: active ? SessionStatus.draft : SessionStatus.closed,
  sessionType: tournament ? SessionType.tournament3 : SessionType.classic2,
  teamNames: const {
    'A': 'Racing Atlas',
    'B': 'Union des Cèdres',
    'C': 'Sporting du Port',
  },
  teamColors: const {'A': 0xFF8B5CF6, 'B': 0xFFEC4899, 'C': 0xFF06B6D4},
  scoreA: 5,
  scoreB: 2,
  winsA: 7,
  winsB: 4,
  winsC: 2,
  unassignedGoalsC: unassigned,
);

SessionParticipantDetail player(
  String name,
  Team team,
  int goals, {
  String sessionId = 's',
}) => SessionParticipantDetail(
  playerName: name,
  participation: Participation(
    id: name,
    sessionId: sessionId,
    playerId: name,
    team: team,
    goals: goals,
  ),
);

Finder block(Team team) => find.byKey(ValueKey('home-team-${team.name}'));
Finder scorerRow(Team team, String name) =>
    find.byKey(ValueKey('home-scorer-${team.name}-$name'));
Finder inside(Team team, String text) =>
    find.descendant(of: block(team), matching: find.text(text));

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  Future<ProviderContainer> mount(
    WidgetTester tester,
    Session Function() session,
    Future<List<SessionParticipantDetail>> Function(String) participants, {
    bool light = false,
    double width = 800,
  }) async {
    tester.view.physicalSize = Size(width, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        activeDraftSessionProvider.overrideWith(
          (ref) async =>
              session().status == SessionStatus.draft ? session() : null,
        ),
        allSessionsProvider.overrideWith(
          (ref) async => [
            SessionSummaryItem(session: session(), playerCount: 15),
          ],
        ),
        sessionParticipantsProvider.overrideWith((ref, id) => participants(id)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: light ? AppTheme.lightTheme : AppTheme.darkTheme,
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    return container;
  }

  for (final active in [false, true]) {
    for (final tournament in [false, true]) {
      testWidgets('BUT-01/02/03 active=$active tournament=$tournament', (
        tester,
      ) async {
        await mount(
          tester,
          () => game(active: active, tournament: tournament),
          (_) async => [
            player('Karim', Team.a, 3),
            player('Lucas', Team.a, 1),
            player('Amine', Team.b, 2),
            player('Samir', Team.c, 4),
          ],
        );
        expect(inside(Team.a, 'Karim'), findsOneWidget);
        expect(inside(Team.a, 'Lucas'), findsOneWidget);
        expect(inside(Team.a, 'x3'), findsOneWidget);
        expect(find.text('1 but'), findsNothing);
        expect(find.text('2 buts'), findsNothing);
        expect(find.text('3 buts'), findsNothing);
        expect(find.text('x1'), findsNothing);
        expect(find.text('x2'), findsNothing);

        // 1 goal -> 1 ball icon, no multiplier text
        final lucasBalls = find.descendant(
          of: scorerRow(Team.a, 'Lucas'),
          matching: find.byIcon(Remix.football_fill),
        );
        expect(lucasBalls, findsOneWidget);

        // 3 goals -> 1 ball icon + 'x3'
        final karimBalls = find.descendant(
          of: scorerRow(Team.a, 'Karim'),
          matching: find.byIcon(Remix.football_fill),
        );
        expect(karimBalls, findsOneWidget);

        // 2 goals -> 2 ball icons, no multiplier text
        expect(inside(Team.b, 'Amine'), findsOneWidget);
        final amineBalls = find.descendant(
          of: scorerRow(Team.b, 'Amine'),
          matching: find.byIcon(Remix.football_fill),
        );
        expect(amineBalls, findsNWidgets(2));

        if (tournament) {
          expect(inside(Team.c, 'Samir'), findsOneWidget);
          expect(inside(Team.c, 'x4'), findsOneWidget);
          expect(inside(Team.c, '2 V'), findsOneWidget);
          expect(
            tester.getTopLeft(block(Team.a)).dy,
            lessThan(tester.getTopLeft(block(Team.b)).dy),
          );
          expect(
            tester.getTopLeft(block(Team.b)).dy,
            lessThan(tester.getTopLeft(block(Team.c)).dy),
          );
          expect(
            tester
                .widget<Text>(inside(Team.c, 'Sporting du Port'))
                .style
                ?.color,
            const Color(0xFF06B6D4),
          );
        } else {
          expect(find.text('Samir'), findsNothing);
          // Classic mode: centered scoreboard between Team A and Team B
          final resultCard = find.byType(HomeSessionResult);
          final score5 = find.descendant(
            of: resultCard,
            matching: find.text('5'),
          );
          final score2 = find.descendant(
            of: resultCard,
            matching: find.text('2'),
          );
          expect(score5, findsOneWidget);
          expect(score2, findsOneWidget);

          final teamAName = find.descendant(
            of: resultCard,
            matching: find.text('Racing Atlas'),
          );
          final teamBName = find.descendant(
            of: resultCard,
            matching: find.text('Union des Cèdres'),
          );
          expect(teamAName, findsOneWidget);
          expect(teamBName, findsOneWidget);
          // Team shields like on session detail screen
          expect(
            find.descendant(
              of: resultCard,
              matching: find.byIcon(Remix.shield_fill),
            ),
            findsNWidgets(2),
          );
          // Score is horizontally centered between Team A identity and Team B identity
          expect(
            tester.getCenter(teamAName).dx,
            lessThan(tester.getCenter(score5).dx),
          );
          expect(
            tester.getCenter(score2).dx,
            lessThan(tester.getCenter(teamBName).dx),
          );
        }
        if (active) {
          expect(find.text('Reprendre le match en direct'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'BUT-04/05/06/07 session isolation, sorting, empty without placeholder text and unassigned',
    (tester) async {
      await mount(
        tester,
        () => game(tournament: true, unassigned: 2),
        (_) async => [
          player('Zaki', Team.a, 1),
          player('Amine', Team.a, 1),
          player('Karim', Team.a, 3),
          player('Sans but', Team.b, 0),
          player('Autre séance', Team.a, 99, sessionId: 'other'),
        ],
      );
      expect(find.text('Sans but'), findsNothing);
      expect(find.text('Autre séance'), findsNothing);
      expect(
        tester.getTopLeft(find.text('Karim')).dy,
        lessThan(tester.getTopLeft(find.text('Amine')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Amine')).dy,
        lessThan(tester.getTopLeft(find.text('Zaki')).dy),
      );
      // "Aucun but enregistré" must never appear
      expect(find.text('Aucun but enregistré'), findsNothing);
      expect(inside(Team.c, 'Non attribués'), findsOneWidget);
      final unassignedBalls = find.descendant(
        of: scorerRow(Team.c, 'Non attribués'),
        matching: find.byIcon(Remix.football_fill),
      );
      expect(unassignedBalls, findsNWidgets(2));
      expect(find.text('2 buts'), findsNothing);
    },
  );

  for (final light in [false, true]) {
    testWidgets(
      'BUT-08 narrow screen long names and many scorers light=$light',
      (tester) async {
        await mount(
          tester,
          () => game(tournament: true),
          (_) async => [
            for (var i = 0; i < 12; i++)
              player(
                'Joueur au nom particulièrement long numéro $i',
                Team.values[i % 3],
                i + 1,
              ),
          ],
          light: light,
          width: 320,
        );
        expect(
          find.text('Joueur au nom particulièrement long numéro 11'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'BUT-08b HomeSessionResult classic mode fits at 320px with 1.5x text scale and long team/player names',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = Session(
        id: 's-long',
        playedAt: DateTime(2026, 11, 6),
        teamNames: const {
          'A': 'Olympique de la Plaine',
          'B': 'Olympique Saint-Roch',
        },
        scoreA: 12,
        scoreB: 10,
      );
      final container = ProviderContainer(
        overrides: [
          sessionParticipantsProvider.overrideWith(
            (ref, id) async => [
              player(
                'Alexandre Benali au nom très long',
                Team.a,
                1,
                sessionId: 's-long',
              ),
              player(
                'Souleymane Diallo au nom très long',
                Team.a,
                2,
                sessionId: 's-long',
              ),
              player(
                'Maximilien Koulibaly au nom très long',
                Team.b,
                4,
                sessionId: 's-long',
              ),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.5),
              ),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: HomeSessionResult(session: s),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Olympique de la Plaine'), findsOneWidget);
      expect(find.text('Olympique Saint-Roch'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      expect(find.text('x4'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'BUT-09 loading does not claim no goals and empty session hides empty text',
    (tester) async {
      final pending = Completer<List<SessionParticipantDetail>>();
      await mount(tester, game, (_) => pending.future);
      expect(find.text('Chargement des buteurs…'), findsOneWidget);
      expect(find.text('Aucun but enregistré'), findsNothing);
      pending.complete([]);
      await tester.pumpAndSettle();
      expect(find.text('Aucun but enregistré'), findsNothing);
    },
  );

  testWidgets(
    'BUT-10 failure preserves score and indicates unavailable scorers',
    (tester) async {
      await mount(
        tester,
        game,
        (_) async => throw StateError('unavailable'),
      );
      expect(find.text('Buteurs indisponibles'), findsOneWidget);
      expect(find.text('Racing Atlas'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('Aucun but enregistré'), findsNothing);
    },
  );

  testWidgets('BUT-11/12 updates scorers (1 -> 2 -> 3 balls) and discards previous session', (
    tester,
  ) async {
    var current = game();
    var goals = 1;
    final container = await mount(
      tester,
      () => current,
      (id) async => [
        player(id == 's' ? 'Karim' : 'Samir', Team.a, goals, sessionId: id),
      ],
    );
    expect(
      find.descendant(
        of: scorerRow(Team.a, 'Karim'),
        matching: find.byIcon(Remix.football_fill),
      ),
      findsOneWidget,
    );
    expect(find.text('1 but'), findsNothing);

    goals = 2;
    container.invalidate(sessionParticipantsProvider('s'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: scorerRow(Team.a, 'Karim'),
        matching: find.byIcon(Remix.football_fill),
      ),
      findsNWidgets(2),
    );
    expect(find.text('2 buts'), findsNothing);
    expect(find.text('x2'), findsNothing);

    goals = 3;
    container.invalidate(sessionParticipantsProvider('s'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: scorerRow(Team.a, 'Karim'),
        matching: find.byIcon(Remix.football_fill),
      ),
      findsOneWidget,
    );
    expect(inside(Team.a, 'x3'), findsOneWidget);
    expect(find.text('3 buts'), findsNothing);

    current = game(id: 'next');
    container.invalidate(allSessionsProvider);
    await tester.pumpAndSettle();
    expect(find.text('Samir'), findsOneWidget);
    expect(find.text('Karim'), findsNothing);
  });
}
