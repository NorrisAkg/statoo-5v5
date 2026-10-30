import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/features/players/data/players_repository.dart';
import 'package:statoo/features/shared/data/shared_service.dart';

void main() {
  late Database db;
  late AppDatabase app;
  late SharedService service;
  late SqlitePlayersRepository players;
  Map<String, dynamic> member(String id, String name) => {
    'id': id,
    'name': name,
    'nickname': 'Surnom',
    'avatar_url': 'avatar',
    'is_active': 1,
    'created_at': '2026-10-01T10:00:00',
    'updated_at': '2026-10-01T10:00:00',
  };
  Map<String, dynamic> snapshot(List<Map<String, dynamic>> members) => {
    'name': 'Groupe',
    'members': members,
    'documents': <String, dynamic>{},
  };
  Future<Map<String, Object?>> alice() async =>
      (await db.query('players', where: 'id = ?', whereArgs: ['a'])).single;
  SharedService newService() =>
      SharedService(app)..identity = {'group_id': 'g'};
  setUp(() async {
    sqfliteFfiInit();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    app = AppDatabase.forTesting(db);
    await app.initSchemaForTest(db);
    players = SqlitePlayersRepository(app);
    service = newService();
    await service.importSnapshot(snapshot([member('a', 'Alice')]));
  });
  tearDown(() async {
    service.dispose();
    await db.close();
  });
  test(
    'MEM01 repeated imports retain rename, cleared nickname and archive',
    () async {
      await players.updatePlayer(id: 'a', teamId: 'g', name: 'Alice corrigée');
      await players.togglePlayerActive(id: 'a', teamId: 'g', isActive: false);
      final local = await alice();
      await service.importSnapshot(snapshot([member('a', 'Alice')]));
      await service.importSnapshot(snapshot([member('a', 'Alice')]));
      expect(await alice(), local);
    },
  );
  test(
    'MEM02 clean fields and other members still receive remote updates',
    () async {
      await players.updatePlayer(
        id: 'a',
        teamId: 'g',
        name: 'Local',
        nickname: 'Surnom',
      );
      await service.importSnapshot(
        snapshot([
          member('a', 'Alice')..['nickname'] = 'Distant',
          member('b', 'Bob'),
        ]),
      );
      expect((await alice())['name'], 'Local');
      expect((await alice())['nickname'], 'Distant');
      expect(
        (await db.query(
          'players',
          where: 'id = ?',
          whereArgs: ['b'],
        )).single['name'],
        'Bob',
      );
    },
  );
  test(
    'MEM03 conflicting remote edits never overwrite the local field',
    () async {
      await players.updatePlayer(id: 'a', teamId: 'g', name: 'Local');
      final remote = snapshot([member('a', 'Distant')]);
      await service.importSnapshot(remote);
      await service.importSnapshot(remote);
      expect((await alice())['name'], 'Local');
    },
  );
  test(
    'MEM04 remote acknowledgement releases the field for later changes',
    () async {
      await players.updatePlayer(
        id: 'a',
        teamId: 'g',
        name: 'Publié',
        nickname: 'Surnom',
      );
      await service.importSnapshot(snapshot([member('a', 'Publié')]));
      await service.importSnapshot(
        snapshot([member('a', 'Après publication')]),
      );
      expect((await alice())['name'], 'Après publication');
    },
  );
  test(
    'MEM05 persisted baseline protects edits after service recreation',
    () async {
      await players.updatePlayer(id: 'a', teamId: 'g', name: 'Local');
      service.dispose();
      service = newService();
      await service.importSnapshot(snapshot([member('a', 'Alice')]));
      expect((await alice())['name'], 'Local');
    },
  );
  test(
    'MEM06 local and remote additions coexist and other groups stay intact',
    () async {
      final local = await players.createPlayer(name: 'Local', teamId: 'g');
      await db.insert('teams', {
        'id': 'other',
        'name': 'Other',
        'format': '5v5',
        'created_at': '2026-10-01',
      });
      await db.insert('players', {
        ...member('other-player', 'Other'),
        'team_id': 'other',
      });
      final foreign = await db.query(
        'players',
        where: 'team_id = ?',
        whereArgs: ['other'],
      );
      await service.importSnapshot(
        snapshot([member('a', 'Alice'), member('b', 'Bob')]),
      );
      expect(
        await db.query('players', where: 'id = ?', whereArgs: [local.id]),
        hasLength(1),
      );
      expect(
        await db.query('players', where: 'id = ?', whereArgs: ['b']),
        hasLength(1),
      );
      expect(
        await db.query('players', where: 'team_id = ?', whereArgs: ['other']),
        foreign,
      );
    },
  );
  test(
    'MEM07 unchanged fields import remote values and optional defaults',
    () async {
      await service.importSnapshot(
        snapshot([
          {'id': 'a', 'name': 'Distant'},
        ]),
      );
      final row = await alice();
      expect(row['name'], 'Distant');
      expect(row['nickname'], isNull);
      expect(row['avatar_url'], isNull);
      expect(row['is_active'], 1);
    },
  );
  test('MEM08 foreign ID rolls back rows and persisted baseline', () async {
    final before = await db.query(
      'meta',
      where: 'key = ?',
      whereArgs: ['shared_snapshot_g'],
    );
    service.identity = {'group_id': 'other'};
    await expectLater(
      service.importSnapshot(snapshot([member('a', 'Collision')])),
      throwsStateError,
    );
    expect((await alice())['name'], 'Alice');
    expect(
      await db.query('teams', where: 'id = ?', whereArgs: ['other']),
      isEmpty,
    );
    expect(
      await db.query(
        'meta',
        where: 'key = ?',
        whereArgs: ['shared_snapshot_g'],
      ),
      before,
    );
    expect(
      await db.query(
        'meta',
        where: 'key = ?',
        whereArgs: ['shared_snapshot_other'],
      ),
      isEmpty,
    );
  });
  test(
    'MEM11 boolean web activity stays compatible with SQLite integers',
    () async {
      await service.importSnapshot(
        snapshot([member('a', 'Alice')..['is_active'] = true]),
      );
      await service.importSnapshot(
        snapshot([member('a', 'Alice')..['is_active'] = false]),
      );
      expect((await alice())['is_active'], 0);
      await service.importSnapshot(
        snapshot([member('a', 'Alice')..['is_active'] = true]),
      );
      expect((await alice())['is_active'], 1);
    },
  );
  test('MEM09 locally changed avatar survives a remote conflict', () async {
    await db.update(
      'players',
      {'avatar_url': 'local-avatar'},
      where: 'id = ?',
      whereArgs: ['a'],
    );
    await service.importSnapshot(
      snapshot([member('a', 'Alice')..['avatar_url'] = 'remote-avatar']),
    );
    expect((await alice())['avatar_url'], 'local-avatar');
  });
  test(
    'MEM10 omitted optional baseline fields do not freeze remote updates',
    () async {
      await service.importSnapshot(
        snapshot([
          {'id': 'a', 'name': 'Alice'},
        ]),
      );
      await service.importSnapshot(
        snapshot([member('a', 'Alice')..['is_active'] = 0]),
      );
      final row = await alice();
      expect(row['nickname'], 'Surnom');
      expect(row['avatar_url'], 'avatar');
      expect(row['is_active'], 0);
    },
  );
}
