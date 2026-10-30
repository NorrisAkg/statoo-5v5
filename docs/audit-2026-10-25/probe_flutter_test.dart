import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/core/data/shared_http_error.dart';
import 'package:statoo/features/settings/domain/backup_payload.dart';
import 'package:statoo/features/shared/data/shared_service.dart';

class OfflineService extends SharedService {
  OfflineService() : super(AppDatabase()) {
    identity = {'group_id': 'audit', 'account': {'id': 'audit'}};
    token = 'fake-audit-token';
  }
  @override
  Future<Map<String,dynamic>> request(String method,String path,[Object? body]) async {
    throw const SharedNetworkException();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('AUD-09 future backup version must be rejected', () {
    expect(() => BackupPayload.fromJson({
      'app':'statoo_5v5', 'version':999,
      'team': {'id':'audit','name':'Audit'},
    }), throwsFormatException);
  });
  test('AUD-11 offline disconnect must erase local token and identity', () async {
    FlutterSecureStorage.setMockInitialValues({'statoo_connection':'fake-audit-connection'});
    final service = OfflineService();
    try { await service.disconnect(); } catch (_) {}
    expect(service.token, isNull, reason:'local token must not depend on network logout');
    expect(service.identity,isNull);
    expect(await service.storage.read(key:'statoo_connection'),isNull);
  });
  test('AUD-10 actual v6 to v8 migration preserves participations', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
    final temp = await Directory.systemTemp.createTemp('statoo-audit-migration-');
    await databaseFactory.setDatabasesPath(temp.path);
    final path = '${temp.path}/statoo.db';
    final old = await databaseFactory.openDatabase(path, options: OpenDatabaseOptions(version:6));
    // Exact table/view statements from historical commit 1a3af10 (schema v6).
    // The first audit fixture based on v8 was excluded: it included newer triggers.
    final sql = jsonDecode(await File('../docs/audit-2026-10-25/historical-v6-schema.json').readAsString()) as List;
    for (final statement in sql) { await old.execute(statement as String); }
    await old.insert('teams', {'id':'t','name':'Audit','created_at':'2026-10-25'});
    await old.insert('players', {'id':'p','team_id':'t','name':'Audit','created_at':'2026-10-25','updated_at':'2026-10-25'});
    await old.insert('sessions', {'id':'s','team_id':'t','played_at':'2026-10-25','status':'DRAFT'});
    await old.insert('participations', {'id':'pt','session_id':'s','player_id':'p','team':'A'});
    await old.close();
    try {
      final upgraded = await AppDatabase.instance.database;
      expect(await upgraded.query('participations'),hasLength(1));
      expect(await upgraded.rawQuery('PRAGMA foreign_key_check'),isEmpty);
      await upgraded.close();
    } finally {
      // Only the disposable audit directory is removed.
      await temp.delete(recursive:true);
    }
  });
}
