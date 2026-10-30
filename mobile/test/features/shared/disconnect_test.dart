import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/core/data/shared_http_error.dart';
import 'package:statoo/features/shared/data/collective_access_key.dart';
import 'package:statoo/features/shared/data/shared_service.dart';

class ControlledStorage extends FlutterSecureStorage {
  Completer<void>? writeStarted;
  Completer<void>? writeRelease;
  Completer<void>? readStarted;
  Completer<void>? readRelease;
  bool refuseDelete = false;

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (key == 'statoo_connection' && writeRelease != null) {
      if (!writeStarted!.isCompleted) writeStarted!.complete();
      await writeRelease!.future;
    }
    await super.write(key: key, value: value);
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    final value = await super.read(key: key);
    if (key == 'statoo_connection' &&
        readRelease != null &&
        !readStarted!.isCompleted) {
      readStarted!.complete();
      await readRelease!.future;
    }
    return value;
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (refuseDelete) throw PlatformException(code: 'storage-denied');
    await super.delete(key: key);
  }
}

class DisconnectService extends SharedService {
  DisconnectService(super.database, {required super.storage});
  final calls = <({String method, String path, String? token})>[];
  Future<Map<String, dynamic>> Function(String, String)? respond;
  bool timerProbe = false;
  int automaticCalls = 0;

  @override
  Future<Map<String, dynamic>> request(
    String method,
    String path, [
    Object? body,
  ]) async {
    calls.add((method: method, path: path, token: token));
    return respond == null ? <String, dynamic>{} : await respond!(method, path);
  }

  @override
  Future<void> synchronize() async {
    if (timerProbe) {
      automaticCalls++;
      return;
    }
    await super.synchronize();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;
  late AppDatabase app;
  late ControlledStorage storage;
  late DisconnectService service;
  late String accessKey;
  final account = {
    'id': 'admin',
    'roles': ['ADMIN'],
    'shared': false,
  };
  Map<String, dynamic> identity() => {
    'group_id': 'g',
    'expires_at': '2099-01-01T00:00:00Z',
    'account': account,
  };
  Map<String, dynamic> snapshot() => {
    'name': 'Group',
    'account': account,
    'members': <dynamic>[],
    'documents': <String, dynamic>{},
  };

  Future<void> assertCleared() async {
    expect(service.connected, isFalse);
    expect(service.identity, isNull);
    expect(service.token, isNull);
    expect(service.baseUrl, isNull);
    expect(service.snapshot, isNull);
    expect(service.syncWarning, isNull);
    expect(await storage.read(key: 'statoo_connection'), isNull);
    expect(await storage.read(key: accessKey), isNull);
    expect(await storage.read(key: '${accessKey}_manager_one'), isNull);
  }

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    sqfliteFfiInit();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    app = AppDatabase.forTesting(db);
    await app.initSchemaForTest(db);
    storage = ControlledStorage();
    service = DisconnectService(app, storage: storage)
      ..identity = identity()
      ..token = 'synthetic-token'
      ..baseUrl = 'https://example.test'
      ..snapshot = snapshot()
      ..syncWarning = 'Old warning';
    service.protectedGroups.add('g');
    accessKey = collectiveAccessKey(service.baseUrl, 'g', 'admin')!;
    await storage.write(
      key: 'statoo_connection',
      value: jsonEncode({
        'identity': identity(),
        'url': service.baseUrl,
        'token': service.token,
      }),
    );
    await storage.write(key: accessKey, value: 'synthetic-collective');
    await storage.write(
      key: '${accessKey}_manager_one',
      value: 'synthetic-manager',
    );
    await db.insert('meta', {'key': 'shared_group_g', 'value': '1'});
  });
  tearDown(() async {
    service.dispose();
    await db.close();
  });

  test(
    'OUT01 successful logout clears local state and uses the previous token',
    () async {
      await service.disconnect();
      await assertCleared();
      expect(service.calls.single.path, '/auth/logout');
      expect(service.calls.single.token, 'synthetic-token');
    },
  );

  for (final failure in <Exception>[
    const SharedNetworkException(),
    const SharedApiException(401, 'Expired'),
    const SharedApiException(403, 'Forbidden'),
    const SharedApiException(500, 'Unavailable'),
    const FormatException('Invalid remote response'),
  ]) {
    test(
      'OUT02/03 remote failure $failure does not prevent durable logout',
      () async {
        service.respond = (_, _) async => throw failure;
        await service.disconnect();
        await assertCleared();
        final restored = SharedService(app, storage: storage);
        addTearDown(restored.dispose);
        await restored.load();
        expect(restored.connected, isFalse);
        expect(restored.canWrite('g', 'members'), isFalse);
      },
    );
  }

  test(
    'OUT04 local logout finishes while remote revocation is suspended',
    () async {
      final remote = Completer<Map<String, dynamic>>();
      service.respond = (_, _) => remote.future;
      var finished = false;
      final operation = service.disconnect().then((_) => finished = true);
      // Drain ordinary futures without completing the remote request.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(finished, isTrue);
      remote.complete({});
      await operation;
      await assertCleared();
    },
  );

  test(
    'OUT05 other contexts, local data and protected outbox survive',
    () async {
      final otherKeys = [
        collectiveAccessKey('https://other.test', 'g', 'admin')!,
        collectiveAccessKey('https://example.test', 'other', 'admin')!,
        collectiveAccessKey('https://example.test', 'g', 'other')!,
      ];
      for (final key in otherKeys) {
        await storage.write(key: key, value: 'keep');
      }
      await db.insert('meta', {
        'key': 'outbox_draft',
        'value': '{"status":"pending"}',
      });
      final before = await db.query('meta');
      await service.disconnect();
      expect(await db.query('meta'), before);
      for (final key in otherKeys) {
        expect(await storage.read(key: key), 'keep');
      }
      await expectLater(service.requireWrite('g', 'members'), throwsStateError);
    },
  );

  testWidgets('OUT06 repeated logout cancels the automatic timer', (
    tester,
  ) async {
    service
      ..timerProbe = true
      ..startAutomaticSync();
    await tester.runAsync(() async {
      await service.disconnect();
      await service.disconnect();
    });
    await tester.pump(const Duration(seconds: 46));
    expect(service.automaticCalls, 0);
    expect(service.calls, hasLength(1));
    await tester.runAsync(db.close);
  });

  for (final pausedGet in [1, 2]) {
    test(
      'OUT07 late snapshot GET $pausedGet cannot revive credentials',
      () async {
        final entered = Completer<void>();
        final remote = Completer<Map<String, dynamic>>();
        var gets = 0;
        service.respond = (method, path) async {
          if (method == 'GET') {
            gets++;
            if (gets == pausedGet) {
              entered.complete();
              return await remote.future;
            }
            return snapshot();
          }
          return {};
        };
        final syncing = service.synchronize();
        await entered.future;
        await service.disconnect();
        remote.complete(snapshot());
        await syncing;
        await assertCleared();
        expect(service.calls.where((c) => c.path.endsWith('/sync')), isEmpty);
      },
    );
  }

  test(
    'OUT08 pending secure write cannot resurrect the saved connection',
    () async {
      service.respond = (_, _) async => snapshot();
      storage
        ..writeStarted = Completer<void>()
        ..writeRelease = Completer<void>();
      final syncing = service.synchronize();
      await storage.writeStarted!.future;
      final disconnecting = service.disconnect();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      storage.writeRelease!.complete();
      await Future.wait([syncing, disconnecting]);
      await assertCleared();
    },
  );

  test('OUT09 late login response is cancelled by logout', () async {
    service.identity = null;
    final entered = Completer<void>();
    final login = Completer<Map<String, dynamic>>();
    service.respond = (_, _) {
      entered.complete();
      return login.future;
    };
    final connecting = service.connect(
      'https://example.test',
      'g',
      'admin',
      'synthetic-password',
    );
    final cancelled = expectLater(connecting, throwsStateError);
    await entered.future;
    await service.disconnect();
    login.complete({...identity(), 'token': 'late-token'});
    await cancelled;
    expect(service.connected, isFalse);
    expect(await storage.read(key: 'statoo_connection'), isNull);
  });

  test('OUT09 late initial load cannot restore the old connection', () async {
    service.identity = null;
    storage
      ..readStarted = Completer<void>()
      ..readRelease = Completer<void>();
    final loading = service.load();
    await storage.readStarted!.future;
    await service.disconnect();
    storage.readRelease!.complete();
    await loading;
    await assertCleared();
  });

  test(
    'OUT11 notification failure cannot interrupt credential deletion',
    () async {
      service.onChanged = () => throw StateError('Listener failed');
      await expectLater(service.disconnect(), throwsStateError);
      await assertCleared();
    },
  );

  test(
    'OUT12 old synchronization cannot overwrite a fresh connection',
    () async {
      final entered = Completer<void>();
      final remote = Completer<Map<String, dynamic>>();
      service.respond = (_, _) {
        if (!entered.isCompleted) entered.complete();
        return remote.future;
      };
      final syncing = service.synchronize();
      await entered.future;
      await service.disconnect();
      service.respond = (_, _) async => {...identity(), 'token': 'new-token'};
      await service.connect(
        'https://example.test',
        'g',
        'admin',
        'synthetic-password',
      );
      remote.complete(snapshot());
      await syncing;
      expect(service.connected, isTrue);
      expect(service.token, 'new-token');
      final saved =
          jsonDecode((await storage.read(key: 'statoo_connection'))!) as Map;
      expect(saved['token'], 'new-token');
    },
  );

  test(
    'OUT10 storage deletion failure is surfaced after memory is cleared',
    () async {
      storage.refuseDelete = true;
      await expectLater(
        service.disconnect(),
        throwsA(isA<PlatformException>()),
      );
      expect(service.connected, isFalse);
      expect(service.token, isNull);
      expect(await storage.read(key: 'statoo_connection'), isNotNull);
    },
  );
}
