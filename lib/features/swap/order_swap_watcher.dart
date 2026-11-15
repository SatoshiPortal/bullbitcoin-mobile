import 'dart:async';

import 'package:bb_mobile/features/swap/domain/entities/order_swap_polling.dart';
import 'package:bb_mobile/features/swap/domain/usecases/schedule_order_swap_refresh_usecase.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:flutter/widgets.dart';

class OrderSwapWatcher {
  final ScheduleOrderSwapRefreshUsecase _scheduleRefresh;
  final Duration _pollInterval;
  final bool Function() _isAppUpdateRequired;

  AppLifecycleListener? _lifecycleListener;
  Timer? _timer;
  Future<void>? _activeRefresh;
  bool _isResumed = true;
  bool _isStarted = false;

  OrderSwapWatcher(
    this._scheduleRefresh, {
    this._pollInterval = const Duration(seconds: 30),
    bool Function()? isAppUpdateRequired,
  }) : _isAppUpdateRequired = isAppUpdateRequired ?? (() => false);

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
    if (!_isResumed || _isAppUpdateRequired()) return Future.value();
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
    final attempt = await _scheduleRefresh.execute();
    if (attempt.failure case final failure?) {
      log.warning('[OrderSwapWatcher] refresh failed: ${failure.runtimeType}');
    }
    _schedule(_nextDelay(attempt.lastOutcome));
  }

  Duration _nextDelay(OrderSwapPolling? outcome) {
    if (outcome?.kind == OrderSwapPollingKind.rateLimited) {
      final retryAfter = outcome?.retryAfter;
      if (retryAfter != null && retryAfter >= const Duration(seconds: 60)) {
        return retryAfter;
      }
      return const Duration(seconds: 60);
    }
    if (outcome?.kind == OrderSwapPollingKind.idle) {
      return const Duration(minutes: 5);
    }
    return _pollInterval;
  }

  void _schedule(Duration delay) {
    _timer?.cancel();
    if (!_isStarted || !_isResumed || _isAppUpdateRequired()) return;
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
