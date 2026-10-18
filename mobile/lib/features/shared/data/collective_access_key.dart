import 'dart:convert';

String? collectiveAccessKey(String? url, String? group, String? account) {
  if (url == null || group == null || account == null) return null;
  return 'statoo_collective_access_${base64Url.encode(utf8.encode(jsonEncode([url.replaceAll(RegExp(r'/+$'), ''), group, account])))}';
}
