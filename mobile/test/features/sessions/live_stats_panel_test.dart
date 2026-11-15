import 'dart:async';

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
import 'package:statoo/features/sessions/presentation/player_discipline_sheet.dart';

final _refProvider = Provider<Ref>((ref) => ref);

class _MockSessionsController extends SessionsController {
  _MockSessionsController(super._ref);
  final List<Map<String, dynamic>?> records = [];
  final List<String?> edits = [];
  final List<String> reverts = [];
  Completer<void>? gate;

  @override
  Future<String?> recordLive(
    String id,
    Map<String, dynamic>? action, {
    String? edit,
  }) async {
    records.add(action);
    edits.add(edit);
    final pending = gate;
    if (pending != null && action != null && action['type'] == 'goal') {
      await pending.future;
    }
    return action == null ? null : 'entry-${records.length}';
  }

  @override
  Future<void> revertLive(String id, String entryId) async {
    final error = revertError;
    if (error != null) throw error;
    reverts.add(entryId);
  }

  Error? revertError;
}

Widget _buildPanelHarness({
  required Session session,
  required List<SessionParticipantDetail> players,
  required _MockSessionsController controller,
  bool editable = true,
}) {
  return ProviderScope(
    overrides: [
      liveJournalProvider(session.id).overrideWith((ref) async => [
        {'id': 'dummy', 'action': {'type': 'goal', 'team': 'A', 'player': 'p1'}},
      ]),
      sessionsControllerProvider.overrideWith((ref) => controller),
    ],
    child: MaterialApp(
      theme: AppTheme.darkTheme,
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
    id: 's1',
    playedAt: DateTime(2026, 10, 30),
    teamNames: const {'A': 'Équipe A', 'B': 'Équipe B'},
    scoreA: 0,
    scoreB: 0,
  );

  final testPlayers = [
    const SessionParticipantDetail(
      participation: Participation(
        id: 'part1',
        sessionId: 's1',
        playerId: 'p1',
        team: Team.a,
      ),
      playerName: 'Karim',
    ),
    const SessionParticipantDetail(
      participation: Participation(
        id: 'part2',
        sessionId: 's1',
        playerId: 'p2',
        team: Team.a,
      ),
      playerName: 'Youssef',
    ),
  ];

  group('LiveStatsPanel Tests (Player Cards & Discipline Evolution)', () {
    testWidgets('PANEL-01: Barre supérieure contient [Ajouter un but] et [Annuler la dernière action] et ne contient PLUS les cartons d’équipe', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = _MockSessionsController(container.read(_refProvider));

      await tester.pumpWidget(
        _buildPanelHarness(
          session: testSession,
          players: testPlayers,
          controller: controller,
        ),
      );
      await tester.pumpAndSettle();

      // Bouton Ajouter un but présent (>= 48 dp)
      final addGoalFinder = find.byTooltip('Ajouter un but');
      expect(addGoalFinder, findsOneWidget);
      final addGoalSize = tester.getSize(addGoalFinder);
      expect(addGoalSize.height, greaterThanOrEqualTo(48.0));

      // Bouton Annuler la dernière action présent (>= 48 dp)
      final undoFinder = find.widgetWithText(OutlinedButton, 'Annuler la dernière action');
      expect(undoFinder, findsOneWidget);
      final undoSize = tester.getSize(undoFinder);
      expect(undoSize.height, greaterThanOrEqualTo(48.0));

      // Plus aucun bouton de carton d'équipe dans la barre supérieure !
      expect(find.byTooltip('Carton jaune'), findsNothing);
      expect(find.byTooltip('Carton rouge'), findsNothing);
    });

    testWidgets('PANEL-02: Taper sur la ligne d’un joueur ouvre PlayerDisciplineSheet', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = _MockSessionsController(container.read(_refProvider));

      await tester.pumpWidget(
        _buildPanelHarness(
          session: testSession,
          players: testPlayers,
          controller: controller,
        ),
      );
      await tester.pumpAndSettle();

      // Taper sur la ligne du joueur Karim
      await tester.tap(find.text('Karim'));
      await tester.pumpAndSettle();

      // Vérifie l'ouverture de la PlayerDisciplineSheet
      expect(find.byType(PlayerDisciplineSheet), findsOneWidget);
      expect(find.text('Discipline · Karim'), findsOneWidget);
    });

    testWidgets('PANEL-03: Appliquer une sanction affiche un SnackBar avec [Annuler] qui appelle l’undo', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = _MockSessionsController(container.read(_refProvider));

      await tester.pumpWidget(
        _buildPanelHarness(
          session: testSession,
          players: testPlayers,
          controller: controller,
        ),
      );
      await tester.pumpAndSettle();

      // Ouvrir la sheet de Karim
      await tester.tap(find.text('Karim'));
      await tester.pumpAndSettle();

      // Cliquer sur Carton jaune
      await tester.tap(find.text('Carton jaune'));
      await tester.pumpAndSettle();

      // Le contrôleur a bien reçu l'action
      expect(controller.records, isNotEmpty);
      expect(controller.records.last?['type'], 'yellow');

      // Un SnackBar avec un bouton Annuler apparaît
      final undoAction = find.descendant(
        of: find.byType(SnackBar),
        matching: find.text('Annuler'),
      );
      expect(undoAction, findsOneWidget);

      // Cliquer sur Annuler
      await tester.tap(undoAction);
      await tester.pumpAndSettle();

      // UX-001 : le carton lui-même est annulé (entrée ciblée), pas la dernière action.
      expect(controller.reverts, ['entry-1']);
      expect(controller.records.where((r) => r == null), isEmpty);
    });

    testWidgets('UX001-12: carton, puis but, puis [Annuler] du SnackBar annule le carton et pas le but', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = _MockSessionsController(container.read(_refProvider));
      await tester.pumpWidget(
        _buildPanelHarness(
          session: testSession,
          players: testPlayers,
          controller: controller,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Karim'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Carton jaune'));
      await tester.pumpAndSettle();

      // But de Youssef pendant que le SnackBar du carton est encore visible.
      await tester.tap(find.byTooltip('Ajouter un but pour Youssef'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aucun passeur'));
      await tester.pumpAndSettle();
      expect(controller.records.last?['type'], 'goal');

      final undoAction = find.descendant(
        of: find.byType(SnackBar),
        matching: find.text('Annuler'),
      );
      expect(undoAction, findsOneWidget);
      await tester.tap(undoAction);
      await tester.pumpAndSettle();

      expect(controller.reverts, ['entry-1']);
      expect(controller.records.where((r) => r == null), isEmpty);
    });

    testWidgets('UX001-13: [Annuler] du SnackBar fonctionne après avoir quitté le direct', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = _MockSessionsController(container.read(_refProvider));
      final showPanel = ValueNotifier(true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            liveJournalProvider(testSession.id).overrideWith((ref) async => []),
            sessionsControllerProvider.overrideWith((ref) => controller),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: ValueListenableBuilder<bool>(
                valueListenable: showPanel,
                builder: (context, visible, _) => visible
                    ? SingleChildScrollView(
                        child: LiveStatsPanel(
                          session: testSession,
                          players: testPlayers,
                          editable: true,
                        ),
                      )
                    : const Text('Ailleurs'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Karim'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Carton jaune'));
      await tester.pumpAndSettle();

      showPanel.value = false;
      await tester.pumpAndSettle();
      expect(find.byType(LiveStatsPanel), findsNothing);

      await tester.tap(
        find.descendant(of: find.byType(SnackBar), matching: find.text('Annuler')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(controller.reverts, ['entry-1']);
      expect(find.text('Carton annulé'), findsOneWidget);
    });

    testWidgets('UX001-14: [Annuler] pendant l’enregistrement d’un but annule quand même le carton', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = _MockSessionsController(container.read(_refProvider));
      await tester.pumpWidget(
        _buildPanelHarness(
          session: testSession,
          players: testPlayers,
          controller: controller,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Karim'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Carton jaune'));
      await tester.pumpAndSettle();

      controller.gate = Completer<void>();
      await tester.tap(find.byTooltip('Ajouter un but pour Youssef'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aucun passeur'));
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      await tester.tap(
        find.descendant(of: find.byType(SnackBar), matching: find.text('Annuler')),
      );
      await tester.pump();
      controller.gate!.complete();
      await tester.pumpAndSettle();
      expect(controller.reverts, ['entry-1']);
    });

    testWidgets('UX001-15: échec de l’annulation affiché à l’utilisateur', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = _MockSessionsController(container.read(_refProvider))
        ..revertError = StateError('Ce carton a déjà été annulé.');
      await tester.pumpWidget(
        _buildPanelHarness(
          session: testSession,
          players: testPlayers,
          controller: controller,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Karim'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Carton jaune'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: find.byType(SnackBar), matching: find.text('Annuler')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ce carton a déjà été annulé.'), findsWidgets);
    });

    testWidgets('PANEL-04: Bouton [+] en bout de ligne ajoute un but sans ouvrir la discipline sheet', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = _MockSessionsController(container.read(_refProvider));

      await tester.pumpWidget(
        _buildPanelHarness(
          session: testSession,
          players: testPlayers,
          controller: controller,
        ),
      );
      await tester.pumpAndSettle();

      // Taper sur le bouton + pour Karim
      await tester.tap(find.byTooltip('Ajouter un but pour Karim'));
      await tester.pumpAndSettle();

      // N'a PAS ouvert PlayerDisciplineSheet
      expect(find.byType(PlayerDisciplineSheet), findsNothing);
      // A ouvert le dialog But avec étape de passe pour Karim
      expect(find.text('Qui lui a fait la passe ?'), findsOneWidget);
    });

    Future<_MockSessionsController> pumpPanel(WidgetTester tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = _MockSessionsController(container.read(_refProvider));
      await tester.pumpWidget(
        _buildPanelHarness(
          session: testSession,
          players: testPlayers,
          controller: controller,
        ),
      );
      await tester.pumpAndSettle();
      return controller;
    }

    testWidgets('PANEL-05: But avec passeur envoie l’action complète', (tester) async {
      final controller = await pumpPanel(tester);

      await tester.tap(find.byTooltip('Ajouter un but pour Karim'));
      await tester.pumpAndSettle();
      expect(find.text('Annuler le but'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Youssef')));
      await tester.pumpAndSettle();

      expect(controller.records, [
        {'type': 'goal', 'team': 'A', 'player': 'part1', 'assist': 'part2', 'delta': 1},
      ]);
      expect(controller.edits, [null]);
    });

    testWidgets('PANEL-06: But sans passeur puis buteur non renseigné', (tester) async {
      final controller = await pumpPanel(tester);

      await tester.tap(find.byTooltip('Ajouter un but pour Karim'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aucun passeur'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ajouter un but'));
      await tester.pumpAndSettle();
      expect(find.text('Qui a marqué ?'), findsOneWidget);
      await tester.tap(find.text('Buteur non renseigné'));
      await tester.pumpAndSettle();

      expect(controller.records, [
        {'type': 'goal', 'team': 'A', 'player': 'part1', 'assist': null, 'delta': 1},
        {'type': 'goal', 'team': 'A', 'player': null, 'assist': null, 'delta': 1},
      ]);
    });

    testWidgets('PANEL-07: Modifier un but transmet l’identifiant de l’événement', (tester) async {
      final controller = await pumpPanel(tester);

      final editButton = find.text('Modifier ce but');
      await tester.ensureVisible(editButton);
      await tester.tap(editButton);
      await tester.pumpAndSettle();

      expect(find.text('Annuler la modification'), findsOneWidget);
      expect(find.text('Annuler le but'), findsNothing);
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Youssef')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aucun passeur'));
      await tester.pumpAndSettle();

      expect(controller.records, [
        {'type': 'goal', 'team': 'A', 'player': 'part2', 'assist': null, 'delta': 1},
      ]);
      expect(controller.edits, ['dummy']);
    });
  });
}
