/// Validates the key-server URL accepted by RecoverBull.
///
/// Key-server traffic is intentionally restricted to HTTP onion endpoints:
/// the selected Tor route provides the privacy boundary. Loopback HTTP is
/// retained for local development and tests only.
Uri validateRecoverBullServerUrl(Uri url, {bool allowLoopback = false}) {
  final host = url.host.toLowerCase();
  final isLoopback =
      host == 'localhost' || host == '127.0.0.1' || host == '::1';
  final validHost = host.endsWith('.onion') || (allowLoopback && isLoopback);
  final validPort = !url.hasPort || (url.port >= 1 && url.port <= 65535);

  if (url.scheme != 'http' ||
      url.userInfo.isNotEmpty ||
      url.hasQuery ||
      url.hasFragment ||
      host.isEmpty ||
      !validHost ||
      !validPort) {
    throw ArgumentError.value(url, 'url', 'must be an HTTP onion endpoint');
  }
  return url;
}
