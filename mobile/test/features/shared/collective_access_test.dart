import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/core/data/shared_http_error.dart';
import 'package:statoo/features/shared/data/shared_service.dart';
import 'package:statoo/features/shared/data/collective_access.dart';

class FakeShared extends SharedService {
  FakeShared() : super(AppDatabase()) {
    baseUrl = 'https://example.test';
    identity = {
      'group_id': '#12345678',
      'expires_at': DateTime.now()
          .add(const Duration(days: 1))
          .toIso8601String(),
      'account': {
        'id': 'admin',
        'roles': ['ADMIN'],
        'shared': false,
      },
    };
  }
  String password = 'Members-2026';
  String username = 'members';
  Object? failure;
  Completer<void>? pending;
  int requests = 0;
  @override
  Future<Map<String, dynamic>> request(
    String method,
    String path, [
    Object? body,
  ]) async {
    requests++;
    await pending?.future;
    if (failure != null) throw failure!;
    if (path == '/auth/logout') return {};
    if ((body as Map)['password'] != password)
      throw const SharedApiException(400, 'Incorrect');
    return {'verified': true, 'group_id': groupId, 'username': username};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeShared service;
  late CollectiveAccess access;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    service = FakeShared();
    access = CollectiveAccess(service, '#12345678');
  });
  test('ACC01/04/05 remembers verified access across instances and checks current username on copy', () async {
    await access.remember('Members-2026');
    expect(await CollectiveAccess(service, '#12345678').hasSaved(), isTrue);
    service.username = 'new-members';
    final text = await access.copyText('Atlas');
    expect(text, contains('Atlas'));
    expect(text, contains('#12345678'));
    expect(text, contains('new-members'));
    expect(text, contains('Members-2026'));
    expect(service.requests, 2);
  });
  test(
    'ACC02 wrong reentry preserves previous value; invalid bounds never saved',
    () async {
      for (final value in ['', 'short', 'x' * 201]) {
        await expectLater(access.remember(value), throwsA(isA<Exception>()));
      }
      await access.remember('Members-2026');
      await expectLater(
        access.remember('Wrong-2026'),
        throwsA(isA<Exception>()),
      );
      expect(await access.hasSaved(), isTrue);
    },
  );
  test(
    'ACC03 isolates group, account, server and expired identities',
    () async {
      await access.remember('Members-2026');
      expect(await CollectiveAccess(service, 'other').hasSaved(), isFalse);
      service.baseUrl = 'https://other.test';
      expect(await access.hasSaved(), isFalse);
      service.baseUrl = 'https://example.test';
      (service.identity!['account'] as Map)['id'] = 'another';
      expect(await access.hasSaved(), isFalse);
      (service.identity!['account'] as Map)['roles'] = ['SG'];
      expect(access.allowed, isFalse);
      await expectLater(access.copyText('Atlas'), throwsA(isA<Exception>()));
      (service.identity!['account'] as Map)['roles'] = ['ADMIN'];
      (service.identity!['account'] as Map)['shared'] = true;
      expect(access.allowed, isFalse);
      (service.identity!['account'] as Map)['shared'] = false;
      service.identity!['expires_at'] = '2000-01-01';
      expect(access.allowed, isFalse);
    },
  );
  test('ACC06/07 network retains cached value; rotation discards it', () async {
    await access.remember('Members-2026');
    service.failure = const SharedNetworkException();
    await expectLater(
      access.copyText('Atlas'),
      throwsA(isA<SharedNetworkException>()),
    );
    expect(await access.hasSaved(), isTrue);
    service.failure = null;
    service.password = 'Changed-2026';
    await expectLater(access.copyText('Atlas'), throwsA(isA<Exception>()));
    expect(await access.hasSaved(), isFalse);
  });
  test('ACC08 changed context while verifying never stores password', () async {
    service.pending = Completer<void>();
    final operation = access.remember('Members-2026');
    service.baseUrl = 'https://other.test';
    service.pending!.complete();
    await expectLater(operation, throwsA(isA<Exception>()));
    service.baseUrl = 'https://example.test';
    expect(await access.hasSaved(), isFalse);
  });
  test('ACC09 forget and logout remove device secret', () async {
    await access.remember('Members-2026');
    await access.forget();
    expect(await access.hasSaved(), isFalse);
    await access.remember('Members-2026');
    await service.disconnect();
    final restored = FakeShared();
    expect(await CollectiveAccess(restored, '#12345678').hasSaved(), isFalse);
  });
  test('ACC09 logout leaves another server cache intact', () async {
    await access.remember('Members-2026');
    final other = FakeShared()..baseUrl = 'https://other.test';
    final otherAccess = CollectiveAccess(other, '#12345678');
    await otherAccess.remember('Members-2026');
    await service.disconnect();
    expect(await otherAccess.hasSaved(), isTrue);
  });
  for (final code in [401, 403]) {
    test(
      'ACC06 authorization refusal $code discards stale credentials',
      () async {
        await access.remember('Members-2026');
        service.failure = SharedApiException(code, 'Denied');
        await expectLater(
          access.copyText('Atlas'),
          throwsA(isA<SharedApiException>()),
        );
        service.failure = null;
        expect(await access.hasSaved(), isFalse);
      },
    );
  }
}
