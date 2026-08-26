import 'dart:io';

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
  final HttpClient client;
  final Future<void> Function() _onClose;
  Future<void>? _closing;

  RecoverBullTorRoute(this.route, this._onClose, this.client);

  TorProxyEndpoint get endpoint => route.endpoint;

  TorSource get source => route.source;

  /// Idempotent: callers close in a `finally`, and a retry path may close twice.
  Future<void> close() => _closing ??= _closeResources();

  /// Closes owned resources without allowing teardown to mask the operation
  /// that produced the result. Callers that need teardown diagnostics may use
  /// [close] and handle its error themselves.
  Future<void> closeQuietly() async {
    try {
      await close();
    } catch (_) {}
  }

  Future<void> _closeResources() async {
    try {
      client.close(force: true);
    } finally {
      await _onClose();
    }
  }
}
