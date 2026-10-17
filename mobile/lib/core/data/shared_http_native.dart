import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'shared_http_error.dart';

Future<Map<String, dynamic>> sendSharedRequest(
  String method,
  Uri uri,
  String? token,
  Object? body,
) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
  try {
    final request = await client.openUrl(method, uri);
    if (token != null) request.headers.set('Authorization', 'Bearer $token');
    request.headers.contentType = ContentType.json;
    if (body != null) request.write(jsonEncode(body));
    final response = await request.close().timeout(const Duration(seconds: 90));
    final content = await utf8.decoder.bind(response).join();
    final decoded = jsonDecode(content) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw SharedApiException(response.statusCode, decoded['detail']);
    }
    return decoded;
  } on IOException {
    throw const SharedNetworkException();
  } on TimeoutException {
    throw const SharedNetworkException();
  } finally {
    client.close(force: true);
  }
}
