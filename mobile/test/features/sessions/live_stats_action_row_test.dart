import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:remixicon/remixicon.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/features/sessions/application/sessions_provider.dart';
import 'package:statoo/features/sessions/domain/participation.dart';
import 'package:statoo/features/sessions/domain/session.dart';
import 'package:statoo/features/sessions/domain/session_summary.dart';
import 'package:statoo/features/sessions/presentation/live_stats_panel.dart';

Widget _buildTestWidget({
  required Session session,
  required List<SessionParticipantDetail> players,
  bool editable = true,
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
            editable: editable,
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
    id: 'test-session-1',
    playedAt: DateTime(2026, 10, 30),
    teamNames: const {'A': 'Équipe A', 'B': 'Équipe B'},
    scoreA: 0,
    scoreB: 0,
  );

  final testPlayers = [
    const SessionParticipantDetail(
      participation: Participation(
        id: 'p1',
        sessionId: 'test-session-1',
        playerId: 'player1',
        team: Team.a,
      ),
      playerName: 'Karim',
    ),
    const SessionParticipantDetail(
      participation: Participation(
        id: 'p2',
        sessionId: 'test-session-1',
        playerId: 'player2',
        team: Team.a,
      ),
      playerName: 'Youssef',
    ),
  ];

  group('LiveStatsPanel - Evolution Action Row & Suppression doublon', () {
    testWidgets(
      "RED-01: Nom de l'équipe active sous les onglets est supprimé (aucun doublon)",
      (tester) async {
        await tester.pumpWidget(
          _buildTestWidget(
            session: testSession,
            players: testPlayers,
          ),
        );
        await tester.pumpAndSettle();

        // Le texte "Équipe A" ne doit apparaître qu'UNE SEULE FOIS (dans l'onglet de sélection)
        // et non pas une seconde fois en titre intermédiaire sous les onglets.
        final teamANodes = find.text('Équipe A');
        expect(
          teamANodes,
          findsOneWidget,
          reason:
              "Le nom de l'équipe ne doit plus être doublonné sous les onglets.",
        );
      },
    );

    testWidgets(
      'RED-02: Boutons compacts avec icônes et plus pour but, carton jaune et carton rouge',
      (tester) async {
        await tester.pumpWidget(
          _buildTestWidget(
            session: testSession,
            players: testPlayers,
          ),
        );
        await tester.pumpAndSettle();

        // 1. Le gros bouton avec le texte 'Ajouter un but' ne doit plus exister
        expect(
          find.widgetWithText(FilledButton, 'Ajouter un but'),
          findsNothing,
          reason: 'Le gros bouton textuel "Ajouter un but" doit être remplacé.',
        );

        // 2. Bouton But compact : football_line + add_line avec tooltip/semantics "Ajouter un but"
        final goalButton = find.byTooltip('Ajouter un but');
        expect(goalButton, findsOneWidget);
        expect(
          find.descendant(of: goalButton, matching: find.byIcon(Remix.football_line)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: goalButton, matching: find.byIcon(Remix.add_line)),
          findsOneWidget,
        );

        // 3. Bouton Carton Jaune compact : rectangle_fill + add_line avec tooltip/semantics "Carton jaune"
        final yellowButton = find.byTooltip('Carton jaune');
        expect(yellowButton, findsOneWidget);
        expect(
          find.descendant(of: yellowButton, matching: find.byIcon(Remix.rectangle_fill)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: yellowButton, matching: find.byIcon(Remix.add_line)),
          findsOneWidget,
        );

        // 4. Bouton Carton Rouge compact : rectangle_fill + add_line avec tooltip/semantics "Carton rouge"
        final redButton = find.byTooltip('Carton rouge');
        expect(redButton, findsOneWidget);
        expect(
          find.descendant(of: redButton, matching: find.byIcon(Remix.rectangle_fill)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: redButton, matching: find.byIcon(Remix.add_line)),
          findsOneWidget,
        );

        // 5. Cibles tactiles >= 48x48
        final goalSize = tester.getSize(goalButton);
        final yellowSize = tester.getSize(yellowButton);
        final redSize = tester.getSize(redButton);
        expect(goalSize.width, greaterThanOrEqualTo(48.0));
        expect(goalSize.height, greaterThanOrEqualTo(48.0));
        expect(yellowSize.width, greaterThanOrEqualTo(48.0));
        expect(yellowSize.height, greaterThanOrEqualTo(48.0));
        expect(redSize.width, greaterThanOrEqualTo(48.0));
        expect(redSize.height, greaterThanOrEqualTo(48.0));
      },
    );

    testWidgets(
      'RED-03: Alignement des 3 actions sur une seule ligne (Row) avec Annuler en dessous',
      (tester) async {
        await tester.pumpWidget(
          _buildTestWidget(
            session: testSession,
            players: testPlayers,
          ),
        );
        await tester.pumpAndSettle();

        final goalButton = find.byTooltip('Ajouter un but');
        final yellowButton = find.byTooltip('Carton jaune');
        final redButton = find.byTooltip('Carton rouge');

        expect(goalButton, findsOneWidget);
        expect(yellowButton, findsOneWidget);
        expect(redButton, findsOneWidget);

        // Vérification de l'alignement horizontal (même centre vertical Y)
        final goalCenter = tester.getCenter(goalButton);
        final yellowCenter = tester.getCenter(yellowButton);
        final redCenter = tester.getCenter(redButton);

        expect(
          (goalCenter.dy - yellowCenter.dy).abs(),
          lessThan(2.0),
          reason: 'Le bouton but et carton jaune doivent être alignés sur la même ligne.',
        );
        expect(
          (yellowCenter.dy - redCenter.dy).abs(),
          lessThan(2.0),
          reason: 'Le bouton carton jaune et carton rouge doivent être alignés sur la même ligne.',
        );

        // Bouton "Annuler la dernière action" positionné sous la rangée
        final undoButton = find.widgetWithText(OutlinedButton, 'Annuler la dernière action');
        expect(undoButton, findsOneWidget);
        final undoTop = tester.getTopLeft(undoButton).dy;
        final goalBottom = tester.getBottomRight(goalButton).dy;
        expect(
          undoTop,
          greaterThan(goalBottom),
          reason: 'Le bouton Annuler doit être positionné sous la rangée des 3 actions.',
        );
      },
    );

    testWidgets(
      'RED-04: Clic sur le bouton But ouvre le dialogue "Qui a marqué ?"',
      (tester) async {
        await tester.pumpWidget(
          _buildTestWidget(
            session: testSession,
            players: testPlayers,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Ajouter un but'));
        await tester.pumpAndSettle();

        expect(find.text('Qui a marqué ?'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Karim'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Youssef'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'RED-05: Clic sur Carton jaune ouvre le dialogue de sélection de joueur',
      (tester) async {
        await tester.pumpWidget(
          _buildTestWidget(
            session: testSession,
            players: testPlayers,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Carton jaune'));
        await tester.pumpAndSettle();

        expect(find.text('Quel joueur reçoit le carton ?'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Karim'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'RED-06: Clic sur Carton rouge ouvre le dialogue de sélection de joueur',
      (tester) async {
        await tester.pumpWidget(
          _buildTestWidget(
            session: testSession,
            players: testPlayers,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Carton rouge'));
        await tester.pumpAndSettle();

        expect(find.text('Quel joueur reçoit le carton ?'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Karim'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      "RED-07: Quand editable est faux, aucun bouton d'action n'est affiché",
      (tester) async {
        await tester.pumpWidget(
          _buildTestWidget(
            session: testSession,
            players: testPlayers,
            editable: false,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byTooltip('Ajouter un but'), findsNothing);
        expect(find.byTooltip('Carton jaune'), findsNothing);
        expect(find.byTooltip('Carton rouge'), findsNothing);
        expect(find.widgetWithText(OutlinedButton, 'Annuler la dernière action'), findsNothing);
      },
    );

    for (final width in [320.0, 393.0]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        for (final dark in [false, true]) {
          testWidgets(
            'RED-08: Responsive & Theme $width dp / scale $scale / dark=$dark sans overflow',
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

              expect(
                tester.takeException(),
                isNull,
                reason: 'Aucun RenderFlex overflow à $width dp avec scale $scale',
              );
            },
          );
        }
      }
    }
  });
}
