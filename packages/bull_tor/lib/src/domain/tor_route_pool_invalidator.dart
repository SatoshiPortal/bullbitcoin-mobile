import 'dart:async';

import 'entities/tor_connection_state.dart';
import 'entities/tor_route.dart';
import 'entities/tor_transport.dart';
import 'tor_route_pool.dart';

/// Keeps route ownership in Tor infrastructure, rather than in pool consumers.
final class TorRoutePoolTorInvalidator {
  final TorRoutePool _pool;
  late final StreamSubscription<TorConnectionState> _subscription;
  TorTransport? _lastReadyTransport;
  Future<void>? _pendingInvalidation;

  TorRoutePoolTorInvalidator(Stream<TorConnectionState> states, this._pool) {
    _subscription = states.listen(_onState);
  }

  void _onState(TorConnectionState state) {
    switch (state) {
      case TorReady(:final route) when route.source == TorSource.embedded:
        _lastReadyTransport = route.transport;
      case TorStopped(:final source) when source == TorSource.embedded:
        invalidateEmbedded();
      case TorUnavailable(:final source) when source == TorSource.embedded:
        invalidateEmbedded();
      case TorConnecting(:final transport)
          when transport != null &&
              _lastReadyTransport != null &&
              transport != _lastReadyTransport:
        invalidateEmbedded();
      default:
        break;
    }
  }

  Future<void> invalidateEmbedded() {
    return _pendingInvalidation ??= _pool
        .invalidate(key: 'embedded')
        .whenComplete(() => _pendingInvalidation = null);
  }

  /// Lets synchronous state tests drain the asynchronous pool close.
  Future<void> flush() => _pendingInvalidation ?? Future<void>.value();

  Future<void> close() => _subscription.cancel();
}
