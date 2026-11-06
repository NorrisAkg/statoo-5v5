import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/features/players/application/players_provider.dart';
import 'package:statoo/features/players/domain/player.dart';
import 'package:statoo/features/sessions/application/sessions_provider.dart';
import 'package:statoo/features/sessions/presentation/new_session_screen.dart';
import 'package:statoo/features/settings/application/settings_provider.dart';
import 'package:statoo/features/shared/application/shared_providers.dart';
import 'package:statoo/features/shared/data/shared_service.dart';
import 'package:statoo/features/team/application/team_provider.dart';
import 'package:statoo/features/team/domain/team_info.dart';

const _longName = 'Jean-Pierre au nom particulièrement long';

int _currentRosterCount = 3;

List<Player> _testRoster() => [
  Player(
    id: 'p1',
    teamId: 'g',
    name: 'Asffhb',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  ),
  Player(
    id: 'p2',
    teamId: 'g',
    name: 'Bnpi',
    nickname: 'Ben',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  ),
  Player(
    id: 'p3',
    teamId: 'g',
    name: _longName,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  ),
  for (int i = 4; i <= _currentRosterCount; i++)
    Player(
      id: 'p$i',
      teamId: 'g',
      name: 'Joueur $i',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
];

class _StubPlayersNotifier extends PlayersNotifier {
  @override
  Future<List<Player>> build() async => _testRoster();
}

class _StubTeamNotifier extends TeamInfoNotifier {
  @override
  Future<TeamInfo?> build() async => const TeamInfo(id: 'g', name: 'FC Test');
}

Widget _buildTestApp({
  bool dark = false,
  double scale = 1.0,
}) {
  final service = SharedService(AppDatabase.instance);
  return ProviderScope(
    overrides: [
      activeTeamIdProvider.overrideWith(
        () => ActiveTeamIdNotifier(initialValue: 'g'),
      ),
      hasTeamProvider.overrideWith(() => HasTeamNotifier(initialValue: true)),
      teamInfoProvider.overrideWith(_StubTeamNotifier.new),
      allTeamsProvider.overrideWith((ref) async => []),
      sharedServiceProvider.overrideWithValue(service),
      playersListProvider.overrideWith(_StubPlayersNotifier.new),
      allSessionsProvider.overrideWith((ref) async => []),
      minPlayersPerSessionProvider.overrideWith(
        () => MinPlayersNotifier(initialValue: 6),
      ),
    ],
    child: MaterialApp(
      theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
      locale: const Locale('fr', 'FR'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('fr', 'FR')],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
        ),
        child: child!,
      ),
      home: const NewSessionScreen(),
    ),
  );
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('fr_FR');
  });

  testWidgets(
    'Etape 2 Composition (393dp, scale 1.0) : les cartes joueurs affichent le nom et le bouton Present sur une seule ligne horizontale',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      final nameRect = tester.getRect(find.text('Asffhb'));
      final presentBtnRect = tester.getRect(
        find.widgetWithText(TextButton, 'Présent').first,
      );

      // Le nom et le bouton "+ Présent" doivent être alignés horizontalement sur la même ligne
      expect(
        (nameRect.center.dy - presentBtnRect.center.dy).abs(),
        lessThan(14.0),
        reason:
            'Le bouton + Présent doit être sur la même ligne horizontale que le nom du joueur sur un écran 393dp',
      );
    },
  );

  testWidgets(
    'Etape 2 Composition (393dp, scale 1.0) : un joueur selectionne au nom court garde les boutons A/B sur la meme ligne',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Présent').first);
      await tester.pumpAndSettle();

      final nameRect = tester.getRect(find.text('Asffhb'));
      final segmentedRect = tester.getRect(
        find.byType(SegmentedButton<String>).first,
      );

      expect(
        (nameRect.center.dy - segmentedRect.center.dy).abs(),
        lessThan(18.0),
        reason:
            'Le sélecteur A/B doit rester sur la même ligne que le nom court sur un écran 393dp',
      );
    },
  );

  testWidgets(
    'Etape 2 Composition : le label Rechercher un joueur est place au-dessus du TextField sans chevaucher sa bordure',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      final labelRect = tester.getRect(find.text('Rechercher un joueur'));
      final textFieldRect = tester.getRect(find.byType(TextField));

      expect(
        labelRect.bottom,
        lessThanOrEqualTo(textFieldRect.top + 2.0),
        reason:
            'Le label "Rechercher un joueur" doit être au-dessus du champ et non à cheval sur la bordure supérieure',
      );
    },
  );

  testWidgets(
    'Etape 2 Composition : le bouton Nouveau joueur affiche un libelle explicite et non une icone nue isolee',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      expect(
        find.text('Nouveau joueur'),
        findsOneWidget,
        reason:
            "Le bouton Nouveau joueur doit afficher un libellé visible plutôt qu'une icône isolée dans le vide",
      );
    },
  );

  testWidgets(
    'Etape 2 Composition : lors du scroll, le champ de recherche et son label restent bloques/epingles en haut',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      _currentRosterCount = 25;
      addTearDown(() => _currentRosterCount = 3);

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      final initialTitleRect = tester.getRect(find.text('Composition des équipes'));
      final initialLabelRect = tester.getRect(find.text('Rechercher un joueur'));

      // Scroller vers le bas de 350 pixels
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -350));
      await tester.pumpAndSettle();

      // Le titre a défilé vers le haut (hors écran ou plus haut)
      final scrolledTitleFinder = find.text('Composition des équipes');
      if (scrolledTitleFinder.evaluate().isNotEmpty) {
        final scrolledTitleRect = tester.getRect(scrolledTitleFinder);
        expect(scrolledTitleRect.top, lessThan(initialTitleRect.top));
      }

      // Le champ de recherche et son label doivent rester visibles et bloqués en haut
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Rechercher un joueur'), findsOneWidget);
      final pinnedSearchRect = tester.getRect(find.byType(TextField));
      final pinnedLabelRect = tester.getRect(find.text('Rechercher un joueur'));

      // Le label doit être bloqué en haut sous la barre supérieure (top < initialLabelRect.top)
      // et ne doit pas avoir disparu vers le haut (top >= 0)
      expect(pinnedLabelRect.top, greaterThanOrEqualTo(80.0));
      expect(pinnedLabelRect.top, lessThan(initialLabelRect.top));
      expect(pinnedSearchRect.top, greaterThan(pinnedLabelRect.top));
      expect(find.byType(TextField).hitTestable(), findsOneWidget);
    },
  );
}
