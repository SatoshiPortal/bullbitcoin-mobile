import 'tor_proxy_endpoint.dart';
import 'tor_transport.dart';

/// A circuit-isolated SOCKS route owned by one application concern.
final class TorSession {
  final TorProxyEndpoint endpoint;
  final TorTransport transport;
  final Future<void> Function() _onClose;
  Future<void>? _closing;

  TorSession(this.endpoint, this.transport, this._onClose);

  Future<void> close() => _closing ??= _onClose();
}
