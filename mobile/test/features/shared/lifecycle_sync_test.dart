import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/features/shared/data/shared_service.dart';
import 'package:statoo/features/sessions/data/sessions_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('PAR22 competing offline start is recoverable and does not block the outbox', () async {
    sqfliteFfiInit();
    HttpOverrides.global =
        null; // This fixture uses its own loopback HTTP server.
    FlutterSecureStorage.setMockInitialValues({});
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    final app = AppDatabase.forTesting(db);
    await app.initSchemaForTest(db);
    final account = {
      'id': 'sg',
      'roles': ['SG'],
      'shared': false,
    };
    Map<String, dynamic> session(String id) => {
      'id': id,
      'team_id': 'g',
      'played_at': '2026-10-16T10:00:00',
      'status': 'DRAFT',
    };
    final snapshot = <String, dynamic>{
      'name': 'Test',
      'account': account,
      'members': <dynamic>[],
      'documents': {
        'sport:a': {
          'domain': 'sport',
          'occurrence_id': 'a',
          'owner': 'sg',
          'revision': 1,
          'generation': 0,
          'candidates': <dynamic>[],
          'payload': {'session': session('a'), 'participations': <dynamic>[]},
        },
      },
      'active_session_id': 'a',
    };
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var posts = 0;
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      if (request.method == 'GET')
        request.response.write(jsonEncode(snapshot));
      else {
        posts++;
        await utf8.decoder.bind(request).join();
        if (posts == 1) {
          request.response.statusCode = 409;
          request.response.write(
            jsonEncode({
              'detail': {
                'code': 'active_session_conflict',
                'active_session_id': 'a',
                'message': 'Une autre séance est déjà en cours.',
              },
            }),
          );
        } else
          request.response.write(
            jsonEncode({'status': 'accepted', 'revision': 1}),
          );
      }
      await request.response.close();
    });
    final service = SharedService(app)
      ..identity = {
        'group_id': 'g',
        'expires_at': '2099-01-01T00:00:00Z',
        'account': account,
      }
      ..baseUrl = 'http://127.0.0.1:${server.port}';
    addTearDown(() async {
      service.dispose();
      await server.close(force: true);
      await db.close();
    });
    await db.insert('teams', {
      'id': 'g',
      'name': 'Test',
      'created_at': '2026-10-16',
    });
    await db.insert('sessions', session('b'));
    await db.insert('meta', {'key': 'active_session_id_g', 'value': 'b'});
    for (final id in ['b', 'c'])
      await db.insert('meta', {
        'key': 'outbox_$id',
        'value': jsonEncode({
          'operation_id': id,
          'occurrence_id': id,
          'domain': 'sport',
          'base_revision': 0,
          'generation': 0,
          'payload': {
            'session': session(id),
            'participations': <dynamic>[],
            'is_active': id == 'b',
          },
          'reason': 'Test',
          'local_session_id': id,
          'group_id': 'g',
          'status': 'pending',
          'actor': 'sg',
        }),
      });
    await service.synchronize();
    expect(posts, 2);
    expect(
      await SqliteSessionsRepository(app).getActiveSessionId(teamId: 'g'),
      'a',
    );
    final blocked = jsonDecode(
      (await db.query(
            'meta',
            where: 'key = ?',
            whereArgs: ['outbox_b'],
          )).single['value']!
          as String,
    ) as Map;
    expect(blocked['status'], 'blocked');
    expect(
      (await db.query(
        'sessions',
        where: 'id = ?',
        whereArgs: ['b'],
      )).single['status'],
      'DRAFT',
    );
    expect((service as dynamic).syncWarning, isNotNull);
  });
}
