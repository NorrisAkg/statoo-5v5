import 'dart:ui' show SemanticsActionEvent, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/features/players/application/players_provider.dart';
import 'package:statoo/features/players/domain/player.dart';
import 'package:statoo/features/sessions/application/sessions_provider.dart';
import 'package:statoo/features/sessions/presentation/new_session_screen.dart';
import 'package:statoo/features/sessions/presentation/sessions_screen.dart';
import 'package:statoo/features/settings/application/settings_provider.dart';
import 'package:statoo/features/shared/application/shared_providers.dart';
import 'package:statoo/features/shared/data/shared_service.dart';
import 'package:statoo/features/team/application/team_provider.dart';
import 'package:statoo/features/team/domain/team_info.dart';
import 'package:statoo/features/team/presentation/add_team_players_screen.dart';
import 'package:statoo/features/team/presentation/create_team_screen.dart';

const longName = 'Jean-Pierre au nom particulièrement long';
List<Player> roster() => [
  for (final name in ['Alice', 'Bob', longName])
    Player(
      id: name,
      teamId: 'g',
      name: name,
      nickname: name == 'Bob' ? 'Bobby' : null,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
];

class Players extends PlayersNotifier {
  @override
  Future<List<Player>> build() async => roster();
  @override
  Future<bool> removePlayer(String id) async {
    state = AsyncData(state.requireValue.where((p) => p.id != id).toList());
    return true;
  }
}

class Team extends TeamInfoNotifier {
  @override
  Future<TeamInfo?> build() async => const TeamInfo(id: 'g', name: 'QA');
}

Widget fixture(
  Widget home, {
  bool push = false,
  bool readOnly = false,
  bool dark = false,
  double scale = 1,
  GoRouter? router,
}) {
  final service = SharedService(AppDatabase.instance);
  if (readOnly) {
    service.protectedGroups.add('g');
    service.identity = {
      'group_id': 'g',
      'expires_at': '2099-01-01',
      'account': {
        'id': 'reader',
        'roles': ['MEMBER'],
        'shared': true,
      },
    };
  }
  final theme = dark ? AppTheme.darkTheme : AppTheme.lightTheme;
  Widget media(BuildContext context, Widget? child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  );
  return ProviderScope(
    overrides: [
      activeTeamIdProvider.overrideWith(
        () => ActiveTeamIdNotifier(initialValue: 'g'),
      ),
      hasTeamProvider.overrideWith(() => HasTeamNotifier(initialValue: true)),
      teamInfoProvider.overrideWith(Team.new),
      allTeamsProvider.overrideWith((ref) async => []),
      sharedServiceProvider.overrideWithValue(service),
      playersListProvider.overrideWith(Players.new),
      allSessionsProvider.overrideWith((ref) async => []),
      minPlayersPerSessionProvider.overrideWith(
        () => MinPlayersNotifier(initialValue: 2),
      ),
    ],
    child: router != null
        ? MaterialApp.router(routerConfig: router, theme: theme, builder: media)
        : MaterialApp(
            theme: theme,
            locale: const Locale('fr', 'FR'),
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            supportedLocales: const [Locale('fr', 'FR')],
            builder: media,
            home: push
                ? Scaffold(
                    body: Builder(
                      builder: (context) => TextButton(
                        onPressed: () => Navigator.of(
                          context,
                        ).push(MaterialPageRoute<void>(builder: (_) => home)),
                        child: const Text('Ouvrir'),
                      ),
                    ),
                  )
                : home,
          ),
  );
}

Future<void> visibleTap(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      250,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void semanticTap(WidgetTester tester, String label) {
  final named = find.bySemanticsLabel(label);
  final node = tester.getSemantics(
    named.evaluate().isNotEmpty ? named : find.byTooltip(label),
  );
  expect([
    node.getSemanticsData().label,
    node.getSemanticsData().tooltip,
  ], contains(label));
  expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
  expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
  tester.binding.performSemanticsAction(
    SemanticsActionEvent(
      nodeId: node.id,
      viewId: tester.view.viewId,
      type: SemanticsAction.tap,
    ),
  );
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    for (final face in [
      (FontWeight.w400, 'Regular'),
      (FontWeight.w500, 'Medium'),
      (FontWeight.w600, 'SemiBold'),
      (FontWeight.w700, 'Bold'),
    ]) {
      final loader = FontLoader(
        GoogleFonts.poppins(fontWeight: face.$1).fontFamily!,
      )..addFont(rootBundle.load('assets/google_fonts/Poppins-${face.$2}.ttf'));
      await loader.load();
    }
    await initializeDateFormatting('fr_FR');
  });
  for (final home in [const CreateTeamScreen(), const AddTeamPlayersScreen()]) {
    testWidgets('A11Y01 back has a name and pops ${home.runtimeType}', (
      tester,
    ) async {
      await tester.pumpWidget(fixture(home, push: true));
      await tester.pumpAndSettle();
      await visibleTap(tester, find.text('Ouvrir'));
      semanticTap(tester, 'Retour');
      await tester.pumpAndSettle();
      expect(find.text('Ouvrir'), findsOneWidget);
    });
  }
  testWidgets(
    'A11Y02 roster removal names and removes only the intended member',
    (tester) async {
      await tester.pumpWidget(fixture(const AddTeamPlayersScreen()));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Bob'));
      semanticTap(tester, 'Retirer Bob du groupe');
      await tester.pumpAndSettle();
      expect(find.text('Bob'), findsNothing);
      expect(find.text('Alice'), findsOneWidget);
    },
  );
  for (final readOnly in [false, true]) {
    testWidgets('A11Y03 named create action respects reader=$readOnly', (
      tester,
    ) async {
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const SessionsScreen()),
          GoRoute(
            path: '/seances/nouvelle',
            builder: (_, _) => const Scaffold(body: Text('Destination')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        fixture(const SessionsScreen(), router: router, readOnly: readOnly),
      );
      await tester.pumpAndSettle();
      if (readOnly) {
        expect(find.byType(FloatingActionButton), findsNothing);
      } else {
        final data = tester
            .getSemantics(find.byType(FloatingActionButton))
            .getSemanticsData();
        expect([data.label, data.tooltip], contains('Nouvelle séance'));
        await visibleTap(tester, find.byType(FloatingActionButton));
        expect(find.text('Destination'), findsOneWidget);
      }
    });
  }
  for (final tournament in [false, true]) {
    testWidgets(
      'A11Y04/05/06 contextual composition actions tournament=$tournament',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(fixture(const NewSessionScreen()));
        await tester.pumpAndSettle();
        if (tournament) {
          await visibleTap(tester, find.text('Tournoi (3 équipes)'));
        }
        await visibleTap(tester, find.text('Continuer'));
        await tester.ensureVisible(find.text('Alice'));
        semanticTap(tester, 'Marquer Alice présent');
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(SegmentedButton<String>));
        semanticTap(tester, 'Équipe A pour Alice');
        await tester.pumpAndSettle();
        expect(
          tester
              .getSemantics(find.bySemanticsLabel('Équipe A pour Alice'))
              .getSemanticsData()
              .flagsCollection
              .isSelected,
          Tristate.isTrue,
        );
        if (tournament) {
          semanticTap(tester, 'Équipe C pour Alice');
          await tester.pumpAndSettle();
        } else {
          expect(find.bySemanticsLabel('Équipe C pour Alice'), findsNothing);
        }
        semanticTap(tester, 'Retirer Alice de la séance');
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('Marquer Alice présent'), findsOneWidget);
        expect(find.bySemanticsLabel('Marquer Bob présent'), findsOneWidget);
      },
    );
  }
  testWidgets(
    'A11Y07 search has an isolated stable name and preserves composition',
    (tester) async {
      await tester.pumpWidget(fixture(const NewSessionScreen()));
      await tester.pumpAndSettle();
      await visibleTap(tester, find.text('Continuer'));
      await tester.ensureVisible(find.byType(TextField));
      final before = tester
          .getSemantics(find.byType(TextField))
          .getSemanticsData();
      expect(before.label, contains('Rechercher un joueur'));
      expect(before.label, isNot(contains('Alice')));
      expect(before.flagsCollection.isTextField, isTrue);
      await tester.enterText(find.byType(TextField), 'Bobby');
      await tester.pumpAndSettle();
      addTearDown(tester.view.resetViewInsets);
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue,
      );
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Bobby',
      );
      expect(
        tester.getSemantics(find.byType(TextField)).getSemanticsData().label,
        contains('Rechercher un joueur'),
      );
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Alice'), findsNothing);
      await visibleTap(tester, find.byTooltip('Effacer la recherche'));
      expect(find.text('Alice'), findsOneWidget);
    },
  );
  testWidgets(
    'A11Y11 step transition resets scroll and keyboard leaves content reachable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(fixture(const NewSessionScreen(), scale: 2));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -2200));
      await tester.pumpAndSettle();
      await visibleTap(tester, find.text('Continuer'));
      expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .pixels,
        0,
      );
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Bob');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Bob',
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final width in [320.0, 393.0]) {
    testWidgets('A11Y12 complete search label at $width and 200 percent', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(fixture(const NewSessionScreen(), scale: 2));
      await tester.pumpAndSettle();
      await visibleTap(tester, find.text('Continuer'));
      await tester.ensureVisible(find.text('Rechercher un joueur'));
      await tester.pumpAndSettle();
      expect(
        tester
            .renderObject<RenderParagraph>(find.text('Rechercher un joueur'))
            .didExceedMaxLines,
        isFalse,
      );
    });
  }
  testWidgets('A11Y12 narrow previous label fits on one line', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(fixture(const NewSessionScreen()));
    await tester.pumpAndSettle();
    await visibleTap(tester, find.text('Continuer'));
    await tester.scrollUntilVisible(
      find.text('Précédent'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Précédent'));
    final element = tester.element(find.text('Précédent'));
    final text = tester.widget<Text>(find.text('Précédent'));
    final painter = TextPainter(
      text: TextSpan(
        text: text.data,
        style: DefaultTextStyle.of(element).style.merge(text.style),
      ),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(element),
    )..layout();
    expect(
      tester.getSize(find.text('Précédent')).height,
      lessThanOrEqualTo(painter.height + 1),
    );
    painter.dispose();
  });
  for (final width in [320.0, 393.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      for (final dark in [false, true]) {
        for (final tournament in [false, true]) {
          testWidgets(
            'A11Y08/10 framing $width/$scale/dark=$dark/tournament=$tournament with keyboard',
            (tester) async {
              tester.view.physicalSize = Size(width, width == 320 ? 568 : 852);
              tester.view.devicePixelRatio = 1;
              addTearDown(tester.view.reset);
              await tester.pumpWidget(
                fixture(const NewSessionScreen(), dark: dark, scale: scale),
              );
              await tester.pumpAndSettle();
              if (tournament) {
                await visibleTap(tester, find.text('Tournoi (3 équipes)'));
              }
              await visibleTap(tester, find.text('Continuer'));
              await tester.ensureVisible(find.text(longName));
              await tester.ensureVisible(
                find.widgetWithText(TextButton, 'Présent').last,
              );
              await tester.pumpAndSettle();
              expect(
                find.bySemanticsLabel('Marquer $longName présent'),
                findsOneWidget,
              );
              semanticTap(tester, 'Marquer $longName présent');
              await tester.pumpAndSettle();
              await tester.scrollUntilVisible(
                find.byType(SegmentedButton<String>),
                -200,
                scrollable: find.byType(Scrollable).first,
              );
              await tester.pumpAndSettle();
              semanticTap(tester, 'Équipe B pour $longName');
              await tester.pumpAndSettle();
              tester.view.viewInsets = const FakeViewPadding(bottom: 300);
              tester.view.viewPadding = const FakeViewPadding(
                top: 24,
                bottom: 34,
              );
              await tester.ensureVisible(find.byType(TextField));
              await tester.enterText(find.byType(TextField), 'Jean-Pierre');
              await tester.pumpAndSettle();
              await tester.ensureVisible(
                find.byTooltip('Retirer $longName de la séance'),
              );
              await tester.pumpAndSettle();
              expect(
                tester
                    .getSemantics(
                      find.byTooltip('Retirer $longName de la séance'),
                    )
                    .getSemanticsData()
                    .tooltip,
                'Retirer $longName de la séance',
              );
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  }
}
