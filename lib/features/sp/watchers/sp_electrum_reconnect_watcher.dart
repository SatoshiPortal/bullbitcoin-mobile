import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_notif_log.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_notification.dart';
import 'package:bb_mobile/features/sp/domain/usecases/resync_sp_listener_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/watch_sp_notification_log_usecase.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:flutter/widgets.dart';

/// Restarts the electrum listener after its connection drops: bwk does not
/// reconnect a dropped listener, that is the app's call.
///
/// A restart holds the account lock across a blocking connect, so it only runs
/// in the foreground, spaced by a doubling backoff and capped per round. A drop
/// seen in the background is handled on the next resume.
///
/// Each restart arms the next one, and the round ends when the listener reports
/// it connected. A round that runs out of attempts is retried on the next
/// resume.
class SpElectrumReconnectWatcher {
  static const int maxAttempts = 5;
  static const Duration firstBackoff = Duration(seconds: 2);
  // A drop this long after the last restart is a new failure, not the same
  // server flapping, so it gets a fresh round of attempts.
  static const Duration healthyGap = Duration(minutes: 1);

  final WatchSpNotificationLogUsecase _watchSpNotificationLogUsecase;
  final ResyncSpListenerUsecase _resyncSpListenerUsecase;
  final Stream<AppLifecycleState> _lifecycleStates;

  StreamSubscription<SpNotifLogLine>? _subscription;
  StreamSubscription<AppLifecycleState>? _lifecycleSubscription;
  Timer? _timer;
  bool _isResumed;
  // Set by a drop, cleared when the listener connects.
  bool _isDown = false;
  int _attempts = 0;
  DateTime? _lastRestartAt;
  // Bumped whenever the round is cancelled; a callback already past its await
  // belongs to the old round and must not arm the next attempt.
  int _generation = 0;

  SpElectrumReconnectWatcher({
    required this._watchSpNotificationLogUsecase,
    required this._resyncSpListenerUsecase,
    required this._lifecycleStates,
    required AppLifecycleState initialLifecycleState,
  }) : _isResumed = _isForeground(initialLifecycleState) ?? true;

  void start() {
    if (_subscription != null) return;
    _lifecycleSubscription = _lifecycleStates.listen(_onLifecycleChange);
    // The log stream outlives session recycles, unlike the session's own
    // notification stream.
    _subscription = _watchSpNotificationLogUsecase.execute().updates.listen(
      (line) => _onNotification(line.notification),
    );
  }

  Future<void> dispose() async {
    _cancelRound();
    final cancels = [
      ?_lifecycleSubscription?.cancel(),
      ?_subscription?.cancel(),
    ];
    _lifecycleSubscription = null;
    _subscription = null;
    await Future.wait(cancels);
  }

  void _onNotification(SpNotification n) {
    switch (n) {
      case SpElectrumDisconnected():
        _onDrop();
      case SpElectrumConnected():
        _onConnected();
      case _:
        break;
    }
  }

  void _onDrop() {
    _isDown = true;
    final last = _lastRestartAt;
    if (last == null || DateTime.now().difference(last) > healthyGap) {
      _attempts = 0;
    }
    // With the attempts used up, the round already gave up: the next resume
    // starts a new one.
    if (_isResumed && _timer == null && _attempts < maxAttempts) _schedule();
  }

  void _onConnected() {
    if (!_isDown) return;
    _isDown = false;
    _cancelRound();
  }

  // inactive is a short pass between states (a dialog, the app switcher), so it
  // keeps the previous one.
  static bool? _isForeground(AppLifecycleState state) => switch (state) {
    AppLifecycleState.resumed => true,
    AppLifecycleState.hidden ||
    AppLifecycleState.paused ||
    AppLifecycleState.detached => false,
    AppLifecycleState.inactive => null,
  };

  void _onLifecycleChange(AppLifecycleState state) {
    final isResumed = _isForeground(state) ?? _isResumed;
    if (isResumed == _isResumed) return;
    _isResumed = isResumed;
    if (!isResumed) {
      _cancelRound();
      return;
    }
    if (_isDown) {
      _attempts = 0;
      _schedule();
    }
  }

  void _schedule() {
    if (_attempts >= maxAttempts) {
      log.warning(
        'SpElectrumReconnectWatcher: still disconnected after '
        '$maxAttempts restarts, retrying on the next resume',
      );
      _timer = null;
      return;
    }
    final generation = _generation;
    _timer = Timer(firstBackoff * (1 << _attempts), () async {
      _attempts++;
      _lastRestartAt = DateTime.now();
      if (await _resyncSpListenerUsecase.execute() case Err(:final failure)) {
        log.warning(
          'SpElectrumReconnectWatcher: listener restart failed: '
          '${failure.logMessage}',
        );
      }
      if (generation != _generation || !_isDown) return;
      _schedule();
    });
  }

  void _cancelRound() {
    _timer?.cancel();
    _timer = null;
    _generation++;
  }

  @visibleForTesting
  int get attempts => _attempts;
}
