import 'dart:async';

import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/swap/domain/swap_failure.dart';
import 'package:bb_mobile/features/swap/domain/usecases/refresh_order_swaps_usecase.dart';
import 'package:flutter/widgets.dart';

class OrderSwapWatcher {
  final RefreshOrderSwapsUsecase _refreshOrders;
  final Duration _pollInterval;
  final Duration _idleInterval;

  AppLifecycleListener? _lifecycleListener;
  Timer? _timer;
  Future<void>? _activeRefresh;
  bool _isResumed = true;
  bool _isStarted = false;

  OrderSwapWatcher(
    this._refreshOrders, {
    this._pollInterval = const Duration(seconds: 15),
    this._idleInterval = const Duration(minutes: 1),
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
    var nextDelay = _pollInterval;
    try {
      switch (await _refreshOrders.execute()) {
        case Ok(:final value):
          if (value.pollableOrderCount == 0) nextDelay = _idleInterval;
          final rateLimit = value.failures.whereType<SwapRateLimitedFailure>();
          if (rateLimit.isNotEmpty) {
            nextDelay = rateLimit.first.retryAfter ?? _pollInterval;
          }
          if (value.failures.isNotEmpty) {
            final types = value.failures
                .map((failure) => failure.runtimeType)
                .toSet()
                .join(', ');
            log.warning(
              '[OrderSwapWatcher] refresh failures: '
              '${value.failures.length} ($types)',
            );
          }
        case Err(:final failure):
          log.warning(
            '[OrderSwapWatcher] refresh failed: ${failure.runtimeType}',
          );
      }
    } catch (error) {
      log.warning(
        '[OrderSwapWatcher] unexpected refresh failure: ${error.runtimeType}',
      );
    } finally {
      _schedule(nextDelay);
    }
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
