class SharedApiException implements Exception {
  const SharedApiException(this.statusCode, this.detail);
  final int statusCode;
  final Object? detail;
  String? get code =>
      detail is Map ? (detail! as Map)['code'] as String? : null;
  String get message =>
      detail is Map ? '${(detail! as Map)['message'] ?? detail}' : '$detail';
  @override
  String toString() => '$statusCode: $message';
}
