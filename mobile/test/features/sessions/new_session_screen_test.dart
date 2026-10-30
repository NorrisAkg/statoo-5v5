import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/core/widgets/primary_button.dart';
import 'package:statoo/features/players/application/players_provider.dart';
import 'package:statoo/features/players/domain/player.dart';
import 'package:statoo/features/sessions/application/sessions_provider.dart';
import 'package:statoo/features/sessions/data/sessions_repository.dart';
import 'package:statoo/features/sessions/domain/session_team_names.dart';
import 'package:statoo/features/sessions/presentation/add_late_players_bottom_sheet.dart';
import 'package:statoo/features/sessions/presentation/new_session_screen.dart';
import 'package:statoo/features/settings/application/settings_provider.dart';
import 'package:statoo/features/shared/application/shared_providers.dart';
import 'package:statoo/features/shared/data/shared_service.dart';
import 'package:statoo/features/team/application/team_provider.dart';

class _MockPlayersNotifier extends PlayersNotifier {
  _MockPlayersNotifier(this._players);
  final List<Player> _players;

  @override
  Future<List<Player>> build() async => _players;
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await initializeDateFormatting('fr_FR');
  });

  final now = DateTime.now();
  final testPlayers = [
    Player(
      id: 'p1',
      teamId: 't1',
      name: 'Alice',
      createdAt: now,
      updatedAt: now,
    ),
    Player(
      id: 'p2',
      teamId: 't1',
      name: 'Bob',
      nickname: 'Bobby',
      createdAt: now,
      updatedAt: now,
    ),
    Player(
      id: 'p3',
      teamId: 't1',
      name: 'Charlie',
      createdAt: now,
      updatedAt: now,
    ),
  ];

  Widget createWidget({
    String? role,
    Widget? home,
    SharedService? serviceOverride,
    SessionsRepository? repoOverride,
    String Function(DateTime date)? referenceBuilderOverride,
    String? referenceOverride = '2026-10-30-1',
  }) {
    final service = serviceOverride ?? SharedService(AppDatabase.instance);
    if (role != null) {
      service.protectedGroups.add('t1');
      service.identity = {
        'group_id': 't1',
        'expires_at': '2099-01-01T00:00:00Z',
        'account': {
          'id': 'me',
          'roles': [role],
        },
      };
    }
    return ProviderScope(
      overrides: [
        if (repoOverride != null) sessionsRepositoryProvider.overrideWithValue(repoOverride),
        if (referenceBuilderOverride != null)
          nextSessionReferenceProvider.overrideWith(
            (ref, date) async => referenceBuilderOverride(date),
          )
        else if (referenceOverride != null)
          nextSessionReferenceProvider.overrideWith(
            (ref, date) async => referenceOverride,
          ),
        activeTeamIdProvider.overrideWith(
          () => ActiveTeamIdNotifier(initialValue: 't1'),
        ),
        sharedServiceProvider.overrideWithValue(service),
        playersListProvider.overrideWith(
          () => _MockPlayersNotifier(testPlayers),
        ),
        minPlayersPerSessionProvider.overrideWith(
          () => MinPlayersNotifier(initialValue: 2),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('fr', 'FR')],
        locale: const Locale('fr', 'FR'),
        home: Scaffold(body: home ?? const NewSessionScreen()),
      ),
    );
  }

  group('NewSessionScreen', () {
    testWidgets(
      'UX06-03 late players selection does not offer member creation to SG',
      (tester) async {
        await tester.pumpWidget(
          createWidget(
            role: 'SG',
            home: const AddLatePlayersBottomSheet(
              sessionId: 's',
              currentTeamACount: 1,
              currentTeamBCount: 1,
              alreadyAssignedPlayerIds: {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Alice'), findsOneWidget);
        expect(find.text('Créer'), findsNothing);
      },
    );
    testWidgets('UX06-03 SG can compose teams without creating members', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(createWidget(role: 'SG'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      expect(find.text('Alice'), findsOneWidget);
      expect(find.byTooltip('Nouveau joueur'), findsNothing);
    });
    testWidgets('UX06-06 direct new session route prevents readonly input', (
      tester,
    ) async {
      await tester.pumpWidget(createWidget(role: 'MEMBER'));
      await tester.pumpAndSettle();
      expect(find.text('Continuer'), findsNothing);
      expect(find.textContaining('Consultation'), findsWidgets);
      expect(find.textContaining('Admin, Président, Vice-président, SG ou SGA'), findsOneWidget);
    });
    testWidgets(
      'UX03-22 local creation exposes the optional occurrence reference',
      (tester) async {
        await tester.pumpWidget(createWidget());
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.widgetWithText(TextField, 'Référence de la séance'),
          250,
        );
        expect(
          find.widgetWithText(TextField, 'Référence de la séance'),
          findsOneWidget,
        );
      },
    );
    testWidgets(
      'Checking player as present does not automatically assign team',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createWidget());
        await tester.pumpAndSettle();

        // Step 1 -> Click Continuer to go to Step 2
        expect(find.text('Continuer'), findsOneWidget);
        await tester.tap(find.text('Continuer'));
        await tester.pumpAndSettle();

        // In Step 2, players are listed with "Présent" buttons
        expect(find.text('Alice'), findsOneWidget);
        expect(find.text('Bob'), findsOneWidget);
        expect(find.text('Charlie'), findsOneWidget);
        expect(find.text('Présent'), findsNWidgets(3));

        // Tap "Présent" on Alice
        await tester.tap(find.text('Présent').first);
        await tester.pumpAndSettle();

        // Alice is now present, showing segmented button A/B and unassigned badge
        expect(find.text('À placer: 1'), findsOneWidget);
        expect(find.text('Choisir A ou B'), findsOneWidget);
        expect(find.text('Équipe A: 0'), findsOneWidget);
        expect(find.text('Équipe B: 0'), findsOneWidget);

        // Manually assign Alice to Team A
        final segmentA = find.descendant(
          of: find.byType(SegmentedButton<String>),
          matching: find.text('A'),
        );
        await tester.tap(segmentA);
        await tester.pumpAndSettle();

        expect(find.text('Équipe A: 1'), findsOneWidget);
        expect(find.text('À placer: 1'), findsNothing);

        // Mark Bob as present
        await tester.tap(find.text('Présent').first);
        await tester.pumpAndSettle();

        // Bob is present but not assigned yet
        expect(find.text('Équipe A: 1'), findsOneWidget);
        expect(find.text('Équipe B: 0'), findsOneWidget);
        expect(find.text('À placer: 1'), findsOneWidget);

        // Now test "Tirer au sort"
        await tester.tap(find.text('Tirer au sort'));
        await tester.pumpAndSettle();

        // Both players should now be assigned (one to A, one to B)
        expect(find.text('Équipe A: 1'), findsOneWidget);
        expect(find.text('Équipe B: 1'), findsOneWidget);
        expect(find.text('À placer: 1'), findsNothing);
      },
    );

    testWidgets('Search filters player list by name or nickname', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Charlie'), findsOneWidget);

      // Search by nickname 'Bobby'
      final searchInput = find.byType(TextField);
      await tester.enterText(searchInput, 'Bobby');
      await tester.pumpAndSettle();

      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Alice'), findsNothing);
      expect(find.text('Charlie'), findsNothing);

      // Search non-existent player
      await tester.enterText(searchInput, 'Zinedine');
      await tester.pumpAndSettle();

      expect(
        find.text('Aucun joueur ne correspond à « Zinedine »'),
        findsOneWidget,
      );
      expect(find.text('Effacer la recherche'), findsOneWidget);

      // Tap clear search
      await tester.tap(find.text('Effacer la recherche'));
      await tester.pumpAndSettle();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Charlie'), findsOneWidget);
    });

    testWidgets('Toggle all presence checks and unchecks all players', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      expect(find.text('0/3 présents'), findsOneWidget);
      expect(find.text('Tout cocher'), findsOneWidget);

      // Tap 'Tout cocher'
      await tester.tap(find.text('Tout cocher'));
      await tester.pumpAndSettle();

      expect(find.text('3/3 présents'), findsOneWidget);
      expect(find.text('Tout décocher'), findsOneWidget);
      expect(find.text('À placer: 3'), findsOneWidget);

      // Random draw assigns them to A and B
      await tester.tap(find.text('Tirer au sort'));
      await tester.pumpAndSettle();
      expect(find.text('À placer: 3'), findsNothing);

      // Tap 'Tout décocher'
      await tester.tap(find.text('Tout décocher'));
      await tester.pumpAndSettle();

      expect(find.text('0/3 présents'), findsOneWidget);
      expect(find.text('Tout cocher'), findsOneWidget);
      expect(find.text('Présent'), findsNWidgets(3));
    });
  });
  testWidgets('tournament displays three stable club names', (tester) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tournoi (3 équipes)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tout cocher'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tirer au sort'));
    await tester.pumpAndSettle();
    final names = sessionTeamNames
        .where((name) => find.text(name).evaluate().isNotEmpty)
        .toList();
    expect(names, hasLength(3));
    expect(find.byType(TextFormField), findsNothing);
    await tester.tap(find.text('Précédent'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    for (final name in names) {
      expect(find.text(name), findsOneWidget);
    }
  });
  testWidgets(
    'creation assigns club names without inputs and keeps color validation',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('team-name-A')), findsNothing);
      await tester.tap(find.text('Tout cocher'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tirer au sort'));
      await tester.pumpAndSettle();
      final submit = find.widgetWithText(PrimaryButton, 'Débuter la séance');
      expect(tester.widget<PrimaryButton>(submit).onPressed, isNotNull);
      expect(find.byType(TextFormField), findsNothing);
      final drawnNames = sessionTeamNames
          .where((name) => find.text(name).evaluate().isNotEmpty)
          .toList();
      expect(drawnNames, hasLength(2));
      await tester.tap(find.byKey(const ValueKey('team-color-A-Orange')));
      await tester.pump();
      expect(tester.widget<PrimaryButton>(submit).onPressed, isNull);
      await tester.tap(find.byTooltip('Réinitialiser Équipe A'));
      await tester.pump();
      expect(tester.widget<PrimaryButton>(submit).onPressed, isNotNull);
      for (final name in drawnNames) {
        expect(find.text(name), findsOneWidget);
      }
    },
  );

  testWidgets('auto-generates next reference on initial open without manual input', (tester) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    final refField = find.widgetWithText(TextField, '2026-10-30-1');
    expect(refField, findsOneWidget);
  });

  testWidgets('auto-generates non-colliding reference when previous session exists for today', (tester) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidget(referenceOverride: '2026-10-30-2'));
    await tester.pumpAndSettle();

    final refField = find.widgetWithText(TextField, '2026-10-30-2');
    expect(refField, findsOneWidget);
  });

  testWidgets('keeps custom reference when user manually typed a custom reference', (tester) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    final refField = find.widgetWithText(TextField, '2026-10-30-1');
    expect(refField, findsOneWidget);

    await tester.enterText(refField, 'CUSTOM-REF-99');
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'CUSTOM-REF-99'), findsOneWidget);
  });

  testWidgets('updates reference dynamically when date changes if user has not edited it', (tester) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      createWidget(
        referenceBuilderOverride: (date) =>
            '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}-1',
      ),
    );
    await tester.pumpAndSettle();

    final today = DateTime.now();
    final todayFormatted =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}-1';
    expect(find.widgetWithText(TextField, todayFormatted), findsOneWidget);

    await tester.tap(find.text('Date'));
    await tester.pumpAndSettle();

    expect(find.text('OK'), findsOneWidget);
    final targetDay = today.day == 15 ? 16 : 15;
    await tester.tap(find.text('$targetDay').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    final updatedDateFormatted =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${targetDay.toString().padLeft(2, '0')}-1';
    expect(find.widgetWithText(TextField, updatedDateFormatted), findsOneWidget);
  });
}
