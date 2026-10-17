import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:statoo/core/data/shared_http_browser.dart';
import 'package:statoo/core/data/shared_http_error.dart';
import 'package:statoo/core/data/shared_http_native.dart' as native;

void main() {
  for (final timeout in [false, true]) {
    test(
      'NET01 web network failure has a helpful message timeout=$timeout',
      () async {
        await http.runWithClient(
          () async {
            await expectLater(
              sendSharedRequest(
                'POST',
                Uri.parse('https://example.test/groups'),
                null,
                {},
              ),
              throwsA(
                predicate(
                  (Object error) =>
                      error.toString().contains(
                        'Impossible de joindre Statoo',
                      ) &&
                      !error.toString().contains('ClientException') &&
                      !error.toString().contains('https://'),
                ),
              ),
            );
          },
          () => MockClient((request) async {
            if (timeout) throw TimeoutException('test timeout');
            throw http.ClientException('Failed to fetch', request.url);
          }),
        );
      },
    );
  }
  test('NET02 preserve server business errors', () async {
    await http.runWithClient(
      () async {
        await expectLater(
          sendSharedRequest(
            'POST',
            Uri.parse('https://example.test/groups'),
            null,
            {},
          ),
          throwsA(
            isA<SharedApiException>()
                .having((e) => e.statusCode, 'status', 409)
                .having((e) => e.message, 'message', 'Compte existant'),
          ),
        );
      },
      () => MockClient(
        (_) async => http.Response('{"detail":"Compte existant"}', 409),
      ),
    );
  });
  test(
    'NET03 native connection refusal uses the same helpful message',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      await server.close(force: true);
      await expectLater(
        native.sendSharedRequest(
          'POST',
          Uri.parse('http://127.0.0.1:$port/groups'),
          null,
          {},
        ),
        throwsA(
          predicate(
            (Object error) =>
                error.toString().contains('Impossible de joindre Statoo') &&
                !error.toString().contains('SocketException'),
          ),
        ),
      );
    },
  );
}
