import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'shared_http_error.dart';

Future<Map<String, dynamic>> sendSharedRequest(
  String method,
  Uri uri,
  String? token,
  Object? body,
) async {
  final client = http.Client();
  try {
    final request = http.Request(method, uri)
      ..headers['Content-Type'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(
      await client.send(request).timeout(const Duration(seconds: 90)),
    );
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw SharedApiException(response.statusCode, decoded['detail']);
    }
    return decoded;
  } on http.ClientException {
    throw const SharedNetworkException();
  } on TimeoutException {
    throw const SharedNetworkException();
  } finally {
    client.close();
  }
}
