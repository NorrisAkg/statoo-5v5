import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/features/players/application/players_provider.dart';
import 'package:statoo/features/players/domain/player.dart';
import 'package:statoo/features/sessions/presentation/new_session_screen.dart';
import 'package:statoo/features/settings/application/settings_provider.dart';

class _MockPlayersNotifier extends PlayersNotifier {
  _MockPlayersNotifier(this._players);
  final List<Player> _players;

  @override
  Future<List<Player>> build() async => _players;
}

void main() {
  setUpAll(() async {
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
      createdAt: now,
      updatedAt: now,
    ),
  ];

  Widget createWidget() {
    return ProviderScope(
      overrides: [
        playersListProvider.overrideWith(() => _MockPlayersNotifier(testPlayers)),
        minPlayersPerSessionProvider.overrideWith(() => MinPlayersNotifier(initialValue: 2)),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('fr', 'FR'),
        ],
        locale: const Locale('fr', 'FR'),
        home: const Scaffold(body: NewSessionScreen()),
      ),
    );
  }

  testWidgets('Checking player as present does not automatically assign team', (tester) async {
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    // Step 1 -> Click Continuer to go to Step 2
    expect(find.text('Continuer'), findsOneWidget);
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    // In Step 2, players are listed with "Présent" buttons
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Présent'), findsNWidgets(2));

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
    await tester.tap(find.text('Présent'));
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
  });
}
