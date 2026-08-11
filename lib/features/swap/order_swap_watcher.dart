import 'dart:async';

import 'package:bb_mobile/core/sync/sync_coordinator.dart';
import 'package:bb_mobile/core/sync/sync_kind.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:flutter/widgets.dart';

class OrderSwapWatcher {
  final SyncCoordinator _syncCoordinator;
  final Duration _pollInterval;

  AppLifecycleListener? _lifecycleListener;
  Timer? _timer;
  Future<void>? _activeRefresh;
  bool _isResumed = true;
  bool _isStarted = false;

  OrderSwapWatcher(
    this._syncCoordinator, {
    this._pollInterval = const Duration(seconds: 30),
  });

  void start() {
    if (_isStarted) return;
    _isStarted = true;
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _isResumed =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
    _lifecycleListener = AppLifecycleListener(
      onStateChange: _onLifecycleChange,
    );
    _schedule(Duration.zero);
  }

  Future<void> refresh() {
    if (!_isResumed) return Future.value();
    final active = _activeRefresh;
    if (active != null) return active;

    _timer?.cancel();
    final future = _refreshOnce();
    _activeRefresh = future;
    return future.whenComplete(() {
      if (identical(_activeRefresh, future)) _activeRefresh = null;
    });
  }

  Future<void> _refreshOnce() async {
    try {
      await _syncCoordinator.sync(only: {SyncKind.swaps});
    } catch (error) {
      log.warning('[OrderSwapWatcher] refresh failed: ${error.runtimeType}');
    } finally {
      _schedule(_nextDelay());
    }
  }

  Duration _nextDelay() {
    final outcome = _syncCoordinator.lastSwapSyncOutcome;
    if (outcome?.kind == SyncOutcomeKind.rateLimited) {
      final retryAfter = outcome?.retryAfter;
      if (retryAfter != null && retryAfter >= const Duration(seconds: 60)) {
        return retryAfter;
      }
      return const Duration(seconds: 60);
    }
    if (outcome?.kind == SyncOutcomeKind.idle) {
      return const Duration(minutes: 5);
    }
    return _pollInterval;
  }

  void _schedule(Duration delay) {
    _timer?.cancel();
    if (!_isStarted || !_isResumed) return;
    _timer = Timer(delay, () => unawaited(refresh()));
  }

  void _onLifecycleChange(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    _isResumed = resumed;
    if (!resumed) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _schedule(Duration.zero);
  }

  void dispose() {
    _isStarted = false;
    _timer?.cancel();
    _timer = null;
    _lifecycleListener?.dispose();
    _lifecycleListener = null;
  }
}
