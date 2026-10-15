import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/features/home/presentation/home_screen.dart';
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
            player('Amine', Team.b, 2),
            player('Samir', Team.c, 4),
          ],
        );
        expect(inside(Team.a, 'Karim'), findsOneWidget);
        expect(inside(Team.a, '3 buts'), findsOneWidget);
        expect(inside(Team.b, 'Amine'), findsOneWidget);
        if (tournament) {
          expect(inside(Team.c, 'Samir'), findsOneWidget);
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
          expect(inside(Team.a, '5'), findsOneWidget);
          expect(inside(Team.b, '2'), findsOneWidget);
        }
        if (active)
          expect(find.text('Reprendre le match en direct'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'BUT-04/05/06/07 session isolation, sorting, empty and unassigned',
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
      expect(inside(Team.b, 'Aucun but enregistré'), findsOneWidget);
      expect(inside(Team.c, 'Non attribués'), findsOneWidget);
      expect(inside(Team.c, '2 buts'), findsOneWidget);
      expect(inside(Team.c, 'Aucun but enregistré'), findsNothing);
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

  testWidgets('BUT-09 loading does not claim no goals', (tester) async {
    final pending = Completer<List<SessionParticipantDetail>>();
    await mount(tester, () => game(), (_) => pending.future);
    expect(find.text('Chargement des buteurs…'), findsOneWidget);
    expect(find.text('Aucun but enregistré'), findsNothing);
    pending.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('Aucun but enregistré'), findsNWidgets(2));
  });

  testWidgets(
    'BUT-10 failure preserves score and indicates unavailable scorers',
    (tester) async {
      await mount(
        tester,
        () => game(),
        (_) async => throw StateError('unavailable'),
      );
      expect(find.text('Buteurs indisponibles'), findsOneWidget);
      expect(find.text('Racing Atlas'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('Aucun but enregistré'), findsNothing);
    },
  );

  testWidgets('BUT-11/12 updates scorers and discards previous session', (
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
    expect(find.text('1 but'), findsOneWidget);
    goals = 3;
    container.invalidate(sessionParticipantsProvider('s'));
    await tester.pumpAndSettle();
    expect(find.text('3 buts'), findsOneWidget);
    current = game(id: 'next');
    container.invalidate(allSessionsProvider);
    await tester.pumpAndSettle();
    expect(find.text('Samir'), findsOneWidget);
    expect(find.text('Karim'), findsNothing);
  });
}
