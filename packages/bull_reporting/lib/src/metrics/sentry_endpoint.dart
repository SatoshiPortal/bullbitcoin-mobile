Uri? parseSentryEndpoint(String value) {
  final dsn = Uri.tryParse(value);
  if (dsn == null || dsn.host.isEmpty || dsn.hasQuery || dsn.hasFragment) {
    return null;
  }
  if (dsn.scheme != 'https' &&
      !(dsn.scheme == 'http' && dsn.host == '127.0.0.1')) {
    return null;
  }
  final key = dsn.userInfo;
  if (!RegExp(r'^[0-9A-Za-z_-]+$').hasMatch(key)) return null;
  final segments = dsn.pathSegments.where((value) => value.isNotEmpty).toList();
  if (segments.isEmpty || int.tryParse(segments.last) == null) return null;
  final project = segments.removeLast();
  return dsn.replace(
    userInfo: '',
    pathSegments: [...segments, 'api', project, 'envelope', ''],
    queryParameters: {'sentry_key': key},
  );
}
