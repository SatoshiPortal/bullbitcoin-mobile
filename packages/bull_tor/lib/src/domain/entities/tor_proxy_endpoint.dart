/// A validated local SOCKS5 endpoint.
final class TorProxyEndpoint {
  final String host;
  final int port;

  TorProxyEndpoint({required this.host, required this.port}) {
    if (host.trim().isEmpty) {
      throw ArgumentError.value(host, 'host', 'must not be empty');
    }
    if (port < 1 || port > 65535) {
      throw RangeError.range(port, 1, 65535, 'port');
    }
  }

  /// Reads back a `host:port` address, or null when [value] is not one.
  ///
  /// Null rather than a throw because the addresses that reach here are typed
  /// by hand — the Electrum advanced options accept a free-form SOCKS5 string —
  /// so "not a usable proxy" is an ordinary answer, not a programming error.
  static TorProxyEndpoint? tryParse(String value) {
    final separator = value.lastIndexOf(':');
    if (separator < 1) return null;

    final port = int.tryParse(value.substring(separator + 1));
    if (port == null) return null;

    try {
      return TorProxyEndpoint(host: value.substring(0, separator), port: port);
    } on ArgumentError {
      return null;
    }
  }

  /// `host:port` — the form expected by libraries that take a SOCKS5 proxy as
  /// a plain string, such as BDK's Electrum client.
  String get authority => '$host:$port';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TorProxyEndpoint && other.host == host && other.port == port;

  @override
  int get hashCode => Object.hash(host, port);

  @override
  String toString() => authority;
}
