import 'dart:async';

import 'autoswap/autoswap_watcher.dart';
import 'order_swap_watcher.dart';

/// The foreground swap watchers, started once and suspended with the session.
final class SwapWatchers {
  final OrderSwapWatcher _orders;
  final AutoswapWatcher _autoswap;
  bool _watchingOrders = false;
  bool _watchingAutoswap = false;
  bool _suspended = false;
  bool _restartOrders = false;
  bool _restartAutoswap = false;
  bool _stopFailed = false;
  Future<void>? _suspending;

  SwapWatchers(this._orders, this._autoswap);

  bool get isWatchingOrders => _watchingOrders;

  bool get isWatchingAutoswap => _watchingAutoswap;

  void start({required bool watchOrders, required bool watchAutoswap}) {
    if (_suspended) {
      // Started while locked: begin at the unlock instead.
      _restartOrders = _restartOrders || watchOrders;
      _restartAutoswap = _restartAutoswap || watchAutoswap;
      return;
    }
    if (watchOrders) {
      _watchingOrders = true;
      _orders.start();
    }
    if (watchAutoswap) {
      _watchingAutoswap = true;
      _autoswap.start();
    }
  }

  Future<void> dispose() async {
    if (_watchingOrders) {
      _watchingOrders = false;
      _orders.dispose();
    }
    if (_watchingAutoswap) {
      _watchingAutoswap = false;
      await _autoswap.dispose();
    }
  }

  /// Revokes both watchers now; completes once each, and any refresh or
  /// autoswap in progress, is confirmed stopped. A failure keeps them stopped.
  Future<void> suspend() {
    final stopping = _suspending;
    if (stopping != null) return stopping;
    if (_suspended) return Future<void>.value();
    _suspended = true;
    _restartOrders = _watchingOrders;
    _restartAutoswap = _watchingAutoswap;
    _watchingOrders = false;
    _watchingAutoswap = false;
    // Both watchers revoke before their first await.
    final stops = [_orders.stop(), _autoswap.dispose()];
    return _suspending = _confirm(stops);
  }

  Future<void> _confirm(List<Future<void>> stops) async {
    try {
      await Future.wait(stops);
    } catch (_) {
      _stopFailed = true;
      rethrow;
    } finally {
      _suspending = null;
    }
  }

  /// Restarts what [suspend] stopped, once, after its stop is confirmed.
  void resume() {
    if (!_suspended || _suspending != null || _stopFailed) return;
    _suspended = false;
    final orders = _restartOrders;
    final autoswap = _restartAutoswap;
    _restartOrders = false;
    _restartAutoswap = false;
    start(watchOrders: orders, watchAutoswap: autoswap);
  }
}
