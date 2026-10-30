import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/features/sessions/data/sessions_repository.dart';
import 'package:statoo/features/sessions/domain/participation.dart';
import 'package:statoo/features/sessions/domain/session.dart';
import 'package:statoo/features/sessions/domain/team_appearance.dart';
import 'package:statoo/features/shared/data/shared_service.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  test(
    'WEB-41 imports a real PWA wire fixture into the unchanged mobile schema',
    () async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      final app = AppDatabase.forTesting(db);
      await app.initSchemaForTest(db);
      final service = SharedService(app)
        ..identity = {
          'group_id': 'g',
          'expires_at': '2099-01-01T00:00:00Z',
          'account': {
            'id': 'me',
            'roles': ['MEMBER'],
            'shared': true,
          },
        };
      addTearDown(() async {
        service.dispose();
        await db.close();
      });
      final fixture = jsonDecode(
        await File('../web/tests/fixtures/mobile-snapshot.json').readAsString(),
      ) as Map<String, dynamic>;
      fixture['sport_settings'] = {'min_players_per_session': 8};
      await service.importSnapshot(fixture);
      expect(
        (await db.query('meta', where: 'key = ?', whereArgs: ['min_players_per_session_g'])).single['value'],
        '8',
      );
      final repo = SqliteSessionsRepository(app);
      final session = (await repo.getSession('pwa-s', teamId: 'g'))!;
      expect(session.sessionType, SessionType.tournament3);
      expect(session.status, SessionStatus.closed);
      expect(session.teamName(Team.c), 'Sporting Atlas');
      expect(session.teamColors['C'], 0xff22c55e);
      expect(session.isRanked, isTrue);
      expect(
        (await repo.getSessionParticipants('pwa-s', teamId: 'g')).length,
        3,
      );
      expect(
        (await db.query(
          'participations',
          where: 'team = ?',
          whereArgs: ['C'],
        )).single['goals'],
        3,
      );
      // PAR21: a session started on the other platform stays active here.
      fixture['active_session_id'] = 'pwa-s';
      final documents = fixture['documents'] as Map<String, dynamic>;
      for (final raw in documents.values) {
        final document = raw as Map<String, dynamic>;
        if (document['domain'] == 'sport') {
          final payload = document['payload'] as Map<String, dynamic>?;
          final sessionMap = payload?['session'] as Map<String, dynamic>?;
          if (sessionMap != null) {
            sessionMap['status'] = 'DRAFT';
          }
        }
      }
      await service.importSnapshot(fixture);
      expect(await repo.getActiveSessionId(teamId: 'g'), 'pwa-s');
      await service.queueSport('g', 'pwa-s');
      final pending = await db.query('meta', where: 'substr(key,1,7) = ?', whereArgs: ['outbox_']);
      final queued = jsonDecode(pending.single['value']! as String) as Map<String, dynamic>;
      final queuedPayload = queued['payload'] as Map<String, dynamic>;
      expect(queuedPayload['is_active'], isTrue);
      final queuedSession = queuedPayload['session'] as Map<String, dynamic>;
      expect(queuedSession.containsKey('is_active'), isFalse);
      fixture['active_session_id'] = null;
      await service.importSnapshot(fixture);
      expect(await repo.getActiveSessionId(teamId: 'g'), 'pwa-s', reason: 'A pending local sport mutation must not be overwritten');
      await db.delete('meta', where: 'substr(key,1,7) = ?', whereArgs: ['outbox_']);
      await service.importSnapshot(fixture);
      expect(await repo.getActiveSessionId(teamId: 'g'), isNull);
    },
  );
}
