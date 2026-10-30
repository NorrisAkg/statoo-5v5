import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/core/data/shared_http_error.dart';
import 'package:statoo/features/shared/data/shared_service.dart';

class QueueService extends SharedService {
  QueueService(super.database);
  final sent = <Map<String, dynamic>>[];
  Future<Map<String, dynamic>> Function(Map<String, dynamic>)? post;
  Exception? getFailure;
  String remoteNotes = 'Distant';
  final Map<String, dynamic> account = {
    'id': 'writer',
    'roles': ['SG', 'TR'],
    'shared': false,
  };

  Map<String, dynamic> remoteSnapshot() => {
    'name': 'Queue',
    'account': account,
    'members': <dynamic>[],
    'active_session_id': null,
    'documents': {
      'sport:d1': {
        'domain': 'sport',
        'occurrence_id': 'd1',
        'owner': 'writer',
        'revision': 1,
        'generation': 0,
        'candidates': <dynamic>[],
        'payload': {
          'session': {
            'id': 's1',
            'team_id': 'g',
            'played_at': '2026-10-25',
            'status': 'DRAFT',
            'notes': remoteNotes,
          },
          'participations': <dynamic>[],
        },
      },
    },
  };

  @override
  Future<Map<String, dynamic>> request(
    String method,
    String path, [
    Object? body,
  ]) async {
    if (method == 'GET') {
      if (getFailure != null) throw getFailure!;
      return remoteSnapshot();
    }
    if (path == '/auth/logout') return {};
    final wire = Map<String, dynamic>.from(body! as Map);
    sent.add(wire);
    return post == null
        ? {'status': 'accepted', 'revision': 2}
        : await post!(wire);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;
  late AppDatabase app;
  late QueueService service;
  Map<String, dynamic> event(
    String id, {
    String doc = 'd1',
    String session = 's1',
    String domain = 'sport',
    String group = 'g',
    String actor = 'writer',
  }) => {
    'operation_id': id,
    'occurrence_id': doc,
    'local_session_id': session,
    'domain': domain,
    'group_id': group,
    'actor': actor,
    'status': 'pending',
    'base_revision': 0,
    'generation': 0,
    'reason': 'Correction',
    'payload': domain == 'sport'
        ? {
            'session': {
              'id': session,
              'team_id': group,
              'played_at': '2026-10-25',
              'status': 'DRAFT',
              'notes': 'Local',
            },
            'participations': <dynamic>[],
            'is_active': true,
          }
        : <String, dynamic>{},
  };
  Future<void> add(Map<String, dynamic> value) => db
      .insert('meta', {
        'key': "outbox_${value['operation_id']}",
        'value': jsonEncode(value),
      })
      .then((_) {});
  Future<Map<String, dynamic>> stored(String id) async => jsonDecode(
    (await db.query(
          'meta',
          where: 'key = ?',
          whereArgs: ['outbox_$id'],
        )).single['value']!
        as String,
  ) as Map<String, dynamic>;
  Future<String?> notes() async =>
      (await db.query(
            'sessions',
            where: 'id = ?',
            whereArgs: ['s1'],
          )).single['notes']
          as String?;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    sqfliteFfiInit();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    app = AppDatabase.forTesting(db);
    await app.initSchemaForTest(db);
    service = QueueService(app)
      ..baseUrl = 'https://example.test'
      ..token = 'synthetic';
    service.identity = {
      'group_id': 'g',
      'expires_at': '2099-01-01T00:00:00Z',
      'account': service.account,
    };
    await db.insert('teams', {
      'id': 'g',
      'name': 'Queue',
      'created_at': '2026-10-25',
    });
    await db.insert('sessions', {
      'id': 's1',
      'team_id': 'g',
      'played_at': '2026-10-25',
      'status': 'DRAFT',
      'notes': 'Local',
    });
    await db.insert('meta', {'key': 'shared_group_g', 'value': '1'});
    await db.insert('meta', {'key': 'active_session_id_g', 'value': 's1'});
  });
  tearDown(() async {
    service.dispose();
    await db.close();
  });

  for (final code in [400, 403, 404, 409, 410, 422]) {
    test(
      'QUE01 permanent $code is isolated, durable and does not lose local data',
      () async {
        final first = event('first');
        await add(first);
        await add(event('second', doc: 'd2', session: 's2', domain: 'finance'));
        service.post = (wire) async {
          if (wire['operation_id'] == 'first') {
            throw SharedApiException(code, 'Refus $code');
          }
          return {'status': 'accepted', 'revision': 1};
        };
        await service.synchronize();
        expect(service.sent.map((e) => e['operation_id']), ['first', 'second']);
        expect((await stored('first'))['status'], 'rejected');
        expect((await stored('first'))['error_status'], code);
        expect((await stored('first'))['payload'], first['payload']);
        expect((await stored('second'))['status'], 'accepted');
        expect(service.syncWarning, contains('Refus $code'));
        expect(await notes(), 'Local');
        expect(
          (await db.query(
            'meta',
            where: 'key = ?',
            whereArgs: ['active_session_id_g'],
          )).single['value'],
          's1',
        );
        await service.synchronize();
        expect(service.sent, hasLength(2));
        final restored = SharedService(app);
        addTearDown(restored.dispose);
        await restored.load();
        expect(restored.syncWarning, contains('Refus $code'));
      },
    );
  }

  for (final failure in <Exception>[
    const SharedApiException(401, 'Expired'),
    const SharedApiException(408, 'Timeout'),
    const SharedApiException(429, 'Limited'),
    const SharedApiException(503, 'Unavailable'),
    const SharedNetworkException(),
    const FormatException('Unreadable'),
  ]) {
    test(
      'QUE02 transient $failure stops safely then retries identical wire',
      () async {
        await add(event('first'));
        await add(event('second', doc: 'd2', session: 's2'));
        var notified = false;
        service.onChanged = () {
          if (service.syncWarning != null) notified = true;
        };
        service.post = (_) async => throw failure;
        await expectLater(service.synchronize(), throwsA(same(failure)));
        expect(service.sent, hasLength(1));
        expect((await stored('first'))['status'], 'pending');
        expect((await stored('first'))['error'], isNotNull);
        expect(service.syncWarning, isNotNull);
        expect(notified, isTrue);
        final wire = jsonEncode(service.sent.single);
        service.post = null;
        await service.synchronize();
        expect(jsonEncode(service.sent[1]), wire);
        expect(service.sent.last['operation_id'], 'second');
        expect((await stored('first')).containsKey('error'), isFalse);
        expect(service.syncWarning, isNull);
      },
    );
  }

  test('QUE03/04 dependent correction waits one pass then acknowledgement releases import', () async {
    await add(event('first'));
    await add(event('correction'));
    await add(event('independent', doc: 'd2', session: 's2'));
    service.post = (wire) async {
      if (wire['operation_id'] == 'first') {
        throw const SharedApiException(422, 'Invalid');
      }
      if (wire['operation_id'] == 'correction') service.remoteNotes = 'Publié';
      return {'status': 'accepted', 'revision': 2};
    };
    await service.synchronize();
    expect(service.sent.map((e) => e['operation_id']), [
      'first',
      'independent',
    ]);
    expect((await stored('correction'))['status'], 'pending');
    expect(service.syncWarning, contains('Invalid'));
    expect(await notes(), 'Local');
    await service.synchronize();
    expect(service.sent.last['operation_id'], 'correction');
    expect((await stored('first'))['status'], 'rejected');
    expect(await notes(), 'Publié');
    expect(service.syncWarning, isNull);
    expect(
      await db.query(
        'meta',
        where: 'key = ?',
        whereArgs: ['active_session_id_g'],
      ),
      isEmpty,
    );
  });

  test(
    'QUE05 rejected financial draft survives remote finance import',
    () async {
      await add(event('finance', session: 'f1', domain: 'finance'));
      await db.insert('meta', {
        'key': 'finance_point_g_f1',
        'value': jsonEncode({
          'played_at': '2026-10-25',
          'lines': <dynamic>[],
          'rate': 200,
        }),
      });
      await db.insert('meta', {
        'key': 'shared_finance_alias_g_d1',
        'value': 'f1',
      });
      service.post = (_) async =>
          throw const SharedApiException(422, 'Bad finance');
      // Import the matching remote financial document after its rejection.
      await service.synchronize();
      expect((await stored('finance'))['status'], 'rejected');
      final snapshot = service.remoteSnapshot();
      (snapshot['documents'] as Map)['finance:d1'] = {
        'domain': 'finance',
        'occurrence_id': 'd1',
        'owner': 'writer',
        'revision': 1,
        'generation': 0,
        'payload': {
          'played_at': '2026-10-25',
          'lines': <dynamic>[],
          'rate': 100,
        },
      };
      await service.importSnapshot(snapshot);
      final value = (await db.query(
        'meta',
        where: 'key = ?',
        whereArgs: ['finance_point_g_f1'],
      )).single['value'];
      expect((jsonDecode(value! as String) as Map)['rate'], 200);
    },
  );

  test('QUE07 foreign group and author are never sent or changed', () async {
    final foreign = [
      event('other-group', group: 'other'),
      event('other-actor', actor: 'other'),
    ];
    for (final item in foreign) {
      await add(item);
    }
    await service.synchronize();
    expect(service.sent, isEmpty);
    for (final item in foreign) {
      expect(await stored(item['operation_id'] as String), item);
    }
  });

  test('QUE05 acknowledgement from another author does not discard a rejected draft', () async {
    await add(event('other-refused', actor: 'other')..['status'] = 'rejected');
    await add(event('own-accepted')..['status'] = 'accepted');
    await service.synchronize();
    expect(await notes(), 'Local');
    expect(service.syncWarning, isNull);
    expect(service.sent, isEmpty);
  });

  test(
    'QUE09 initial snapshot failure notifies without touching the outbox',
    () async {
      final pending = event('first');
      await add(pending);
      service.getFailure = const SharedNetworkException();
      var notified = false;
      service.onChanged = () {
        notified = service.syncWarning != null;
      };
      await expectLater(
        service.synchronize(),
        throwsA(isA<SharedNetworkException>()),
      );
      expect(await stored('first'), pending);
      expect(service.sent, isEmpty);
      expect(notified, isTrue);
    },
  );
}
