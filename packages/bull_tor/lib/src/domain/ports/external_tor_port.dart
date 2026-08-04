import '../entities/tor_proxy_endpoint.dart';

abstract interface class ExternalTorPort {
  /// Completes only after [endpoint] answers a valid SOCKS5 greeting.
  Future<void> verify(TorProxyEndpoint endpoint);
}
