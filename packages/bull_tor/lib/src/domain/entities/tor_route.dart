import 'tor_proxy_endpoint.dart';
import 'tor_transport.dart';

enum TorSource { embedded, external }

/// What was actually verified before exposing a route.
enum TorReadinessEvidence {
  /// Arti reported that it can open circuits.
  embeddedBootstrap,

  /// An external endpoint completed a SOCKS5 greeting.
  externalSocksHandshake,
}

/// The effective proxy selected for a Tor-routed operation.
final class TorRoute {
  final TorSource source;
  final TorProxyEndpoint endpoint;
  final TorReadinessEvidence evidence;
  final TorTransport? transport;

  const TorRoute({
    required this.source,
    required this.endpoint,
    required this.evidence,
    this.transport,
  });
}
