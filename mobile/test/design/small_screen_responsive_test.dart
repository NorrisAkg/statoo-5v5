import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/core/widgets/browser_app_frame.dart';
import 'package:statoo/core/widgets/primary_button.dart';
import 'package:statoo/features/home/presentation/home_screen.dart';
import 'package:statoo/features/onboarding/presentation/group_entry_screen.dart';
import 'package:statoo/features/players/application/players_provider.dart';
import 'package:statoo/features/players/domain/player.dart';
import 'package:statoo/features/players/presentation/players_screen.dart';
import 'package:statoo/features/ranking/application/ranking_providers.dart';
import 'package:statoo/features/ranking/domain/mvp_entry.dart';
import 'package:statoo/features/ranking/domain/standing_entry.dart';
import 'package:statoo/features/ranking/presentation/standings_screen.dart';
import 'package:statoo/features/sessions/application/sessions_provider.dart';
import 'package:statoo/features/sessions/domain/session.dart';
import 'package:statoo/features/sessions/presentation/new_session_screen.dart';
import 'package:statoo/features/sessions/presentation/sessions_screen.dart';
import 'package:statoo/features/settings/presentation/settings_screen.dart';
import 'package:statoo/features/shared/application/shared_providers.dart';
import 'package:statoo/features/shared/presentation/shared_group_screen.dart';
import 'package:statoo/features/stats/application/stats_providers.dart';
import 'package:statoo/features/stats/domain/group_totals.dart';
import 'package:statoo/features/stats/presentation/stats_screen.dart';
import 'package:statoo/features/team/application/team_provider.dart';
import 'package:statoo/features/team/domain/team_info.dart';
import 'package:statoo/features/team/presentation/add_team_players_screen.dart';
import 'package:statoo/features/team/presentation/create_team_screen.dart';

import '../support/local_shared_service.dart';

const groupName = 'Les joueurs du quartier de la grande ville';

class _Team extends TeamInfoNotifier {
  @override
  Future<TeamInfo?> build() async => const TeamInfo(id: 'g', name: groupName);
}

class _Players extends PlayersNotifier {
  @override
  Future<List<Player>> build() async => [
    Player(
      id: 'p',
      teamId: 'g',
      name: 'Jean-Pierre au nom particulièrement long',
      nickname: 'Le capitaine de toute la grande équipe',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  ];
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('fr_FR');
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final width in [320.0, 393.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      for (final dark in [false, true]) {
        for (final page in [
          'button',
          'create',
          'home',
          'home-rich',
          'active',
          'players',
          'entry',
          'members',
          'sessions',
          'ranking',
          'stats',
          'stats-rich',
          'settings',
          'shared',
          'new-session',
        ]) {
          for (final keyboard in [0.0, 300.0]) {
            if (keyboard > 0 &&
                ![
                  'create',
                  'members',
                  'shared',
                  'new-session',
                ].contains(page)) {
              continue;
            }
            testWidgets(
              'RSP $page width=$width scale=$scale dark=$dark keyboard=$keyboard',
              (tester) async {
                final errorHandler = FlutterError.onError;
                FlutterError.onError = (details) {
                  FlutterError.dumpErrorToConsole(details, forceReport: true);
                  errorHandler?.call(details);
                };
                addTearDown(() => FlutterError.onError = errorHandler);
                tester.view.physicalSize = Size(
                  width,
                  width == 320 ? 568 : 852,
                );
                tester.view.devicePixelRatio = 1;
                tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
                if (keyboard > 0) {
                  tester.view.viewPadding = const FakeViewPadding(
                    top: 24,
                    bottom: 34,
                  );
                }
                addTearDown(tester.view.reset);
                final home = switch (page) {
                  'button' => Scaffold(
                    body: SingleChildScrollView(
                      child: PrimaryButton(
                        label: 'Continuer vers la désignation des responsables du groupe',
                        onPressed: () {},
                      ),
                    ),
                  ),
                  'create' => const CreateTeamScreen(),
                  'home' || 'home-rich' || 'active' => const HomeScreen(),
                  'players' => const PlayersScreen(),
                  'entry' => const GroupEntryScreen(),
                  'members' => const AddTeamPlayersScreen(),
                  'sessions' => const SessionsScreen(),
                  'ranking' => const StandingsScreen(),
                  'stats' || 'stats-rich' => const StatsScreen(),
                  'settings' => const SettingsScreen(),
                  'shared' => const SharedGroupScreen(),
                  _ => const NewSessionScreen(),
                };
                await tester.pumpWidget(
                  ProviderScope(
                    overrides: [
                      sharedServiceProvider.overrideWithValue(
                        LocalTestSharedService(),
                      ),
                      teamInfoProvider.overrideWith(_Team.new),
                      allTeamsProvider.overrideWith((ref) async => []),
                      teamCountsProvider('g').overrideWith((ref) async => {}),
                      playersListProvider.overrideWith(_Players.new),
                      deletablePlayerIdsProvider.overrideWith(
                        (ref) async => <String>{},
                      ),
                      activeDraftSessionProvider.overrideWith(
                        (ref) async => page == 'active'
                            ? Session(
                                id: 's',
                                playedAt: DateTime(2026, 10, 17, 18),
                              )
                            : null,
                      ),
                      playerOfTheMonthProvider.overrideWith(
                        (ref) async => page == 'home-rich'
                            ? MvpEntry.fromMap({
                                'rank': 1,
                                'player_id': 'p',
                                'name':
                                    'Jean-Pierre au nom particulièrement long',
                                'nickname':
                                    'Le capitaine de toute la grande équipe',
                                'matches_played': 12,
                                'month': '2026-10',
                                'score': 123.45,
                              })
                            : null,
                      ),
                      standingsProvider.overrideWith(
                        (ref) async => page == 'home-rich'
                            ? [
                                StandingEntry.fromMap({
                                  'rank': 1,
                                  'player_id': 'p',
                                  'name': 'Jean-Pierre au nom particulièrement long',
                                  'nickname':
                                      'Le capitaine de toute la grande équipe',
                                  'matches_played': 12,
                                  'points': 12345,
                                }),
                              ]
                            : [],
                      ),
                      groupTotalsProvider.overrideWith(
                        (ref) async =>
                            page == 'stats-rich' || page == 'home-rich'
                            ? GroupTotals.fromMap({
                                'total_sessions': 12345,
                                'total_players': 12345,
                                'total_goals': 123456,
                                'total_assists': 123456,
                                'unassigned_goals_difference': 12,
                              })
                            : const GroupTotals.empty(),
                      ),
                    ],
                    child: MaterialApp(
                      theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
                      builder: (context, child) => MediaQuery(
                        data: MediaQuery.of(context)
                            .copyWith(textScaler: TextScaler.linear(scale)),
                        child: child!,
                      ),
                      home: BrowserAppFrame(enabled: true, child: home),
                    ),
                  ),
                );
                await tester.pumpAndSettle();
                expect(tester.takeException(), isNull);
                if (page == 'create' && keyboard > 0) {
                  await tester.enterText(
                    find.byType(TextFormField).first,
                    'Les Lions QA',
                  );
                  tester.view.viewInsets = FakeViewPadding.zero;
                  await tester.pumpAndSettle();
                  expect(
                    tester
                        .widget<TextFormField>(find.byType(TextFormField).first)
                        .controller!
                        .text,
                    'Les Lions QA',
                  );
                  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
                  await tester.pumpAndSettle();
                  expect(tester.takeException(), isNull);
                }
                if (page == 'stats' || page == 'stats-rich') {
                  final target = find.text('Score global des séances');
                  await tester.scrollUntilVisible(
                    target,
                    180,
                    scrollable: find
                        .byWidgetPredicate(
                          (w) =>
                              w is Scrollable &&
                              w.axisDirection == AxisDirection.down,
                        )
                        .first,
                  );
                  final paragraph = tester.renderObject<RenderParagraph>(
                    target,
                  );
                  expect(
                    paragraph.didExceedMaxLines,
                    isFalse,
                    reason: 'dashboard descriptions must wrap instead of truncating',
                  );
                }
                // Visit content below the fold as well; ListView children may be lazy.
                final vertical = find.byWidgetPredicate(
                  (w) =>
                      w is Scrollable && w.axisDirection == AxisDirection.down,
                );
                if (vertical.evaluate().isNotEmpty) {
                  for (var i = 0; i < 30; i++) {
                    final state = tester.state<ScrollableState>(vertical.first);
                    if (!state.position.hasContentDimensions ||
                        state.position.pixels >=
                            state.position.maxScrollExtent) {
                      break;
                    }
                    final before = state.position.pixels;
                    await tester.drag(vertical.first, const Offset(0, -320));
                    await tester.pumpAndSettle();
                    expect(tester.takeException(), isNull);
                    if (state.position.pixels == before) break;
                  }
                }
                if (page == 'button') {
                  final paragraph = tester.renderObject<RenderParagraph>(
                    find.text(
                      'Continuer vers la désignation des responsables du groupe',
                    ),
                  );
                  expect(
                    paragraph.didExceedMaxLines,
                    isFalse,
                    reason: 'essential action must remain fully readable',
                  );
                  expect(
                    tester.getSize(find.byType(ElevatedButton)).height,
                    greaterThanOrEqualTo(48),
                  );
                }
                if (page == 'home-rich') {
                  final target = find.text('123456').first;
                  await tester.scrollUntilVisible(
                    target,
                    180,
                    scrollable: vertical.first,
                  );
                  final paragraph = tester.renderObject<RenderParagraph>(
                    target,
                  );
                  expect(
                    paragraph.getTransformTo(null).storage[0].abs(),
                    greaterThanOrEqualTo(.99),
                    reason: 'KPI must not shrink the requested text size',
                  );
                }
                if (page == 'create') {
                  expect(
                    tester
                        .renderObject<RenderParagraph>(
                          find.text('Nom court (facultatif)'),
                        )
                        .didExceedMaxLines,
                    isFalse,
                    reason: 'field labels must remain complete at large text',
                  );
                  expect(
                    tester
                        .renderObject<RenderParagraph>(
                          find.text('Étape 1 sur 2 · Votre équipe'),
                        )
                        .didExceedMaxLines,
                    isFalse,
                    reason: 'step label must not be cut at larger text sizes',
                  );
                  await tester.ensureVisible(
                    find.text("Continuer vers l'effectif"),
                  );
                  await tester.pumpAndSettle();
                  expect(tester.takeException(), isNull);
                  expect(
                    find.text("Continuer vers l'effectif").hitTestable(),
                    findsOneWidget,
                  );
                }
                if (page == 'members') {
                  expect(
                    tester
                        .renderObject<RenderParagraph>(
                          find.text('Étape 2 sur 2 · Effectif'),
                        )
                        .didExceedMaxLines,
                    isFalse,
                  );
                }
              },
            );
          }
        }
      }
    }
  }
}
