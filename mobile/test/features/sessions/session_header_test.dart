import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remixicon/remixicon.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/features/sessions/domain/participation.dart';
import 'package:statoo/features/sessions/domain/session.dart';
import 'package:statoo/features/sessions/domain/session_summary.dart';
import 'package:statoo/features/sessions/presentation/session_header.dart';

void main() {
  final session = Session(
    id: 'current',
    playedAt: DateTime(2026, 10, 12),
    status: SessionStatus.closed,
    scoreA: 3,
    scoreB: 1,
  );
  SessionParticipantDetail player(
    String name,
    Team team,
    int goals, {
    String sessionId = 'current',
  }) {
    return SessionParticipantDetail(
      participation: Participation(
        id: name,
        sessionId: sessionId,
        playerId: name,
        team: team,
        goals: goals,
      ),
      playerName: name,
    );
  }

  Widget header({
    Session? value,
    List<SessionParticipantDetail> players = const [],
    bool active = false,
    double textScale = 1,
    void Function(Team, int)? onScore,
  }) {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: SessionHeader(
            session: value ?? session,
            participants: players,
            formattedDate: '12 oct. 2026 · 20h30',
            formatLabel: '5v5',
            isCurrentActive: active,
            onScoreIncrement: onScore ?? (_, _) {},
          ),
        ),
      ),
    );
  }

  testWidgets(
    'only this session scorers are listed under their own team with goal counts',
    (tester) async {
      await tester.pumpWidget(
        header(
          players: [
            player('Karim', Team.a, 2),
            player('Lucas', Team.a, 1),
            player('Yassine', Team.b, 1),
            player('Sans but', Team.b, 0),
            player('Autre séance', Team.a, 99, sessionId: 'other'),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final a = find.byKey(const ValueKey('session-scorers-a'));
      final b = find.byKey(const ValueKey('session-scorers-b'));
      expect(
        find.descendant(of: a, matching: find.text('Karim')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: a, matching: find.byIcon(Remix.football_fill)),
        findsNWidgets(2),
      );
      expect(
        find.descendant(of: b, matching: find.text('Yassine')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: b, matching: find.byIcon(Remix.football_fill)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: b, matching: find.text('Karim')),
        findsNothing,
      );
      expect(find.text('Sans but'), findsNothing);
      expect(find.text('Autre séance'), findsNothing);
      expect(find.text('3 - 1'), findsOneWidget);
      expect(find.text('Terminée'), findsOneWidget);
      final karimRow = find.byKey(const ValueKey('session-scorer-a-Karim'));
      final yassineRow = find.byKey(const ValueKey('session-scorer-b-Yassine'));
      final karimBalls = find.descendant(
        of: karimRow,
        matching: find.byIcon(Remix.football_fill),
      );
      final yassineBalls = find.descendant(
        of: yassineRow,
        matching: find.byIcon(Remix.football_fill),
      );
      expect(karimBalls, findsOneWidget);
      expect(find.text('x2'), findsOneWidget);
      expect(
        tester.getCenter(find.text('Karim')).dx,
        lessThan(tester.getCenter(karimBalls.first).dx),
      );
      expect(
        tester.getCenter(find.text('Yassine')).dx,
        greaterThan(tester.getCenter(yassineBalls.first).dx),
      );
      expect(find.text('2 buts'), findsNothing);
    },
  );

  testWidgets('empty camps are blank and unassigned goals retain a count', (
    tester,
  ) async {
    await tester.pumpWidget(
      header(value: session.copyWith(unassignedGoalsA: 2)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Non attribués'), findsOneWidget);
    expect(find.byIcon(Remix.football_fill), findsOneWidget);
    expect(find.text('x2'), findsOneWidget);
    expect(find.text('Aucun buteur'), findsNothing);
  });

  testWidgets('long scorer names fit at 320px with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
        child: header(
          textScale: 1.5,
          players: [
            player('Alexandre Benali avec un nom très long', Team.a, 12),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Remix.football_fill), findsOneWidget);
    expect(find.text('x12'), findsOneWidget);
  });

  testWidgets(
    'tournament includes team C scorers without inventing a match score',
    (tester) async {
      await tester.pumpWidget(
        header(
          value: session.copyWith(
            sessionType: SessionType.tournament3,
            scoreA: null,
            scoreB: null,
          ),
          players: [player('Sofiane', Team.c, 3)],
        ),
      );
      await tester.pumpAndSettle();
      final c = find.byKey(const ValueKey('session-scorers-c'));
      expect(
        find.descendant(of: c, matching: find.text('Sofiane')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: c, matching: find.byIcon(Remix.football_fill)),
        findsOneWidget,
      );
      expect(find.text('0 - 0'), findsNothing);
    },
  );

  testWidgets('live score buttons keep the team and delta', (tester) async {
    Team? selected;
    int? change;
    await tester.pumpWidget(
      header(
        active: true,
        value: session.copyWith(status: SessionStatus.draft),
        onScore: (team, delta) {
          selected = team;
          change = delta;
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Augmenter le score de Équipe B'));
    expect(selected, Team.b);
    expect(change, 1);
  });
}
