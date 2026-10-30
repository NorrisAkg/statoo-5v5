import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/core/router/app_router.dart';
import 'package:statoo/features/players/application/players_provider.dart';
import 'package:statoo/features/players/data/players_repository.dart';
import 'package:statoo/features/shared/application/shared_providers.dart';
import 'package:statoo/features/shared/data/shared_service.dart';
import 'package:statoo/features/team/application/team_provider.dart';
import 'package:statoo/features/team/data/team_repository.dart';
import 'package:statoo/main.dart';

Map<String, dynamic> snapshot({
  String group = 'g',
  int? goals,
  String status = 'CLOSED',
}) => {
  'name': 'QA $group',
  'members': [
    for (final id in ['a', 'b'])
      {
        'id': '$group-$id',
        'name': 'QA $id',
        'is_active': 1,
        'created_at': '2026-10-26T12:00:00',
        'updated_at': '2026-10-26T12:00:00',
      },
  ],
  'documents': <String, dynamic>{
    if (goals != null)
      'sport:$group-s': {
        'domain': 'sport',
        'occurrence_id': '$group-s',
        'revision': goals,
        'generation': 1,
        'payload': {
          'session': {
            'id': '$group-s',
            'team_id': group,
            'played_at': '2026-10-26T12:00:00',
            'status': status,
            'is_ranked': 1,
            'score_a': goals,
            'score_b': 0,
            'result': 'A',
          },
          'participations': [
            {
              'id': '$group-pt',
              'session_id': '$group-s',
              'player_id': '$group-a',
              'team': 'A',
              'goals': goals,
              'assists': 1,
              'yellow_cards': 0,
              'red_cards': 0,
            },
          ],
        },
      },
  },
};

void main() {
  late Database db;
  late AppDatabase app;
  late SharedService service;
  late ProviderContainer c;
  late GoRouter router;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      ),
    );
    app = AppDatabase.forTesting(db);
    await app.initSchemaForTest(db);
    service = SharedService(app)..identity = {'group_id': 'g'};
    await service.importSnapshot(snapshot());
    router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const SizedBox.shrink())],
    );
    c = ProviderContainer(
      overrides: [
        sharedServiceProvider.overrideWithValue(service),
        playersRepositoryProvider.overrideWithValue(
          SqlitePlayersRepository(app),
        ),
        teamRepositoryProvider.overrideWithValue(SqliteTeamRepository(app)),
        activeTeamIdProvider.overrideWith(
          () => ActiveTeamIdNotifier(initialValue: 'g'),
        ),
        appRouterProvider.overrideWithValue(router),
      ],
    );
    for (final id in ['g-a', 'g-b', 'h-a']) {
      c
        ..listen(playerStatsProvider(id), (_, _) {})
        ..listen(playerMatchHistoryProvider(id), (_, _) {})
        ..listen(canDeletePlayerProvider(id), (_, _) {});
    }
    c.listen(deletablePlayerIdsProvider, (_, _) {});
  });
  tearDown(() async {
    service.dispose();
    c.dispose();
    router.dispose();
    await db.close();
  });

  Future<void> settleQueries(WidgetTester tester) async {
    for (var attempt = 0; attempt < 200; attempt++) {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      final values = [
        for (final id in ['g-a', 'g-b', 'h-a']) ...[
          c.read(playerStatsProvider(id)),
          c.read(playerMatchHistoryProvider(id)),
          c.read(canDeletePlayerProvider(id)),
        ],
        c.read(deletablePlayerIdsProvider),
      ];
      if (values.every((value) => !value.isLoading)) {
        for (final value in values) {
          expect(value.hasError, isFalse, reason: '${value.error}');
        }
        return;
      }
    }
    fail('SQLite provider queries did not settle');
  }

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(container: c, child: const MyApp()),
    );
    await settleQueries(tester);
    expect(service.onChanged, isNotNull);
  }

  Future<void> receive(WidgetTester tester, Map<String, dynamic> data) async {
    await tester.runAsync(() async {
      await service.importSnapshot(data);
    });
    await settleQueries(tester);
  }

  testWidgets('REF01 open player stats refresh after a remote match', (
    tester,
  ) async {
    await mount(tester);
    await receive(tester, snapshot(goals: 2));
    final stats = await tester.runAsync(
      () => c.read(playerStatsProvider('g-a').future),
    );
    expect(stats!.matchesPlayed, 1);
    expect(stats.goals, 2);
    expect(stats.assists, 1);
    expect(stats.points, 3);
  });

  testWidgets('REF02 open history receives new and corrected matches', (
    tester,
  ) async {
    await mount(tester);
    await receive(tester, snapshot(goals: 1));
    final first = await tester.runAsync(
      () => c.read(playerMatchHistoryProvider('g-a').future),
    );
    expect(first, hasLength(1));
    await receive(tester, snapshot(goals: 3));
    final history = await tester.runAsync(
      () => c.read(playerMatchHistoryProvider('g-a').future),
    );
    expect(history, hasLength(1));
    expect(history!.single.goals, 3);
    expect(history.single.scoreA, 3);
  });

  testWidgets(
    'REF03 deletion guard refreshes after first remote participation',
    (tester) async {
      await mount(tester);
      expect(
        await tester.runAsync(
          () => c.read(canDeletePlayerProvider('g-a').future),
        ),
        isTrue,
      );
      await receive(tester, snapshot(goals: 1));
      expect(
        await tester.runAsync(
          () => c.read(canDeletePlayerProvider('g-a').future),
        ),
        isFalse,
      );
      expect(
        await tester.runAsync(
          () => c.read(canDeletePlayerProvider('g-b').future),
        ),
        isTrue,
      );
    },
  );

  testWidgets(
    'REF03 deletable set refreshes after first remote participation',
    (tester) async {
      await mount(tester);
      expect(
        await tester.runAsync(() => c.read(deletablePlayerIdsProvider.future)),
        {'g-a', 'g-b'},
      );
      await receive(tester, snapshot(goals: 1));
      expect(
        await tester.runAsync(() => c.read(deletablePlayerIdsProvider.future)),
        {'g-b'},
      );
    },
  );

  testWidgets('REF04 cancellation refreshes stats history and deletion guard', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await service.importSnapshot(snapshot(goals: 1));
      // Establish the closed-match baseline before binding the real callback.
      c
        ..invalidate(playerStatsProvider)
        ..invalidate(playerMatchHistoryProvider)
        ..invalidate(canDeletePlayerProvider);
      await c.pump();
    });
    await mount(tester);
    expect(
      (await tester.runAsync(() => c.read(playerStatsProvider('g-a').future)))!
          .goals,
      1,
    );
    await receive(tester, snapshot(goals: 1, status: 'CANCELLED'));
    final stats = await tester.runAsync(
      () => c.read(playerStatsProvider('g-a').future),
    );
    expect(stats!.goals, 0);
    expect(stats.matchesPlayed, 0);
    expect(
      await tester.runAsync(
        () => c.read(playerMatchHistoryProvider('g-a').future),
      ),
      isEmpty,
    );
    expect(
      await tester.runAsync(
        () => c.read(canDeletePlayerProvider('g-a').future),
      ),
      isTrue,
    );
  });

  testWidgets('REF05 repeated snapshot does not duplicate statistics or rows', (
    tester,
  ) async {
    await mount(tester);
    await receive(tester, snapshot(goals: 2));
    await receive(tester, snapshot(goals: 2));
    expect(
      (await tester.runAsync(() => c.read(playerStatsProvider('g-a').future)))!
          .goals,
      2,
    );
    expect(await tester.runAsync(() => db.query('sessions')), hasLength(1));
    expect(
      await tester.runAsync(() => db.query('participations')),
      hasLength(1),
    );
    expect(await tester.runAsync(() => db.query('players')), hasLength(2));
  });

  testWidgets('REF06 failed import leaves observed data unchanged', (
    tester,
  ) async {
    await mount(tester);
    final invalid = snapshot(goals: 1)
      ..['sport_settings'] = {'min_players_per_session': 1};
    await tester.runAsync(
      () => expectLater(service.importSnapshot(invalid), throwsStateError),
    );
    expect(
      (await tester.runAsync(() => c.read(playerStatsProvider('g-a').future)))!
          .goals,
      0,
    );
    expect(
      await tester.runAsync(
        () => c.read(playerMatchHistoryProvider('g-a').future),
      ),
      isEmpty,
    );
    expect(
      await tester.runAsync(
        () => c.read(canDeletePlayerProvider('g-a').future),
      ),
      isTrue,
    );
    expect(await tester.runAsync(() => db.query('sessions')), isEmpty);
  });

  testWidgets('REF07 other group notification cannot expose its players here', (
    tester,
  ) async {
    await mount(tester);
    final other = SharedService(app)
      ..identity = {'group_id': 'h'}
      ..onChanged = service.onChanged;
    await tester.runAsync(
      () => other.importSnapshot(snapshot(group: 'h', goals: 4)),
    );
    await settleQueries(tester);
    expect(c.read(activeTeamIdProvider), 'g');
    expect(
      (await tester.runAsync(() => c.read(playerStatsProvider('g-a').future)))!
          .goals,
      0,
    );
    expect(
      (await tester.runAsync(() => c.read(playerStatsProvider('h-a').future)))!
          .goals,
      0,
    );
    expect(
      await tester.runAsync(
        () => c.read(playerMatchHistoryProvider('h-a').future),
      ),
      isEmpty,
    );
    expect(
      await tester.runAsync(
        () => c.read(canDeletePlayerProvider('h-a').future),
      ),
      isFalse,
    );
    other.dispose();
  });

  testWidgets('REF08 switch after notification reads only the selected group', (
    tester,
  ) async {
    await mount(tester);
    await receive(tester, snapshot(goals: 2));
    final other = SharedService(app)..identity = {'group_id': 'h'};
    await tester.runAsync(
      () => other.importSnapshot(snapshot(group: 'h', goals: 4)),
    );
    await tester.runAsync(() async {
      await c.read(activeTeamIdProvider.notifier).selectTeam('h');
    });
    await settleQueries(tester);
    expect(
      (await tester.runAsync(() => c.read(playerStatsProvider('h-a').future)))!
          .goals,
      4,
    );
    expect(
      (await tester.runAsync(() => c.read(playerStatsProvider('g-a').future)))!
          .goals,
      0,
    );
    expect(
      await tester.runAsync(
        () => c.read(canDeletePlayerProvider('g-a').future),
      ),
      isFalse,
    );
    other.dispose();
  });
}
