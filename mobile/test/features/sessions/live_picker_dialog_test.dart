import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:remixicon/remixicon.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/core/widgets/initial_avatar.dart';
import 'package:statoo/core/widgets/soccer_shoe_icon.dart';
import 'package:statoo/features/sessions/application/sessions_provider.dart';
import 'package:statoo/features/sessions/domain/participation.dart';
import 'package:statoo/features/sessions/domain/session.dart';
import 'package:statoo/features/sessions/domain/session_summary.dart';
import 'package:statoo/features/sessions/presentation/live_stats_panel.dart';

Widget _buildTestWidget({
  required Session session,
  required List<SessionParticipantDetail> players,
  ThemeData? theme,
  double textScale = 1.0,
}) {
  return ProviderScope(
    overrides: [
      liveJournalProvider(session.id).overrideWith((ref) async => []),
    ],
    child: MaterialApp(
      theme: theme ?? AppTheme.darkTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: LiveStatsPanel(
            session: session,
            players: players,
            editable: true,
          ),
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
    id: 'session-1',
    playedAt: DateTime(2026, 10, 30, 14),
    teamNames: const {'A': 'Les Aigles', 'B': 'Les Tigres'},
  );

  final testPlayers = [
    const SessionParticipantDetail(
      participation: Participation(
        id: 'part-1',
        sessionId: 'session-1',
        playerId: 'player-1',
        team: Team.a,
      ),
      playerName: 'Karim',
    ),
    const SessionParticipantDetail(
      participation: Participation(
        id: 'part-2',
        sessionId: 'session-1',
        playerId: 'player-2',
        team: Team.a,
      ),
      playerName: 'Youssef',
    ),
  ];

  group('LivePicker Modal Style & Design System Tests', () {
    testWidgets(
      'Scorer modal displays football icon, team badge, player InitialAvatars, and question icon for unknown scorer',
      (tester) async {
        await tester.pumpWidget(
          _buildTestWidget(
            session: testSession,
            players: testPlayers,
          ),
        );
        await tester.pumpAndSettle();

        // Open goal modal
        await tester.tap(find.byTooltip('Ajouter un but'));
        await tester.pumpAndSettle();

        final dialog = find.byType(AlertDialog);
        expect(dialog, findsOneWidget);

        // Header must contain football icon
        expect(
          find.descendant(of: dialog, matching: find.byIcon(Remix.football_line)),
          findsWidgets,
        );

        // Header must display styled team badge with team name
        expect(
          find.descendant(of: dialog, matching: find.text('Les Aigles')),
          findsOneWidget,
        );

        // Players must display an InitialAvatar
        final avatars = find.descendant(of: dialog, matching: find.byType(InitialAvatar));
        expect(avatars, findsNWidgets(2));
        expect(find.descendant(of: dialog, matching: find.text('K')), findsOneWidget);
        expect(find.descendant(of: dialog, matching: find.text('Y')), findsOneWidget);

        // "Buteur non renseigné" must display a dedicated question icon
        expect(
          find.descendant(of: dialog, matching: find.text('Buteur non renseigné')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: dialog, matching: find.byIcon(Remix.question_line)),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Assist modal displays SoccerShoeIcon, assist prompt, "Aucun passeur" with icon, and back button with arrow icon',
      (tester) async {
        await tester.pumpWidget(
          _buildTestWidget(
            session: testSession,
            players: testPlayers,
          ),
        );
        await tester.pumpAndSettle();

        // Open goal modal
        await tester.tap(find.byTooltip('Ajouter un but'));
        await tester.pumpAndSettle();

        // Select Karim as scorer
        await tester.tap(find.widgetWithText(TextButton, 'Karim'));
        await tester.pumpAndSettle();

        final dialog = find.byType(AlertDialog);
        expect(find.text('But de Karim'), findsOneWidget);
        expect(find.text('Qui lui a fait la passe ?'), findsOneWidget);

        // Assist header must contain SoccerShoeIcon
        expect(
          find.descendant(of: dialog, matching: find.byType(SoccerShoeIcon)),
          findsOneWidget,
        );

        // "Aucun passeur" must have close_circle_line icon
        expect(
          find.descendant(of: dialog, matching: find.text('Aucun passeur')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: dialog, matching: find.byIcon(Remix.close_circle_line)),
          findsOneWidget,
        );

        // Eligible assist players (Youssef) must display InitialAvatar
        expect(
          find.descendant(of: dialog, matching: find.byType(InitialAvatar)),
          findsOneWidget,
        );
        expect(find.descendant(of: dialog, matching: find.text('Y')), findsOneWidget);

        // "Retour au buteur" must have arrow_left_line icon
        expect(
          find.descendant(of: dialog, matching: find.text('Retour au buteur')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: dialog, matching: find.byIcon(Remix.arrow_left_line)),
          findsOneWidget,
        );

        // Tapping back returns to scorer step
        await tester.tap(find.text('Retour au buteur'));
        await tester.pumpAndSettle();
        expect(find.text('Qui a marqué ?'), findsOneWidget);
      },
    );

    testWidgets(
      'Card modal displays rectangle card icon, team badge, and player InitialAvatars',
      (tester) async {
        await tester.pumpWidget(
          _buildTestWidget(
            session: testSession,
            players: testPlayers,
          ),
        );
        await tester.pumpAndSettle();

        // Open yellow card modal
        await tester.tap(find.byTooltip('Carton jaune'));
        await tester.pumpAndSettle();

        final dialog = find.byType(AlertDialog);
        expect(find.text('Quel joueur reçoit le carton ?'), findsOneWidget);
        expect(
          find.descendant(of: dialog, matching: find.byType(InitialAvatar)),
          findsNWidgets(2),
        );
      },
    );

    for (final width in [320.0, 393.0]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        for (final dark in [false, true]) {
          testWidgets(
            'Dialog responsive $width dp / scale $scale / dark=$dark without overflow',
            (tester) async {
              tester.view.physicalSize = Size(width, 852);
              tester.view.devicePixelRatio = 1;
              addTearDown(tester.view.resetPhysicalSize);
              addTearDown(tester.view.resetDevicePixelRatio);

              await tester.pumpWidget(
                _buildTestWidget(
                  session: testSession,
                  players: testPlayers,
                  theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
                  textScale: scale,
                ),
              );
              await tester.pumpAndSettle();

              await tester.tap(find.byTooltip('Ajouter un but'));
              await tester.pumpAndSettle();

              expect(
                tester.takeException(),
                isNull,
                reason: 'No overflow at $width dp / scale $scale (scorer step)',
              );

              await tester.tap(find.widgetWithText(TextButton, 'Karim'));
              await tester.pumpAndSettle();

              expect(
                tester.takeException(),
                isNull,
                reason: 'No overflow at $width dp / scale $scale (assist step)',
              );
            },
          );
        }
      }
    }
  });
}
