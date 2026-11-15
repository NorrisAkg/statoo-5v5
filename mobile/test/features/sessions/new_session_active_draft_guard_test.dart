import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/core/widgets/primary_button.dart';
import 'package:statoo/features/players/application/players_provider.dart';
import 'package:statoo/features/players/domain/player.dart';
import 'package:statoo/features/sessions/application/sessions_provider.dart';
import 'package:statoo/features/sessions/domain/session.dart';
import 'package:statoo/features/sessions/presentation/new_session_screen.dart';
import 'package:statoo/features/settings/application/settings_provider.dart';
import 'package:statoo/features/shared/application/shared_providers.dart';
import 'package:statoo/features/shared/data/shared_service.dart';
import 'package:statoo/features/team/application/team_provider.dart';

/// Garde « séance déjà active » de NewSessionScreen
/// (new_session_screen.dart : libellé du bouton, bandeau, `startImmediately`).
///
/// GRD01 sans séance active : « Débuter la séance », pas de bandeau,
///       création avec startImmediately = true, pas de SnackBar brouillon.
/// GRD02 avec séance active : bandeau d'avertissement et
///       « Enregistrer en brouillon » à l'étape de composition.
/// GRD03 avec séance active : création avec startImmediately = false et
///       SnackBar expliquant que la séance est enregistrée en brouillon.
/// GRD04 l'étape 1 affiche « Continuer » quel que soit l'état de la séance active.

class _MockPlayersNotifier extends PlayersNotifier {
  _MockPlayersNotifier(this._players);
  final List<Player> _players;

  @override
  Future<List<Player>> build() async => _players;
}

class _RecordingController extends SessionsController {
  _RecordingController(super._ref);

  final List<bool> startFlags = [];

  @override
  Future<String> createDraftSession({
    required DateTime playedAt,
    required bool isRanked,
    required bool allowUnevenTeams,
    required Map<String, String> playerTeamAssignments,
    SessionType sessionType = SessionType.classic2,
    int drawPoints = 1,
    bool startImmediately = true,
    Map<String, String> teamNames = const {},
    Map<String, int> teamColors = const {},
    String? occurrenceId,
  }) async {
    startFlags.add(startImmediately);
    return 's_created';
  }
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await initializeDateFormatting('fr_FR');
  });

  final now = DateTime(2026, 11, 14, 20);
  final players = [
    for (final (id, name) in [
      ('p1', 'Alice'),
      ('p2', 'Bob'),
      ('p3', 'Charlie'),
      ('p4', 'Dina'),
    ])
      Player(id: id, teamId: 't1', name: name, createdAt: now, updatedAt: now),
  ];
  final activeDraft = Session(
    id: 's_active',
    playedAt: now.subtract(const Duration(hours: 1)),
  );

  late _RecordingController controller;

  Widget createWidget({Session? active}) {
    final router = GoRouter(
      initialLocation: '/seances/nouvelle',
      routes: [
        GoRoute(
          path: '/seances',
          builder: (context, state) =>
              const Scaffold(body: Text('Liste des séances')),
          routes: [
            GoRoute(
              path: 'nouvelle',
              builder: (context, state) =>
                  const Scaffold(body: NewSessionScreen()),
            ),
            GoRoute(
              path: ':id',
              builder: (context, state) =>
                  Scaffold(body: Text('Détail ${state.pathParameters['id']}')),
            ),
          ],
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        activeDraftSessionProvider.overrideWith((ref) async => active),
        sessionsControllerProvider.overrideWith(
          (ref) => controller = _RecordingController(ref),
        ),
        nextSessionReferenceProvider.overrideWith(
          (ref, date) async => '2026-11-14-1',
        ),
        activeTeamIdProvider.overrideWith(
          () => ActiveTeamIdNotifier(initialValue: 't1'),
        ),
        sharedServiceProvider.overrideWithValue(
          SharedService(AppDatabase.instance),
        ),
        playersListProvider.overrideWith(() => _MockPlayersNotifier(players)),
        minPlayersPerSessionProvider.overrideWith(
          () => MinPlayersNotifier(initialValue: 2),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.darkTheme,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('fr', 'FR')],
        locale: const Locale('fr', 'FR'),
      ),
    );
  }

  Future<void> reachComposition(WidgetTester tester, {Session? active}) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(createWidget(active: active));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tout cocher'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tirer au sort'));
    await tester.pumpAndSettle();
  }

  const banner =
      'Une séance est déjà en cours. Cette séance sera sauvegardée en brouillon.';
  const draftSnack =
      'Séance enregistrée en brouillon. Clôturez ou supprimez la séance en cours pour débuter celle-ci.';

  testWidgets('GRD01 sans séance active la séance démarre immédiatement', (
    tester,
  ) async {
    await reachComposition(tester);

    expect(find.text(banner), findsNothing);
    expect(
      find.widgetWithText(PrimaryButton, 'Enregistrer en brouillon'),
      findsNothing,
    );
    final submit = find.widgetWithText(PrimaryButton, 'Débuter la séance');
    expect(submit, findsOneWidget);

    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(controller.startFlags, [true]);
    expect(find.text(draftSnack), findsNothing);
    expect(find.text('Détail s_created'), findsOneWidget);
  });

  testWidgets(
    'GRD02 avec séance active : bandeau et bouton « Enregistrer en brouillon »',
    (tester) async {
      await reachComposition(tester, active: activeDraft);

      expect(find.text(banner), findsOneWidget);
      expect(
        find.widgetWithText(PrimaryButton, 'Enregistrer en brouillon'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(PrimaryButton, 'Débuter la séance'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'GRD03 avec séance active la création reste en brouillon et prévient',
    (tester) async {
      await reachComposition(tester, active: activeDraft);

      await tester.tap(
        find.widgetWithText(PrimaryButton, 'Enregistrer en brouillon'),
      );
      await tester.pump();
      await tester.pump();

      expect(controller.startFlags, [false]);
      expect(find.text(draftSnack), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Détail s_created'), findsOneWidget);
    },
  );

  testWidgets(
    'GRD04 l’étape 1 affiche « Continuer » même avec une séance active',
    (tester) async {
      await tester.pumpWidget(createWidget(active: activeDraft));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(PrimaryButton, 'Continuer'), findsOneWidget);
      expect(find.text(banner), findsNothing);
    },
  );
}
