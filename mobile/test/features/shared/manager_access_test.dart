import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:statoo/features/shared/data/collective_access.dart';
import 'package:statoo/features/shared/data/manager_password.dart';

import 'collective_access_test.dart' show FakeShared;

class ManagerService extends FakeShared {
  final paths = <String>[];
  final passwords = <String, String>{};
  @override
  Future<Map<String, dynamic>> request(
    String method,
    String path, [
    Object? body,
  ]) async {
    paths.add(path);
    if (path.contains('/accounts/')) {
      final id = path.split('/accounts/').last.split('/').first;
      final supplied = (body! as Map)['password'] as String;
      if (!path.endsWith('/verify')) passwords[id] = supplied;
      if (passwords[id] != supplied) throw Exception('Wrong password');
      return {'verified': true, 'group_id': groupId, 'username': 'user-$id'};
    }
    return super.request(method, path, body);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('GES01 secure generated passwords always meet 8 character contract', () {
    final generated = List.generate(200, (_) => generateManagerPassword());
    for (final value in generated) {
      expect(value, matches(r'^[A-Za-z0-9]{8}$'));
      expect(value, matches('[a-z]'));
      expect(value, matches('[A-Z]'));
      expect(value, matches('[0-9]'));
    }
    expect(generated.toSet().length, 200);
  });
  test('GES02/07 targets and collective secret remain isolated; copy current manager login', () async {
    final service = ManagerService()
      ..passwords['a'] = 'aB3dE6fG'
      ..passwords['b'] = 'hJ7kL2mN';
    final a = CollectiveAccess(service, '#12345678', managerAccountId: 'a');
    final b = CollectiveAccess(service, '#12345678', managerAccountId: 'b');
    await a.remember('aB3dE6fG');
    expect(await b.hasSaved(), isFalse);
    expect(await CollectiveAccess(service, '#12345678').hasSaved(), isFalse);
    await b.remember('hJ7kL2mN');
    final text = await a.copyText('Atlas');
    expect(text, contains('user-a'));
    expect(text, contains('aB3dE6fG'));
    expect(text, isNot(contains('lecture seule')));
    expect(service.paths.every((p) => p.contains('/accounts/')), isTrue);
    await service.disconnect();
    final restored = ManagerService();
    expect(
      await CollectiveAccess(
        restored,
        '#12345678',
        managerAccountId: 'a',
      ).hasSaved(),
      isFalse,
    );
    expect(
      await CollectiveAccess(
        restored,
        '#12345678',
        managerAccountId: 'b',
      ).hasSaved(),
      isFalse,
    );
  });
  test('GES04 explicit regeneration uses target endpoint and saves only verified result', () async {
    final service = ManagerService();
    final access = CollectiveAccess(
      service,
      '#12345678',
      managerAccountId: 'a',
    );
    await access.regenerate();
    expect(service.passwords['a'], hasLength(8));
    expect(await access.hasSaved(), isTrue);
    expect(await access.copyText('Atlas'), contains(service.passwords['a']));
  });
}
