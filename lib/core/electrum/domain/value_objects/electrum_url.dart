/// Canonical parse of a stored electrum server url into host, port and TLS
/// intent. Lives in the electrum module so every consumer shares one rule
/// instead of re-implementing scheme and port handling.
class ElectrumUrl {
  final String host;
  final int port;

  /// True when the url carries an `ssl://` scheme. Consumers that speak to
  /// TLS-only servers (e.g. `:50002`) must preserve this rather than silently
  /// downgrading to plaintext.
  final bool useSsl;

  const ElectrumUrl._({
    required this.host,
    required this.port,
    required this.useSsl,
  });

  /// Parses `[scheme://]host:port`. Returns null when the host is empty, the
  /// port is missing, or the port is outside 1-65535.
  static ElectrumUrl? tryParse(String url) {
    final trimmed = url.trim();
    final schemeEnd = trimmed.indexOf('://');
    final scheme = schemeEnd == -1
        ? ''
        : trimmed.substring(0, schemeEnd).toLowerCase();
    final hostPort = schemeEnd == -1
        ? trimmed
        : trimmed.substring(schemeEnd + 3);

    final colon = hostPort.lastIndexOf(':');
    if (colon <= 0 || colon == hostPort.length - 1) return null;

    final host = hostPort.substring(0, colon);
    final port = int.tryParse(hostPort.substring(colon + 1));
    if (port == null || port < 1 || port > 65535) return null;

    return ElectrumUrl._(host: host, port: port, useSsl: scheme == 'ssl');
  }
}
