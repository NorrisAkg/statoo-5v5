import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';

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
      liveJournalProvider(session.id).overrideWith((ref) async => [
        {'id': 'dummy', 'action': {'type': 'goal', 'team': 'A', 'player': 'player1'}},
      ]),
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
      'RED-02: Barre supérieure épurée : [Ajouter un but] et [Annuler], aucun carton en haut',
      (tester) async {
        await tester.pumpWidget(
          _buildTestWidget(
            session: testSession,
            players: testPlayers,
          ),
        );
        await tester.pumpAndSettle();

        // 1. Bouton But présent avec libellé et icônes
        final goalButton = find.byTooltip('Ajouter un but');
        expect(goalButton, findsOneWidget);
        expect(find.text('Ajouter un but'), findsOneWidget);

        // 2. Bouton Annuler présent
        final undoButton = find.widgetWithText(OutlinedButton, 'Annuler la dernière action');
        expect(undoButton, findsOneWidget);

        // 3. Aucun bouton carton d'équipe dans la barre supérieure
        expect(find.byTooltip('Carton jaune'), findsNothing);
        expect(find.byTooltip('Carton rouge'), findsNothing);

        // 4. Cibles tactiles >= 48dp
        final goalSize = tester.getSize(goalButton);
        final undoSize = tester.getSize(undoButton);
        expect(goalSize.height, greaterThanOrEqualTo(48.0));
        expect(undoSize.height, greaterThanOrEqualTo(48.0));
      },
    );

    testWidgets(
      'RED-03: Alignement des 2 actions sur une seule ligne (Row)',
      (tester) async {
        await tester.pumpWidget(
          _buildTestWidget(
            session: testSession,
            players: testPlayers,
          ),
        );
        await tester.pumpAndSettle();

        final goalButton = find.byTooltip('Ajouter un but');
        final undoButton = find.widgetWithText(OutlinedButton, 'Annuler la dernière action');

        expect(goalButton, findsOneWidget);
        expect(undoButton, findsOneWidget);

        // Vérification de l'alignement horizontal (même centre vertical Y)
        final goalCenter = tester.getCenter(goalButton);
        final undoCenter = tester.getCenter(undoButton);

        expect(
          (goalCenter.dy - undoCenter.dy).abs(),
          lessThan(2.0),
          reason: 'Le bouton but et le bouton annuler doivent être alignés sur la même ligne.',
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
        expect(find.text('Annuler la dernière action'), findsNothing);
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
                reason:
                    'Aucun overflow RenderFlex ne doit survenir à $width dp avec scale $scale (dark=$dark).',
              );
            },
          );
        }
      }
    }
  });
}
