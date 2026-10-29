import 'dart:async';

import 'package:transaction_sync/transaction_sync.dart';

import 'cbf_foreground_service.dart';

/// Protects the existing owner while it has recovery or substantial catch-up.
/// Heartbeats come from that isolate's native polls and supervised retry/offline waits.
final class CbfForegroundSync {
  final CbfForegroundService service;
  final Future<({String title, String body})> Function() labels;
  final void Function() onProtectionChanged;
  final Duration Function() _elapsed;
  final _pending = <WalletNetworkKey>{};
  final _subscriptions =
      <WalletNetworkKey, StreamSubscription<BitcoinSyncProgress>>{};
  late final StreamSubscription<void> _lost;
  bool _visible = true;
  bool _allowed = true;
  bool _denied = false;
  bool _updating = false;
  bool _renewing = false;
  bool _disposed = false;
  Duration? _lastHeartbeat;
  int _revision = 0;
  int _serviceGeneration = 0;

  CbfForegroundSync({
    required this.service,
    required this.labels,
    required this.onProtectionChanged,
    Duration Function()? elapsed,
  }) : _elapsed = elapsed ?? _monotonicClock() {
    _lost = service.protectionLost.listen((_) => _loseProtection());
  }

  bool get protected => service.isActive && !_denied && !_disposed;

  static Duration Function() _monotonicClock() {
    final clock = Stopwatch()..start();
    return () => clock.elapsed;
  }

  void setVisible(bool visible) {
    if (_disposed || _visible == visible) return;
    if (visible) _denied = false;
    _visible = visible;
    _revision++;
    unawaited(_update());
  }

  void setAllowed(bool allowed) {
    if (_disposed || _allowed == allowed) return;
    _allowed = allowed;
    _revision++;
    unawaited(_update());
  }

  void observe(BitcoinSyncProgress progress) {
    if (_disposed) return;
    if (progress.failure != null || progress.phase == BitcoinSyncPhase.done) {
      _pending.remove(progress.key);
    } else {
      final target = progress.targetHeight;
      final reached = progress.reachedHeight;
      if (progress.isRecovery ||
          (target != null && reached != null && target - reached >= 1000)) {
        // A long catch-up retains protection until its persisted tip/failure.
        _pending.add(progress.key);
      }
    }
    _revision++;
    unawaited(_update());
  }

  void watch(WalletTransactionSyncFacade facade, Set<WalletNetworkKey> keys) {
    if (_disposed) return;
    for (final key in _subscriptions.keys.toList()) {
      if (!keys.contains(key)) _remove(key);
    }
    for (final key in keys) {
      _subscriptions.putIfAbsent(
        key,
        () => facade.watchBitcoinSyncProgress(key).listen(observe),
      );
    }
    _revision++;
    unawaited(_update());
  }

  /// Cancelling/removing a wallet must also discard its retained demand.
  void cancel(WalletNetworkKey key) {
    if (_disposed) return;
    _remove(key);
    _revision++;
    unawaited(_update());
  }

  void _remove(WalletNetworkKey key) {
    unawaited(_subscriptions.remove(key)?.cancel());
    _pending.remove(key);
  }

  void _loseProtection() {
    if (_disposed) return;
    _denied = true;
    _lastHeartbeat = null;
    _serviceGeneration++;
    onProtectionChanged();
  }

  Future<void> _stop() async {
    final wasProtected = protected;
    _serviceGeneration++;
    _lastHeartbeat = null;
    await service.stop();
    if (wasProtected && !_disposed) onProtectionChanged();
  }

  Future<void> _update() async {
    if (_disposed || _updating) return;
    _updating = true;
    var revision = _revision;
    try {
      do {
        revision = _revision;
        if (!_allowed || _pending.isEmpty) {
          await _stop();
        } else if (_visible && !_denied && !protected) {
          final text = await labels();
          if (_disposed || !_allowed || _pending.isEmpty || !_visible) continue;
          final generation = ++_serviceGeneration;
          final started = await service.start(
            title: text.title,
            body: text.body,
          );
          if (generation != _serviceGeneration || _disposed) {
            if (started) await service.stop();
            continue;
          }
          _lastHeartbeat = null;
          if (!started) _denied = true;
          onProtectionChanged();
        }
      } while (!_disposed && revision != _revision);
    } on Exception {
      _loseProtection();
      try {
        await _stop();
      } on Exception {
        // Native watchdog independently removes protection after its owner TTL.
      }
    } finally {
      _updating = false;
    }
  }

  /// Invoke only after a successful native lease poll; no independent timer.
  void heartbeat() {
    if (_disposed || _renewing || !protected || !_allowed || _pending.isEmpty) {
      return;
    }
    final now = _elapsed();
    final last = _lastHeartbeat;
    if (last != null && now - last < const Duration(seconds: 1)) return;
    _lastHeartbeat = now;
    final generation = _serviceGeneration;
    _renewing = true;
    unawaited(() async {
      try {
        final renewed = await service.renew();
        if (!renewed && generation == _serviceGeneration && !_disposed) {
          _loseProtection();
          await _stop();
        }
      } on Exception {
        if (generation == _serviceGeneration && !_disposed) {
          _loseProtection();
          try {
            await _stop();
          } on Exception {
            // Native watchdog supplies the independent final bound.
          }
        }
      } finally {
        _renewing = false;
      }
    }());
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _revision++;
    _serviceGeneration++;
    await _lost.cancel();
    await Future.wait(
      _subscriptions.values.map((subscription) => subscription.cancel()),
    );
    _subscriptions.clear();
    await service.dispose();
  }
}
