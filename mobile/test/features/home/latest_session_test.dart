import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/features/home/presentation/home_screen.dart';
import 'package:statoo/features/home/presentation/home_session_result.dart';
import 'package:statoo/features/sessions/application/sessions_provider.dart';
import 'package:statoo/features/sessions/domain/session.dart';
import 'package:statoo/features/sessions/domain/session_summary.dart';

SessionSummaryItem summary(
  String id,
  int day, {
  bool ranked = false,
  bool tournament = false,
  SessionStatus status = SessionStatus.closed,
}) => SessionSummaryItem(
  playerCount: 15,
  session: Session(
    id: id,
    playedAt: DateTime(2026, 10, day),
    status: status,
    isRanked: ranked,
    sessionType: tournament ? SessionType.tournament3 : SessionType.classic2,
    teamNames: {'A': '$id Atlas', 'B': '$id Racing', 'C': '$id Sporting'},
    teamColors: const {'A': 0xFF8B5CF6, 'B': 0xFFEC4899, 'C': 0xFF06B6D4},
    winsA: 7,
    winsB: 4,
    winsC: 2,
    scoreA: 9,
    scoreB: 6,
  ),
);

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  Future<ProviderContainer> mount(
    WidgetTester tester,
    List<SessionSummaryItem> Function() sessions, {
    String filter = 'all',
    Session? active,
    GoRouter? router,
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        allSessionsProvider.overrideWith((ref) async => sessions()),
        activeDraftSessionProvider.overrideWith((ref) async => active),
      ],
    );
    addTearDown(container.dispose);
    container.read(sessionsFilterProvider.notifier).selectFilter(filter);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: router == null
            ? MaterialApp(theme: AppTheme.darkTheme, home: const HomeScreen())
            : MaterialApp.router(
                theme: AppTheme.darkTheme,
                routerConfig: router,
              ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  for (final filter in ['ranked', 'friendly', 'draft']) {
    testWidgets('ACC-01/02/03 latest closed session ignores $filter filter', (
      tester,
    ) async {
      final latest = summary(
        'latest',
        15,
        ranked: filter == 'friendly',
        tournament: true,
      );
      await mount(
        tester,
        () => [latest, summary('old', 14, ranked: filter != 'friendly')],
        filter: filter,
      );
      expect(find.text('latest Atlas'), findsOneWidget);
      expect(find.text('old Atlas'), findsNothing);
    });
  }

  testWidgets('ACC-04 chooses greatest played date among closed sessions', (
    tester,
  ) async {
    await mount(
      tester,
      () => [
        summary('old', 10),
        summary('draft', 16, status: SessionStatus.draft),
        summary('latest', 15),
      ],
    );
    expect(find.text('latest Atlas'), findsOneWidget);
    expect(find.text('old Atlas'), findsNothing);
  });

  testWidgets('ACC-05 tournament shows three club colors and victories', (
    tester,
  ) async {
    await mount(tester, () => [summary('cup', 15, tournament: true)]);
    for (final name in ['cup Atlas', 'cup Racing', 'cup Sporting']) {
      expect(find.text(name), findsOneWidget);
    }
    for (final value in ['7 V', '4 V', '2 V']) {
      expect(find.text(value), findsOneWidget);
    }
    expect(
      tester.widget<Text>(find.text('cup Sporting')).style?.color,
      const Color(0xFF06B6D4),
    );
    expect(find.text('9'), findsNothing);
    expect(find.text('6'), findsNothing);
  });

  testWidgets('ACC-06 classic result keeps both scores and club colors', (
    tester,
  ) async {
    await mount(tester, () => [summary('match', 15)]);
    expect(find.text('match Atlas'), findsOneWidget);
    expect(find.text('match Racing'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('match Atlas')).style?.color,
      const Color(0xFF8B5CF6),
    );
    expect(find.text('match Sporting'), findsNothing);
  });

  testWidgets(
    'D01-02 restored DRAW_ALL without match scores shows three victories',
    (tester) async {
      final restored = SessionSummaryItem(
        playerCount: 6,
        session: Session(
          id: 'restored',
          playedAt: DateTime(2026, 10, 15),
          status: SessionStatus.closed,
          sessionType: SessionType.tournament3,
          result: MatchResult.drawAll,
          winsA: 2,
          winsB: 2,
          winsC: 2,
          teamNames: const {
            'A': 'Lions QA',
            'B': 'Aigles QA',
            'C': 'Tigres QA',
          },
        ),
      );
      await mount(tester, () => [restored]);
      expect(find.text('2 V'), findsNWidgets(3));
      expect(find.text('Tigres QA'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(HomeSessionResult),
          matching: find.text('0'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets('ACC-07 active session keeps priority', (tester) async {
    await mount(
      tester,
      () => [summary('closed', 15)],
      active: summary('active', 16, status: SessionStatus.draft).session,
    );
    expect(find.text('Séance en cours'), findsOneWidget);
    expect(find.text('Dernière séance'), findsNothing);
  });

  testWidgets('ACC-08 no closed or active session keeps empty state', (
    tester,
  ) async {
    await mount(
      tester,
      () => [summary('draft', 16, status: SessionStatus.draft)],
    );
    expect(find.text('Aucune séance pour le moment'), findsOneWidget);
  });

  testWidgets('ACC-09 refreshed source replaces last closed session', (
    tester,
  ) async {
    var data = [summary('old', 14)];
    final container = await mount(tester, () => data);
    expect(find.text('old Atlas'), findsOneWidget);
    data = [summary('new', 15, tournament: true), ...data];
    container.invalidate(allSessionsProvider);
    await tester.pumpAndSettle();
    expect(find.text('new Sporting'), findsOneWidget);
    expect(find.text('old Atlas'), findsNothing);
  });

  testWidgets('ACC-10 tap opens the displayed tournament', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
        GoRoute(
          path: '/seances/:id',
          builder: (_, state) =>
              Scaffold(body: Text('Détail ${state.pathParameters['id']}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await mount(
      tester,
      () => [summary('cup', 15, tournament: true)],
      router: router,
    );
    await tester.tap(find.text('Dernière séance'));
    await tester.pumpAndSettle();
    expect(find.text('Détail cup'), findsOneWidget);
  });
}
