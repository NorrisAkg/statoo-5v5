import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/features/sessions/data/live_stats_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:statoo/features/sessions/application/sessions_provider.dart';
import 'package:statoo/features/shared/application/shared_providers.dart';
import 'package:statoo/features/shared/data/shared_service.dart';
import 'package:statoo/features/team/application/team_provider.dart';

void main() {
  late Database db;
  late LiveStatsRepository repo;
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    final app = AppDatabase.forTesting(db);
    await app.initSchemaForTest(db);
    repo = LiveStatsRepository(app);
    await db.insert('teams', {
      'id': 't',
      'name': 'Test',
      'format': '5v5',
      'created_at': '2026-10-17',
    });
    await db.insert('sessions', {
      'id': 's',
      'team_id': 't',
      'played_at': '2026-10-17',
      'status': 'DRAFT',
      'session_type': 'CLASSIC_2',
      'score_a': 0,
      'score_b': 0,
    });
    await db.insert('meta', {'key': 'active_session_id_t', 'value': 's'});
    for (final id in ['p', 'q', 'r']) {
      await db.insert('players', {
        'id': id,
        'team_id': 't',
        'name': id,
        'created_at': '2026-10-17',
        'updated_at': '2026-10-17',
      });
      await db.insert('participations', {
        'id': id,
        'session_id': 's',
        'player_id': id,
        'team': id == 'r' ? 'B' : 'A',
      });
    }
  });
  tearDown(() async => db.close());
  Future<Map<String, Object?>> session() async =>
      (await db.query('sessions')).single;
  Future<Map<String, Object?>> player(String id) async => (await db.query(
    'participations',
    where: 'id = ?',
    whereArgs: [id],
  )).single;
  Future<void> add(
    String type, {
    String? player,
    String? assist,
    String team = 'A',
    int delta = 1,
    String? edit,
  }) => repo.apply('t', 's', {
    'type': type,
    'team': team,
    'player': player,
    'assist': assist,
    'delta': delta,
  }, edit: edit);
  test('INT-01/06 atomic goal, assist, durable journal and undo', () async {
    await add('goal', player: 'p', assist: 'q');
    expect((await session())['score_a'], 1);
    expect((await player('p'))['goals'], 1);
    expect((await player('q'))['assists'], 1);
    expect(
      (await LiveStatsRepository(
        AppDatabase.forTesting(db),
      ).journal('t', 's')).length,
      1,
    );
    await repo.undo('t', 's');
    expect((await session())['score_a'], 0);
    expect((await player('q'))['assists'], 0);
    expect(await repo.journal('t', 's'), isEmpty);
    await repo.undo('t', 's');
  });
  test('INT-02/05 anonymous goals and cards', () async {
    await add('goal');
    await add('yellow', player: 'p');
    await add('red', player: 'q');
    expect((await session())['unassigned_goals_a'], 1);
    expect((await session())['score_a'], 1);
    expect((await player('p'))['yellow_cards'], 1);
    expect((await player('q'))['red_cards'], 1);
  });
  test('INT-03 invalid actions never write', () async {
    for (final a in [
      {'type': 'goal', 'team': 'A', 'player': 'p', 'assist': 'p'},
      {'type': 'goal', 'team': 'A', 'player': 'r'},
      {'type': 'goal', 'team': 'A', 'assist': 'p'},
      {'type': 'goal', 'team': 'C'},
      {'type': 'assist', 'team': 'A', 'player': 'q'},
      {'type': 'yellow', 'team': 'A'},
    ]) {
      await expectLater(repo.apply('t', 's', a), throwsStateError);
    }
    expect((await session())['score_a'], 0);
    expect(await repo.journal('t', 's'), isEmpty);
  });
  test('INT-04 wins independent from goals, no negative wins', () async {
    await db.update('sessions', {
      'session_type': 'TOURNAMENT_3',
      'score_a': null,
      'score_b': null,
    });
    await expectLater(add('win', delta: -1), throwsStateError);
    await add('win');
    await add('goal', player: 'p');
    expect((await session())['wins_a'], 1);
    expect((await session())['score_a'], isNull);
    await repo.undo('t', 's');
    expect((await session())['wins_a'], 1);
  });
  test(
    'INT-07 edit scorer and assist preserves score; correction undoable',
    () async {
      await add('goal', player: 'p', assist: 'q');
      final id = (await repo.journal('t', 's')).single['id']! as String;
      await add('goal', player: 'q', edit: id);
      expect((await session())['score_a'], 1);
      expect((await player('p'))['goals'], 0);
      expect((await player('q'))['goals'], 1);
      expect((await player('q'))['assists'], 0);
      await repo.undo('t', 's');
      expect((await player('p'))['goals'], 1);
      expect((await player('q'))['assists'], 1);
    },
  );
  test('INT-08 refuses other group, inactive, closed', () async {
    await expectLater(
      repo.apply('other', 's', {'type': 'goal', 'team': 'A'}),
      throwsStateError,
    );
    await db.delete(
      'meta',
      where: 'key = ?',
      whereArgs: ['active_session_id_t'],
    );
    await expectLater(add('goal'), throwsStateError);
    await db.insert('meta', {'key': 'active_session_id_t', 'value': 's'});
    await db.update('sessions', {'status': 'CLOSED'});
    await expectLater(add('goal'), throwsStateError);
  });
  test(
    'INT-10 external changes block undo and editing without data loss',
    () async {
      await add('goal', player: 'p');
      await db.update(
        'participations',
        {'goals': 9},
        where: 'id = ?',
        whereArgs: ['p'],
      );
      await expectLater(repo.undo('t', 's'), throwsStateError);
      final id = (await repo.journal('t', 's')).single['id']! as String;
      await expectLater(add('goal', player: 'q', edit: id), throwsStateError);
      expect((await player('p'))['goals'], 9);
    },
  );
  test('INT-09 transaction rollback includes journal', () async {
    await db.execute(
      "CREATE TRIGGER fail_stats BEFORE UPDATE ON participations BEGIN SELECT RAISE(ABORT, 'disk full'); END",
    );
    await expectLater(add('goal', player: 'p'), throwsA(anything));
    expect((await session())['score_a'], 0);
    expect(await repo.journal('t', 's'), isEmpty);
  });
  test('INT-16 new action cannot rehabilitate obsolete goals', () async {
    await add('goal', player: 'p');
    final id = (await repo.journal('t', 's')).single['id']! as String;
    await db.update(
      'participations',
      {'goals': 9},
      where: 'id = ?',
      whereArgs: ['p'],
    );
    await add('yellow', player: 'q');
    await expectLater(add('goal', player: 'q', edit: id), throwsStateError);
    expect((await player('p'))['goals'], 9);
    await repo.undo('t', 's');
    expect((await player('q'))['yellow_cards'], 0);
  });
  test('INT-09 malformed journal blocks writes', () async {
    await db.insert('meta', {'key': 'live_stats_t_s', 'value': '[{}]'});
    await expectLater(add('goal', player: 'p'), throwsStateError);
    expect((await session())['score_a'], 0);
  });
  test(
    'INT-08/14 controller denies member and SG queues aggregate payload',
    () async {
      final service = SharedService(AppDatabase.forTesting(db))
        ..identity = {
          'group_id': 't',
          'expires_at': '2099-01-01T00:00:00Z',
          'account': {
            'id': 'account',
            'roles': ['MEMBER'],
            'shared': true,
          },
        };
      final container = ProviderContainer(
        overrides: [
          activeTeamIdProvider.overrideWith(
            () => ActiveTeamIdNotifier(initialValue: 't'),
          ),
          sharedServiceProvider.overrideWith((ref) => service),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(service.dispose);
      final controller = container.read(sessionsControllerProvider);
      await expectLater(
        controller.recordLive('s', {
          'type': 'goal',
          'team': 'A',
          'player': 'p',
        }),
        throwsStateError,
      );
      expect((await session())['score_a'], 0);
      service.identity!['account'] = {
        'id': 'account',
        'roles': ['SG'],
        'shared': false,
      };
      await controller.recordLive('s', {
        'type': 'goal',
        'team': 'A',
        'player': 'p',
        'assist': 'q',
      });
      expect((await session())['score_a'], 1);
      final queued = await db.query(
        'meta',
        where: 'substr(key,1,7) = ?',
        whereArgs: ['outbox_'],
      );
      expect(queued, hasLength(1));
      expect(queued.single['value'], contains('"assists":1'));
    },
  );
}
