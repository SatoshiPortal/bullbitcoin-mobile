import 'package:bull_tor/tor.dart';

/// The SOCKS route one key-server call travels through.
///
/// Deliberately not a [TorSession]: that type carries a [TorTransport], which
/// only describes how *embedded* Tor reached the network. An external proxy such
/// as an external proxy has no transport we know of, and inventing one would be a lie the
/// UI could read back. Mirrors `ElectrumTorRoute`, which draws the same line for
/// the same reason.
final class RecoverBullTorRoute {
  final TorRoute route;
  final Future<void> Function() _onClose;
  Future<void>? _closing;

  RecoverBullTorRoute(this.route, this._onClose);

  TorProxyEndpoint get endpoint => route.endpoint;

  TorSource get source => route.source;

  /// Idempotent: callers close in a `finally`, and a retry path may close twice.
  Future<void> close() => _closing ??= _onClose();
}
