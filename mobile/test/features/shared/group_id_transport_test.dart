import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/features/shared/data/shared_service.dart';

void main() {
  test('GRP-10 group hash remains in HTTP path, including API prefix', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final paths = <String>[];
    server.listen((request) async {
      paths.add(Uri.decodeComponent(request.uri.path));
      request.response.headers.contentType = ContentType.json;
      request.response.write('{}');
      await request.response.close();
    });
    final service = SharedService(AppDatabase.instance)
      ..baseUrl = 'http://127.0.0.1:${server.port}/api';
    addTearDown(() async { service.dispose(); await server.close(force: true); });
    await service.request('GET', '/groups/#00000001');
    await service.request('GET', '/groups/historical');
    expect(paths, ['/api/groups/#00000001', '/api/groups/historical']);
  });

  test('UX-003 connexion et récupération envoient l’identifiant normalisé', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final sent = <String, Object?>{};
    server.listen((request) async {
      final body = jsonDecode(await utf8.decodeStream(request)) as Map;
      sent[request.uri.path] = body['group_id'];
      request.response
        ..statusCode = 401
        ..headers.contentType = ContentType.json
        ..write('{"detail": "refusé"}');
      await request.response.close();
    });
    final service = SharedService(AppDatabase.instance);
    addTearDown(() async { service.dispose(); await server.close(force: true); });
    final url = 'http://127.0.0.1:${server.port}';
    await expectLater(
      service.connect(url, ' 1312 0987 ', 'admin', 'secret-123'),
      throwsA(anything),
    );
    await expectLater(
      service.recover(
        url: url,
        groupId: '13120987\n',
        username: 'admin',
        recoveryCode: 'ABCD-EFGH-JKLM-NPQR',
        newPassword: 'New-Password-2026',
        newRecoveryCode: 'KLMN-PQRS-TUVW-XYZ2',
      ),
      throwsA(anything),
    );
    expect(sent, {'/auth/login': '#13120987', '/auth/recover': '#13120987'});
  });
}
