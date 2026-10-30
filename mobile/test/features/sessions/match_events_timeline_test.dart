import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:remixicon/remixicon.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/features/sessions/domain/participation.dart';
import 'package:statoo/features/sessions/domain/session.dart';
import 'package:statoo/features/sessions/domain/session_summary.dart';
import 'package:statoo/features/sessions/presentation/match_events_timeline.dart';

Widget _buildTestWidget({
  required Session session,
  required List<SessionParticipantDetail> participants,
  List<Map<String, dynamic>> journal = const [],
  ThemeData? theme,
  double textScale = 1.0,
  double width = 393.0,
}) {
  return MaterialApp(
    theme: theme ?? AppTheme.darkTheme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
        size: Size(width, 852),
      ),
      child: child!,
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        child: MatchEventsTimeline(
          session: session,
          participants: participants,
          journal: journal,
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('fr_FR');
  });

  final testSession = Session(
    id: 's1',
    playedAt: DateTime(2026, 10, 30, 14),
    scoreA: 2,
    scoreB: 1,
    teamNames: const {'A': 'Frosinone', 'B': 'Lecce'},
  );

  final testParticipants = [
    const SessionParticipantDetail(
      participation: Participation(
        id: 'part_a1',
        sessionId: 's1',
        playerId: 'p_a1',
        team: Team.a,
        goals: 2,
      ),
      playerName: 'M. Cichella',
    ),
    const SessionParticipantDetail(
      participation: Participation(
        id: 'part_a2',
        sessionId: 's1',
        playerId: 'p_a2',
        team: Team.a,
        assists: 1,
      ),
      playerName: 'F. Ghedjemis',
    ),
    const SessionParticipantDetail(
      participation: Participation(
        id: 'part_b1',
        sessionId: 's1',
        playerId: 'p_b1',
        team: Team.b,
        goals: 1,
        yellowCards: 1,
      ),
      playerName: 'Tiago Gabriel',
    ),
  ];

  final testJournal = [
    {
      'id': 'e1',
      'created_at': '2026-10-30T14:10:00Z',
      'action': {
        'type': 'goal',
        'team': 'A',
        'player': 'p_a1',
        'assist': 'p_a2',
      },
    },
    {
      'id': 'e2',
      'created_at': '2026-10-30T14:20:00Z',
      'action': {
        'type': 'yellow',
        'team': 'B',
        'player': 'p_b1',
      },
    },
    {
      'id': 'e3',
      'created_at': '2026-10-30T14:30:00Z',
      'action': {
        'type': 'goal',
        'team': 'B',
        'player': 'p_b1',
      },
    },
    {
      'id': 'e4',
      'created_at': '2026-10-30T14:40:00Z',
      'action': {
        'type': 'goal',
        'team': 'A',
        'player': 'p_a1',
      },
    },
  ];

  group('MatchEventsTimeline', () {
    testWidgets('renders bilateral timeline with Team A on left and Team B on right', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          session: testSession,
          participants: testParticipants,
          journal: testJournal,
        ),
      );
      await tester.pumpAndSettle();

      // Verify team header banner
      expect(find.text('Frosinone'), findsWidgets);
      expect(find.text('Lecce'), findsWidgets);

      // Verify central vertical spine exists
      expect(find.byKey(const ValueKey('timeline-spine')), findsWidgets);

      // Verify scorer names and assists
      expect(find.text('M. Cichella'), findsWidgets);
      expect(find.textContaining('F. Ghedjemis'), findsWidgets);
      expect(find.text('Tiago Gabriel'), findsWidgets);

      // Verify running score calculation
      expect(find.text('(1 - 0)'), findsOneWidget);
      expect(find.text('(1 - 1)'), findsOneWidget);
      expect(find.text('(2 - 1)'), findsOneWidget);

      // Verify NO minute/timestamp indicators are present (as requested: "Nous ne notons pas les moments des faits")
      expect(find.textContaining("'"), findsNothing);
      expect(find.textContaining('min'), findsNothing);

      // Verify football icons and card icons
      expect(find.byIcon(Remix.football_line), findsWidgets);
      expect(find.byIcon(Remix.rectangle_fill), findsWidgets);
    });

    testWidgets('empty state displays friendly message when no events recorded', (tester) async {
      final emptySession = Session(
        id: 's_empty',
        playedAt: DateTime(2026, 10, 30, 14),
        scoreA: 0,
        scoreB: 0,
      );

      await tester.pumpWidget(
        _buildTestWidget(
          session: emptySession,
          participants: const [],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Aucun fait de jeu enregistré pour cette séance.'),
        findsOneWidget,
      );
    });

    for (final width in [320.0, 393.0]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        for (final dark in [false, true]) {
          testWidgets(
            'responsive $width dp / scale $scale / dark=$dark sans overflow',
            (tester) async {
              tester.view.physicalSize = Size(width, 852);
              tester.view.devicePixelRatio = 1;
              addTearDown(tester.view.resetPhysicalSize);
              addTearDown(tester.view.resetDevicePixelRatio);

              await tester.pumpWidget(
                _buildTestWidget(
                  session: testSession,
                  participants: testParticipants,
                  journal: testJournal,
                  theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
                  textScale: scale,
                  width: width,
                ),
              );
              await tester.pumpAndSettle();

              expect(
                tester.takeException(),
                isNull,
                reason: 'No overflow at $width dp / scale $scale / dark=$dark',
              );
            },
          );
        }
      }
    }
  });
}
