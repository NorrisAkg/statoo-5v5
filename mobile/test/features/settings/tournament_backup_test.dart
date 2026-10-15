import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/features/settings/data/backup_service.dart';
import 'package:statoo/features/settings/domain/backup_payload.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  late Database db;
  late BackupService service;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    final app = AppDatabase.forTesting(db);
    await app.initSchemaForTest(db);
    service = BackupService(app);
  });
  tearDown(() => db.close());

  final outcomes = <String, List<int>>{
    'A': [3, 1, 0],
    'B': [1, 3, 0],
    'C': [0, 1, 3],
    'DRAW_AB': [2, 2, 0],
    'DRAW_AC': [2, 0, 2],
    'DRAW_BC': [0, 2, 2],
    'DRAW_ALL': [2, 2, 2],
  };
  for (final entry in outcomes.entries) {
    for (final merge in [false, true]) {
      test('UX07-01/02/11 restores ${entry.key}, merge=$merge', () async {
        await service.restoreBackup(
          _payload(entry.key, entry.value),
          merge: merge,
        );
        final session = (await db.query('sessions')).single;
        expect(session['status'], 'CLOSED');
        expect(session['session_type'], 'TOURNAMENT_3');
        expect(session['result'], entry.key);
        expect([
          session['wins_a'],
          session['wins_b'],
          session['wins_c'],
        ], entry.value);
        expect(session['score_a'], isNull);
        expect(
          session['team_names'],
          '{"A":"Lions","B":"Aigles","C":"Tigres"}',
        );
        expect((await db.query('participations')).single['team'], 'A');
      });
    }
  }
  test(
    'UX07-12 export/restore preserves ranked results and financial metadata',
    () async {
      await service.restoreBackup(_payload('A', [3, 1, 0]), merge: false);
      await db.insert('meta', {
        'key': 'finance_point_g_s',
        'value': 'unchanged',
      });
      final before = await db.query('v_player_match_results');
      expect(before.single['points'], 3);
      final exported = await service.createBackupPayload();
      await service.restoreBackup(exported, merge: false);
      expect(await db.query('v_player_match_results'), before);
      expect(
        (await db.query(
          'meta',
          where: 'key = ?',
          whereArgs: ['finance_point_g_s'],
        )).single['value'],
        'unchanged',
      );
    },
  );
  test(
    'UX07-07 inconsistent tournament is kept as draft without invented result',
    () async {
      final result = await service.restoreBackup(
        _payload('B', [3, 1, 0]),
        merge: false,
      );
      expect(result.normalizedSessionsCount, 1);
      final restored = (await db.query('sessions')).single;
      expect(restored['status'], 'DRAFT');
      expect(restored['result'], 'B');
      expect(restored['wins_a'], 3);
    },
  );
  test(
    'UX07-05/06 classic scored remains closed, incomplete becomes draft',
    () async {
      for (final scored in [false, true]) {
        final payload = _payload('A', [3, 1, 0]);
        payload.sessions.single.addAll({
          'session_type': 'CLASSIC_2',
          'score_a': scored ? 2 : null,
          'score_b': 1,
        });
        await service.restoreBackup(payload, merge: false);
        expect(
          (await db.query('sessions')).single['status'],
          scored ? 'CLOSED' : 'DRAFT',
        );
      }
    },
  );
}

BackupPayload _payload(String result, List<int> wins) => BackupPayload(
  version: 2,
  exportedAt: DateTime(2026, 10, 14),
  team: const {'id': 'g', 'name': 'Groupe', 'created_at': '2026-10-01'},
  players: const [
    {
      'id': 'p',
      'team_id': 'g',
      'name': 'Alice',
      'created_at': '2026-10-01',
      'updated_at': '2026-10-01',
    },
  ],
  sessions: [
    {
      'id': 's',
      'team_id': 'g',
      'played_at': '2026-10-14T18:00:00',
      'status': 'CLOSED',
      'is_ranked': 1,
      'session_type': 'TOURNAMENT_3',
      'wins_a': wins[0],
      'wins_b': wins[1],
      'wins_c': wins[2],
      'result': result,
      'team_names': '{"A":"Lions","B":"Aigles","C":"Tigres"}',
    },
  ],
  participations: const [
    {'id': 'pt', 'session_id': 's', 'player_id': 'p', 'team': 'A'},
  ],
);
