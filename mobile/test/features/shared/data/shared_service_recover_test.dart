// ============================================================================
// FICHIER 1 : mobile/test/features/shared/data/shared_service_recover_test.dart
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/core/data/shared_http_error.dart';
import 'package:statoo/features/shared/data/shared_service.dart';

class FakeSecureStorage extends FlutterSecureStorage {
  FakeSecureStorage([Map<String, String>? initialData])
      : _values = Map<String, String>.from(initialData ?? <String, String>{});

  final Map<String, String> _values;
  Completer<void>? writeCompleter;

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
    if (writeCompleter != null) {
      await writeCompleter!.future;
    }
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
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
    return _values[key];
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
    _values.remove(key);
  }

  @override
  Future<Map<String, String>> readAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return Map<String, String>.from(_values);
  }

  @override
  Future<void> deleteAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _values.clear();
  }

  @override
  Future<bool> containsKey({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _values.containsKey(key);
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('SharedService - Recovery & Session Establishment', () {
    late HttpServer server;
    late String baseUrl;
    late Database rawDb;
    late AppDatabase appDb;
    late FakeSecureStorage fakeStorage;
    late SharedService service;
    Future<void> Function(HttpRequest request)? requestHandler;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      baseUrl = 'http://127.0.0.1:${server.port}';
      requestHandler = null;

      server.listen((request) async {
        if (requestHandler != null) {
          await requestHandler!(request);
        } else {
          request.response.statusCode = HttpStatus.notFound;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode(<String, dynamic>{'detail': 'not found'}));
          await request.response.close();
        }
      });

      rawDb = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      appDb = AppDatabase.forTesting(rawDb);
      await appDb.initSchemaForTest(rawDb);
      fakeStorage = FakeSecureStorage();
      service = SharedService(appDb, storage: fakeStorage);
    });

    tearDown(() async {
      service.dispose();
      await server.close(force: true);
      await rawDb.close();
    });

    group('SharedService.recover() - URL Validation', () {
      test('G-W-T 1.1: Rejette une URL http non-locale avec FormatException', () async {
        // Given
        const String nonLocalHttp = 'http://api.statoo.app';

        // When / Then
        expect(
          () => service.recover(
            url: nonLocalHttp,
            groupId: 'grp_1',
            username: 'alex',
            recoveryCode: '2345-6789-ABCD-EFGH',
            newPassword: 'ValidPassword123!',
            newRecoveryCode: 'WXYZ-2345-6789-ABCD',
          ),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('HTTPS'),
            ),
          ),
        );
      });

      test('G-W-T 1.2: Rejette un schéma non supporté ftp:// avec FormatException', () async {
        // Given
        const String ftpUrl = 'ftp://127.0.0.1:8000';

        // When / Then
        expect(
          () => service.recover(
            url: ftpUrl,
            groupId: 'grp_1',
            username: 'alex',
            recoveryCode: '2345-6789-ABCD-EFGH',
            newPassword: 'ValidPassword123!',
            newRecoveryCode: 'WXYZ-2345-6789-ABCD',
          ),
          throwsA(isA<FormatException>()),
        );
      });

      test('G-W-T 1.3: Rejette une URL sans schéma avec FormatException', () async {
        // Given
        const String rawUrl = 'api.statoo.app';

        // When / Then
        expect(
          () => service.recover(
            url: rawUrl,
            groupId: 'grp_1',
            username: 'alex',
            recoveryCode: '2345-6789-ABCD-EFGH',
            newPassword: 'ValidPassword123!',
            newRecoveryCode: 'WXYZ-2345-6789-ABCD',
          ),
          throwsA(isA<FormatException>()),
        );
      });

      test('G-W-T 1.4: Accepte une URL https distante valide', () async {
        // Given
        const String validHttps = 'https://api.statoo.app';

        // When / Then
        // L'URL est acceptée au niveau de la validation (l'échec réseau distant prouve que la validation a réussi)
        await expectLater(
          () => service.recover(
            url: validHttps,
            groupId: 'grp_1',
            username: 'alex',
            recoveryCode: '2345-6789-ABCD-EFGH',
            newPassword: 'ValidPassword123!',
            newRecoveryCode: 'WXYZ-2345-6789-ABCD',
          ),
          throwsA(isNot(isA<FormatException>())),
        );
      });

      test('G-W-T 1.5: Accepte http://localhost', () async {
        // Given
        const String localUrl = 'http://localhost:9999';

        // When / Then
        await expectLater(
          () => service.recover(
            url: localUrl,
            groupId: 'grp_1',
            username: 'alex',
            recoveryCode: '2345-6789-ABCD-EFGH',
            newPassword: 'ValidPassword123!',
            newRecoveryCode: 'WXYZ-2345-6789-ABCD',
          ),
          throwsA(isNot(isA<FormatException>())),
        );
      });

      test('G-W-T 1.6: Accepte http://127.0.0.1', () async {
        // Given
        final String localIpUrl = baseUrl;

        // When / Then
        await expectLater(
          () => service.recover(
            url: localIpUrl,
            groupId: 'grp_1',
            username: 'alex',
            recoveryCode: '2345-6789-ABCD-EFGH',
            newPassword: 'ValidPassword123!',
            newRecoveryCode: 'WXYZ-2345-6789-ABCD',
          ),
          throwsA(isNot(isA<FormatException>())),
        );
      });

      test('G-W-T 1.7: Accepte http://10.0.2.2 (Android emulator)', () async {
        // Given
        const String androidEmulatorUrl = 'http://10.0.2.2:8000';

        // When / Then
        await expectLater(
          () => service.recover(
            url: androidEmulatorUrl,
            groupId: 'grp_1',
            username: 'alex',
            recoveryCode: '2345-6789-ABCD-EFGH',
            newPassword: 'ValidPassword123!',
            newRecoveryCode: 'WXYZ-2345-6789-ABCD',
          ),
          throwsA(isNot(isA<FormatException>())),
        );
      });

      test('G-W-T 1.8: Normalise les trailing slashes et espaces périphériques', () async {
        // Given
        final String messyUrl = '  $baseUrl/  ';
        requestHandler = (request) async {
          expect(request.uri.path, equals('/auth/recover'));
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode(<String, dynamic>{'token': 'ok'}));
          await request.response.close();
        };

        // When
        final Map<String, dynamic> result = await service.recover(
          url: messyUrl,
          groupId: 'grp_1',
          username: 'alex',
          recoveryCode: '2345-6789-ABCD-EFGH',
          newPassword: 'ValidPassword123!',
          newRecoveryCode: 'WXYZ-2345-6789-ABCD',
        );

        // Then
        expect(result['token'], equals('ok'));
      });
    });

    group('SharedService.recover() - Requête HTTP et Payload JSON', () {
      test('G-W-T 2.1 - 2.4: Émet un POST vers /auth/recover sans token avec le payload JSON requis', () async {
        // Given
        requestHandler = (request) async {
          expect(request.method, equals('POST'));
          expect(request.uri.path, equals('/auth/recover'));
          expect(request.headers.value(HttpHeaders.authorizationHeader), isNull);
          expect(request.headers.contentType?.mimeType, equals('application/json'));

          final String body = await utf8.decoder.bind(request).join();
          final Map<String, dynamic> json = jsonDecode(body) as Map<String, dynamic>;

          expect(json['group_id'], equals('grp_test'));
          expect(json['username'], equals('alex'));
          expect(json['recovery_code'], equals('2345-6789-ABCD-EFGH'));
          expect(json['new_password'], equals('NewPassword123!'));
          expect(json['new_recovery_code'], equals('WXYZ-2345-6789-ABCD'));

          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode(<String, dynamic>{
              'token': 'recovered_jwt_token',
              'expires_at': '2026-11-01T12:00:00Z',
              'group_id': 'grp_test',
              'account': <String, dynamic>{
                'id': 'acc_alex',
                'username': 'alex',
                'roles': <String>['ADMIN'],
              },
              'recovery_rotated': true,
            }),
          );
          await request.response.close();
        };

        // When
        final Map<String, dynamic> result = await service.recover(
          url: baseUrl,
          groupId: 'grp_test',
          username: 'alex',
          recoveryCode: '2345-6789-ABCD-EFGH',
          newPassword: 'NewPassword123!',
          newRecoveryCode: 'WXYZ-2345-6789-ABCD',
        );

        // Then
        expect(result['token'], equals('recovered_jwt_token'));
        expect(result['group_id'], equals('grp_test'));
        expect(result['recovery_rotated'], isTrue);
      });
    });

    group('SharedService.recover() - Réponses du serveur & Erreurs API', () {
      test('G-W-T 3.1: Succès 200 retourne le payload de session complet', () async {
        // Given
        final Map<String, dynamic> expectedPayload = <String, dynamic>{
          'token': 'jwt_abc_123',
          'expires_at': '2026-11-05T18:00:00Z',
          'group_id': 'grp_42',
          'account': <String, dynamic>{
            'id': 'acc_99',
            'username': 'sam',
            'roles': <String>['TR', 'TGA'],
          },
          'recovery_rotated': true,
        };

        requestHandler = (request) async {
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode(expectedPayload));
          await request.response.close();
        };

        // When
        final Map<String, dynamic> response = await service.recover(
          url: baseUrl,
          groupId: 'grp_42',
          username: 'sam',
          recoveryCode: '2345-6789-ABCD-EFGH',
          newPassword: 'NewPassword123!',
          newRecoveryCode: 'WXYZ-2345-6789-ABCD',
        );

        // Then
        expect(response, equals(expectedPayload));
      });

      test('G-W-T 3.2: Erreur 401 lève SharedApiException(401) avec message adapté', () async {
        // Given
        requestHandler = (request) async {
          request.response.statusCode = HttpStatus.unauthorized;
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode(<String, dynamic>{
              'detail': 'Récupération impossible. Vérifiez vos informations.',
            }),
          );
          await request.response.close();
        };

        // When / Then
        await expectLater(
          () => service.recover(
            url: baseUrl,
            groupId: 'grp_1',
            username: 'alex',
            recoveryCode: '2345-6789-ABCD-EFGH',
            newPassword: 'NewPassword123!',
            newRecoveryCode: 'WXYZ-2345-6789-ABCD',
          ),
          throwsA(
            isA<SharedApiException>()
                .having((e) => e.statusCode, 'statusCode', 401)
                .having(
                  (e) => e.message,
                  'message',
                  contains('Récupération impossible'),
                ),
          ),
        );
      });

      test('G-W-T 3.3: Erreur 429 lève SharedApiException(429) pour limitation temporaire', () async {
        // Given
        requestHandler = (request) async {
          request.response.statusCode = HttpStatus.tooManyRequests;
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode(<String, dynamic>{
              'detail': 'Trop de tentatives de récupération. Réessayez dans 15 minutes.',
            }),
          );
          await request.response.close();
        };

        // When / Then
        await expectLater(
          () => service.recover(
            url: baseUrl,
            groupId: 'grp_1',
            username: 'alex',
            recoveryCode: '2345-6789-ABCD-EFGH',
            newPassword: 'NewPassword123!',
            newRecoveryCode: 'WXYZ-2345-6789-ABCD',
          ),
          throwsA(
            isA<SharedApiException>()
                .having((e) => e.statusCode, 'statusCode', 429)
                .having(
                  (e) => e.message,
                  'message',
                  contains('Trop de tentatives'),
                ),
          ),
        );
      });

      test('G-W-T 3.4: Erreur 422 lève SharedApiException(422) pour payload non valide', () async {
        // Given
        requestHandler = (request) async {
          request.response.statusCode = HttpStatus.unprocessableEntity;
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode(<String, dynamic>{
              'detail': 'Format du code de récupération non conforme.',
            }),
          );
          await request.response.close();
        };

        // When / Then
        await expectLater(
          () => service.recover(
            url: baseUrl,
            groupId: 'grp_1',
            username: 'alex',
            recoveryCode: '2345-6789-ABCD-EFGH',
            newPassword: 'NewPassword123!',
            newRecoveryCode: 'WXYZ-2345-6789-ABCD',
          ),
          throwsA(
            isA<SharedApiException>()
                .having((e) => e.statusCode, 'statusCode', 422)
                .having(
                  (e) => e.message,
                  'message',
                  contains('Format du code'),
                ),
          ),
        );
      });

      test('G-W-T 3.5: Erreur 500 lève SharedApiException(500)', () async {
        // Given
        requestHandler = (request) async {
          request.response.statusCode = HttpStatus.internalServerError;
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode(<String, dynamic>{'detail': 'Internal server error'}),
          );
          await request.response.close();
        };

        // When / Then
        await expectLater(
          () => service.recover(
            url: baseUrl,
            groupId: 'grp_1',
            username: 'alex',
            recoveryCode: '2345-6789-ABCD-EFGH',
            newPassword: 'NewPassword123!',
            newRecoveryCode: 'WXYZ-2345-6789-ABCD',
          ),
          throwsA(
            isA<SharedApiException>().having(
              (e) => e.statusCode,
              'statusCode',
              500,
            ),
          ),
        );
      });
    });

    group('SharedService.recover() - Pannes Réseau', () {
      test('G-W-T 4.1: Serveur injoignable (port fermé) lève SharedNetworkException', () async {
        // Given
        await server.close(force: true);

        // When / Then
        await expectLater(
          () => service.recover(
            url: baseUrl,
            groupId: 'grp_1',
            username: 'alex',
            recoveryCode: '2345-6789-ABCD-EFGH',
            newPassword: 'NewPassword123!',
            newRecoveryCode: 'WXYZ-2345-6789-ABCD',
          ),
          throwsA(isA<SharedNetworkException>()),
        );
      });

      test('G-W-T 4.2: Fermeture brutale de socket lève SharedNetworkException', () async {
        // Given
        requestHandler = (request) async {
          (await request.response.detachSocket()).destroy();
        };

        // When / Then
        await expectLater(
          () => service.recover(
            url: baseUrl,
            groupId: 'grp_1',
            username: 'alex',
            recoveryCode: '2345-6789-ABCD-EFGH',
            newPassword: 'NewPassword123!',
            newRecoveryCode: 'WXYZ-2345-6789-ABCD',
          ),
          throwsA(isA<SharedNetworkException>()),
        );
      });
    });

    group('SharedService.establishSession() - Nominal et Persistance', () {
      final Map<String, dynamic> sampleSessionResult = <String, dynamic>{
        'token': 'jwt_established_123',
        'expires_at': DateTime.now().add(const Duration(hours: 4)).toUtc().toIso8601String(),
        'group_id': 'grp_established',
        'account': <String, dynamic>{
          'id': 'acc_established',
          'username': 'alex',
          'roles': <String>['ADMIN'],
        },
        'recovery_rotated': true,
      };

      test('G-W-T 5.1 - 5.5: Persiste les identifiants, met à jour le service et synchronise', () async {
        // Given
        requestHandler = (request) async {
          if (request.method == 'GET' &&
              request.uri.path == '/groups/grp_established') {
            request.response.statusCode = HttpStatus.ok;
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode(<String, dynamic>{
                'id': 'grp_established',
                'name': 'Groupe Établi',
                'account': sampleSessionResult['account'],
                'members': <dynamic>[],
                'documents': <String, dynamic>{},
              }),
            );
            await request.response.close();
          }
        };

        // When
        await service.establishSession(baseUrl, sampleSessionResult);

        // Then
        expect(service.connected, isTrue);
        expect(service.token, equals('jwt_established_123'));
        expect(service.baseUrl, equals(baseUrl));
        expect(service.groupId, equals('grp_established'));
        expect(service.protectedGroups.contains('grp_established'), isTrue);

        final String? storedRaw = await fakeStorage.read(key: 'statoo_connection');
        expect(storedRaw, isNotNull);
        final Map<String, dynamic> stored = jsonDecode(storedRaw!) as Map<String, dynamic>;
        expect(stored['token'], equals('jwt_established_123'));
        expect(stored['url'], equals(baseUrl));
        expect(stored['identity'], equals(sampleSessionResult));

        final List<Map<String, Object?>> metaRows = await rawDb.query(
          'meta',
          where: 'key = ?',
          whereArgs: ['shared_group_grp_established'],
        );
        expect(metaRows, hasLength(1));
        expect(metaRows.single['value'], equals('1'));
      });

      test('G-W-T 5.6: Normalise une URL avec slash final sans doublonner le slash', () async {
        // Given
        final String messyUrl = '$baseUrl/';
        requestHandler = (request) async {
          if (request.method == 'GET' &&
              request.uri.path == '/groups/grp_established') {
            request.response.statusCode = HttpStatus.ok;
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode(<String, dynamic>{
                'id': 'grp_established',
                'name': 'Groupe Établi',
                'account': sampleSessionResult['account'],
                'members': <dynamic>[],
                'documents': <String, dynamic>{},
              }),
            );
            await request.response.close();
          }
        };

        // When
        await service.establishSession(messyUrl, sampleSessionResult);

        // Then
        expect(service.baseUrl, equals(baseUrl));
        final String? storedRaw = await fakeStorage.read(key: 'statoo_connection');
        final Map<String, dynamic> stored = jsonDecode(storedRaw!) as Map<String, dynamic>;
        expect(stored['url'], equals(baseUrl));
      });
    });

    group('SharedService.establishSession() - Concurrence et Race Conditions', () {
      final Map<String, dynamic> sessionResult = <String, dynamic>{
        'token': 'jwt_race_123',
        'expires_at': DateTime.now().add(const Duration(hours: 4)).toUtc().toIso8601String(),
        'group_id': 'grp_race',
        'account': <String, dynamic>{
          'id': 'acc_race',
          'username': 'alex',
          'roles': <String>['ADMIN'],
        },
        'recovery_rotated': true,
      };

      test('G-W-T 6.1: Interrompt avec StateError si disconnect() survient pendant l’écriture storage', () async {
        // Given
        fakeStorage.writeCompleter = Completer<void>();

        // When
        final Future<void> establishFuture = service.establishSession(baseUrl, sessionResult);
        final Future<void> expectation = expectLater(
          establishFuture,
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Connexion annulée'),
            ),
          ),
        );

        // Déconnexion pendant l'écriture
        await service.disconnect();

        // Débloquer l'écriture storage
        fakeStorage.writeCompleter!.complete();

        // Then
        await expectation;

        expect(service.connected, isFalse);
        expect(await fakeStorage.read(key: 'statoo_connection'), isNull);
      });

      test('G-W-T 6.2: Interrompt avec StateError si disconnect() survient pendant la synchronisation', () async {
        // Given
        final Completer<void> syncHold = Completer<void>();

        requestHandler = (request) async {
          if (request.method == 'GET' && request.uri.path == '/groups/grp_race') {
            await syncHold.future;
            request.response.statusCode = HttpStatus.ok;
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode(<String, dynamic>{
                'id': 'grp_race',
                'name': 'Race Group',
                'account': sessionResult['account'],
                'members': <dynamic>[],
                'documents': <String, dynamic>{},
              }),
            );
            await request.response.close();
          }
        };

        // When
        final Future<void> establishFuture = service.establishSession(baseUrl, sessionResult);

        // Attendre que la requête GET soit initiée
        await Future<void>.delayed(const Duration(milliseconds: 20));

        // Déconnexion pendant l'appel GET distant
        await service.disconnect();

        // Débloquer la réponse serveur
        syncHold.complete();

        // Then
        await expectLater(
          establishFuture,
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Connexion annulée'),
            ),
          ),
        );

        expect(service.connected, isFalse);
      });

      test('G-W-T 6.3: Deux establishSession concurrents : le premier est invalidé par le second', () async {
        // Given
        final Map<String, dynamic> sessionResult1 = <String, dynamic>{
          ...sessionResult,
          'token': 'jwt_first',
          'group_id': 'grp_first',
        };
        final Map<String, dynamic> sessionResult2 = <String, dynamic>{
          ...sessionResult,
          'token': 'jwt_second',
          'group_id': 'grp_second',
        };

        requestHandler = (request) async {
          final String requestedGroup = request.uri.pathSegments.last;
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode(<String, dynamic>{
              'id': requestedGroup,
              'name': 'Group $requestedGroup',
              'account': sessionResult['account'],
              'members': <dynamic>[],
              'documents': <String, dynamic>{},
            }),
          );
          await request.response.close();
        };

        fakeStorage.writeCompleter = Completer<void>();

        // When
        final Future<void> first = service.establishSession(baseUrl, sessionResult1);
        final Future<void> firstExpectation = expectLater(
          first,
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Connexion annulée'),
            ),
          ),
        );
        final Future<void> second = service.establishSession(baseUrl, sessionResult2);

        fakeStorage.writeCompleter!.complete();

        // Then
        await firstExpectation;
        await second;

        expect(service.connected, isTrue);
        expect(service.token, equals('jwt_second'));
        expect(service.groupId, equals('grp_second'));
      });
    });
  });
}
