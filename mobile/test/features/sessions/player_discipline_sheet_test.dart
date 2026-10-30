import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/features/sessions/domain/participation.dart';
import 'package:statoo/features/sessions/presentation/player_discipline_sheet.dart';

Widget _buildHarness({
  required String playerName,
  required String playerId,
  required Team team,
  int yellowCards = 0,
  int redCards = 0,
  ThemeData? theme,
  double textScale = 1.0,
  void Function(Map<String, dynamic>?)? onResult,
}) {
  return MaterialApp(
    theme: theme ?? AppTheme.darkTheme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: child!,
    ),
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () async {
              final res = await showModalBottomSheet<Map<String, dynamic>>(
                context: context,
                builder: (_) => PlayerDisciplineSheet(
                  playerName: playerName,
                  playerId: playerId,
                  team: team,
                  yellowCards: yellowCards,
                  redCards: redCards,
                ),
              );
              onResult?.call(res);
            },
            child: const Text('Open Sheet'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('PlayerDisciplineSheet Presentation Tests', () {
    testWidgets('PDS-01: Rendu nominal sans carton avec titre et 2 boutons >= 48dp', (tester) async {
      await tester.pumpWidget(
        _buildHarness(
          playerName: 'Karim',
          playerId: 'p1',
          team: Team.a,
        ),
      );
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Titre
      expect(find.text('Discipline · Karim'), findsOneWidget);

      // Boutons d'ajout
      final yellowBtn = find.text('Carton jaune');
      final redBtn = find.text('Carton rouge');

      expect(yellowBtn, findsOneWidget);
      expect(redBtn, findsOneWidget);

      // Cibles tactiles >= 48dp
      final yellowSize = tester.getSize(find.widgetWithText(OutlinedButton, 'Carton jaune'));
      final redSize = tester.getSize(find.widgetWithText(OutlinedButton, 'Carton rouge'));
      expect(yellowSize.height, greaterThanOrEqualTo(48.0));
      expect(redSize.height, greaterThanOrEqualTo(48.0));

      // Aucun bouton de retrait
      expect(find.textContaining('Retirer'), findsNothing);
    });

    testWidgets('PDS-02: Clic sur Carton jaune retourne delta 1', (tester) async {
      Map<String, dynamic>? result;
      await tester.pumpWidget(
        _buildHarness(
          playerName: 'Karim',
          playerId: 'p1',
          team: Team.a,
          onResult: (r) => result = r,
        ),
      );
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Carton jaune'));
      await tester.pumpAndSettle();

      expect(result, {
        'type': 'yellow',
        'team': 'A',
        'player': 'p1',
        'delta': 1,
      });
    });

    testWidgets('PDS-03: Clic sur Carton rouge retourne delta 1', (tester) async {
      Map<String, dynamic>? result;
      await tester.pumpWidget(
        _buildHarness(
          playerName: 'Karim',
          playerId: 'p1',
          team: Team.a,
          onResult: (r) => result = r,
        ),
      );
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Carton rouge'));
      await tester.pumpAndSettle();

      expect(result, {
        'type': 'red',
        'team': 'A',
        'player': 'p1',
        'delta': 1,
      });
    });

    testWidgets('PDS-04: yellowCards > 0 affiche bouton retrait jaune (-1) et clic retourne delta -1', (tester) async {
      Map<String, dynamic>? result;
      await tester.pumpWidget(
        _buildHarness(
          playerName: 'Karim',
          playerId: 'p1',
          team: Team.a,
          yellowCards: 1,
          onResult: (r) => result = r,
        ),
      );
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      final removeYellowBtn = find.text('Retirer le carton jaune (-1)');
      expect(removeYellowBtn, findsOneWidget);
      expect(find.text('Retirer le carton rouge (-1)'), findsNothing);

      await tester.tap(removeYellowBtn);
      await tester.pumpAndSettle();

      expect(result, {
        'type': 'yellow',
        'team': 'A',
        'player': 'p1',
        'delta': -1,
      });
    });

    testWidgets('PDS-05: redCards > 0 affiche bouton retrait rouge (-1) et clic retourne delta -1', (tester) async {
      Map<String, dynamic>? result;
      await tester.pumpWidget(
        _buildHarness(
          playerName: 'Karim',
          playerId: 'p1',
          team: Team.a,
          redCards: 1,
          onResult: (r) => result = r,
        ),
      );
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      final removeRedBtn = find.text('Retirer le carton rouge (-1)');
      expect(removeRedBtn, findsOneWidget);
      expect(find.text('Retirer le carton jaune (-1)'), findsNothing);

      await tester.tap(removeRedBtn);
      await tester.pumpAndSettle();

      expect(result, {
        'type': 'red',
        'team': 'A',
        'player': 'p1',
        'delta': -1,
      });
    });

    testWidgets('PDS-06: 1 jaune et 1 rouge affichent les 2 boutons de retrait', (tester) async {
      await tester.pumpWidget(
        _buildHarness(
          playerName: 'Karim',
          playerId: 'p1',
          team: Team.a,
          yellowCards: 1,
          redCards: 1,
        ),
      );
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Retirer le carton jaune (-1)'), findsOneWidget);
      expect(find.text('Retirer le carton rouge (-1)'), findsOneWidget);
    });

    for (final width in [320.0, 393.0]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        for (final dark in [false, true]) {
          testWidgets('PDS-07: Responsive $width dp / scale $scale / dark=$dark sans overflow', (tester) async {
            tester.view.physicalSize = Size(width, 852);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);

            await tester.pumpWidget(
              _buildHarness(
                playerName: 'Karim',
                playerId: 'p1',
                team: Team.a,
                yellowCards: 1,
                redCards: 1,
                theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
                textScale: scale,
              ),
            );
            await tester.tap(find.text('Open Sheet'));
            await tester.pumpAndSettle();

            expect(
              tester.takeException(),
              isNull,
              reason: 'Aucun overflow RenderFlex à $width dp avec scale $scale',
            );
          });
        }
      }
    }
  });
}
