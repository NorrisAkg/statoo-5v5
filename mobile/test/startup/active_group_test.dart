import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/core/router/app_router.dart';
import 'package:statoo/features/players/application/players_provider.dart';
import 'package:statoo/features/sessions/application/sessions_provider.dart';
import 'package:statoo/features/shared/application/shared_providers.dart';
import 'package:statoo/features/stats/application/stats_providers.dart';
import 'package:statoo/features/team/application/team_provider.dart';
import 'package:statoo/features/team/data/team_repository.dart';
import 'package:statoo/main.dart' as application;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Database db;
  const now = '2026-10-26T12:00:00.000';

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    directory = await Directory.systemTemp.createTemp('statoo-boot-');
    await databaseFactory.setDatabasesPath(directory.path);
    db = await AppDatabase.instance.database;
  });
  tearDownAll(() async {
    await db.close();
    await directory.delete(recursive: true);
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({'hasSeenOnboarding': true});
    FlutterSecureStorage.setMockInitialValues({});
    for (final table in [
      'participations',
      'sessions',
      'players',
      'teams',
      'meta',
    ]) {
      await db.delete(table);
    }
  });

  Future<void> seed(String id, {int goals = 1, int players = 6}) async {
    await db.insert('teams', {'id': id, 'name': 'QA $id', 'created_at': now});
    for (var i = 0; i < players; i++) {
      await db.insert('players', {
        'id': '$id-p$i',
        'team_id': id,
        'name': 'QA $i',
        'created_at': now,
        'updated_at': now,
      });
    }
    await db.insert('sessions', {
      'id': '$id-s',
      'team_id': id,
      'played_at': now,
      'status': 'CLOSED',
      'is_ranked': 1,
      'score_a': goals,
      'score_b': 0,
      'result': 'A',
    });
    for (var i = 0; i < players; i++) {
      await db.insert('participations', {
        'id': '$id-pt$i',
        'session_id': '$id-s',
        'player_id': '$id-p$i',
        'team': i < players ~/ 2 ? 'A' : 'B',
        'goals': i == 0 ? goals : 0,
        'assists': i == 1 ? 1 : 0,
      });
    }
  }

  Future<Map<String, Object?>> records() async => {
    for (final table in ['teams', 'players', 'sessions', 'participations'])
      table: await db.query(table, orderBy: 'id'),
  };

  Future<ProviderContainer> boot(WidgetTester tester) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue = '/stats';
    addTearDown(
      tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
    );
    await tester.runAsync(application.main);
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(application.MyApp)),
    );
    final shared = container.read(sharedServiceProvider);
    addTearDown(shared.dispose);
    return container;
  }

  Future<void> checkStats(
    WidgetTester tester,
    ProviderContainer c,
    String id,
    int players,
    int goals,
  ) async {
    // Check before awaiting any other provider: no home/team-info side effect.
    expect(c.read(activeTeamIdProvider), id);
    expect(
      c.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/stats',
    );
    final totals = await tester.runAsync(
      () => c.read(groupTotalsProvider.future),
    );
    expect(totals!.totalSessions, 1);
    expect(totals.totalPlayers, players);
    expect(totals.activePlayers, players);
    expect(totals.totalGoals, goals);
    expect(totals.totalAssists, 1);
    final roster = await tester.runAsync(
      () => c.read(playersListProvider.future),
    );
    expect(roster, hasLength(players));
    expect(roster!.every((p) => p.teamId == id), isTrue);
    final sessions = await tester.runAsync(
      () => c.read(allSessionsProvider.future),
    );
    expect(sessions, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
  }

  testWidgets(
    'direct stats startup gets the persisted group before any home read',
    (tester) async {
      await tester.runAsync(() async {
        await seed('a');
        await SqliteTeamRepository(AppDatabase.instance).setActiveTeamId('a');
      });
      final before = await tester.runAsync(records);
      final c = await boot(tester);
      await checkStats(tester, c, 'a', 6, 1);
      expect(await tester.runAsync(records), before);
    },
  );

  for (final selection in ['sqlite', 'preferences', 'stale', 'missing']) {
    testWidgets(
      'startup resolves $selection selection without crossing groups',
      (tester) async {
        await tester.runAsync(() async {
          await seed('a');
          await seed('b', players: 4, goals: 3);
          final prefs = await SharedPreferences.getInstance();
          if (selection == 'sqlite') {
            await db.insert('meta', {'key': 'active_team_id', 'value': 'b'});
            await prefs.setString('active_team_id', 'a');
          } else if (selection == 'preferences') {
            await prefs.setString('active_team_id', 'b');
          } else if (selection == 'stale') {
            await db.insert('meta', {
              'key': 'active_team_id',
              'value': 'deleted',
            });
          }
        });
        final c = await boot(tester);
        final second = selection == 'sqlite' || selection == 'preferences';
        await checkStats(
          tester,
          c,
          second ? 'b' : 'a',
          second ? 4 : 6,
          second ? 3 : 1,
        );
      },
    );
  }

  testWidgets('empty installation stays empty and redirects to welcome', (
    tester,
  ) async {
    final c = await boot(tester);
    expect(c.read(activeTeamIdProvider), isNull);
    expect(c.read(hasTeamProvider), isFalse);
    expect(
      c.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/bienvenue',
    );
    final totals = await tester.runAsync(
      () => c.read(groupTotalsProvider.future),
    );
    expect(totals!.totalPlayers, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('legacy team preferences initialize the migrated group', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'hasSeenOnboarding': true,
      'team_name': 'Legacy QA',
    });
    final c = await boot(tester);
    expect(c.read(activeTeamIdProvider), 'team_1');
    expect(c.read(hasTeamProvider), isTrue);
    expect(
      (await tester.runAsync(() => db.query('teams')))?.single['name'],
      'Legacy QA',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('onboarding remains required while the group is initialized', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'hasSeenOnboarding': false});
    await tester.runAsync(() => seed('a'));
    final c = await boot(tester);
    expect(c.read(activeTeamIdProvider), 'a');
    expect(
      c.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/onboarding',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('selection after startup persists into the next boot', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seed('a');
      await seed('b', goals: 3, players: 4);
    });
    final first = await boot(tester);
    expect(first.read(activeTeamIdProvider), 'a');
    await tester.runAsync(
      () => first.read(activeTeamIdProvider.notifier).selectTeam('b'),
    );
    await checkStats(tester, first, 'b', 4, 3);
    final second = await boot(tester);
    await checkStats(tester, second, 'b', 4, 3);
  });

  testWidgets('database read failure does not boot a false empty application', (
    tester,
  ) async {
    await tester.runAsync(
      () => db.execute('ALTER TABLE teams RENAME TO unavailable_teams'),
    );
    try {
      Object? failure;
      await tester.runAsync(() async {
        try {
          await application.main();
        } on Object catch (error) {
          failure = error;
        }
      });
      expect(failure, isA<DatabaseException>());
      expect(find.byType(application.MyApp), findsNothing);
    } finally {
      await tester.runAsync(
        () => db.execute('ALTER TABLE unavailable_teams RENAME TO teams'),
      );
    }
  });
}
