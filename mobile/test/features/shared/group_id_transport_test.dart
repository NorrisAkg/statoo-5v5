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
}
