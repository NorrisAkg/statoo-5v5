import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/features/shared/application/shared_providers.dart';
import 'package:statoo/features/shared/data/shared_service.dart';
import 'package:statoo/features/shared/presentation/shared_group_screen.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('SharedService.joinReadonly normalise # et appelle /groups/join-readonly', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    String? calledMethod;
    String? calledPath;
    Map<String, dynamic>? calledBody;
    server.listen((request) async {
      if (request.method == 'POST') {
        calledMethod = request.method;
        calledPath = request.uri.path;
        calledBody = jsonDecode(await utf8.decodeStream(request)) as Map<String, dynamic>;
      }
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'token': 'ro-token',
          'expires_at': '2026-12-01T00:00:00Z',
          'group_id': '#13120987',
          'name': 'Groupe Test',
          'members': <dynamic>[],
          'documents': <String, dynamic>{},
          'account': {'id': 'shared', 'username': 'membres', 'shared': true, 'roles': ['MEMBER']},
        }));
      await request.response.close();
    });

    final service = SharedService(AppDatabase.instance);
    addTearDown(() async {
      service.dispose();
      await server.close(force: true);
    });

    await service.joinReadonly('http://127.0.0.1:${server.port}', '#13120987');

    expect(calledMethod, 'POST');
    expect(calledPath, '/groups/join-readonly');
    expect(calledBody, {'group_id': '#13120987'});
    expect(service.token, 'ro-token');
    expect(service.groupId, '#13120987');
  });

  testWidgets('SharedGroupScreen: mode Accès membre (lecture seule) masque identifiant et mot de passe', (tester) async {
    final service = SharedService(AppDatabase.instance);
    addTearDown(service.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const SharedGroupScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Accès membre (lecture seule)'), findsOneWidget);
    await tester.tap(find.text('Accès membre (lecture seule)'));
    await tester.pumpAndSettle();

    expect(find.text('Identifiant du groupe'), findsOneWidget);
    expect(find.text('Identifiant'), findsNothing);
    expect(find.text('Mot de passe'), findsNothing);
  });
}
