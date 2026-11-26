import 'dart:async';

import 'package:primitives/primitives.dart';
import 'package:silent/src/domain/entities/sp_notif_log.dart';
import 'package:silent/src/domain/entities/sp_notification.dart';
import 'package:silent/src/domain/entities/sp_update.dart';
import 'package:silent/src/domain/usecases/sync_sp_wallet_usecase.dart';
import 'package:silent/src/domain/usecases/watch_sp_notification_log_usecase.dart';
import 'package:silent/src/domain/usecases/watch_sp_updates_usecase.dart';
import 'package:bull_logger/bull_logger.dart';

/// Re-runs the SP sync when the chain tip lands, and retries a foreground scan
/// that failed.
///
/// A sync tick judges the scan policy with whatever tip it has, and at app start
/// it usually runs before the header store has reported one, so it declines and
/// nothing would resume the scan until the next foreground. Watching for the tip
/// keeps that decision from depending on which finishes first.
///
/// Both jobs are foreground-only: bwk's scan holds the account lock, and a
/// backgrounded process can be frozen or killed mid-scan. A scan that fails
/// while the app is in front is retried a bounded number of times with a
/// growing delay, then left alone until the next tip or foreground.
class SpTipWatcher {
  /// Three attempts, at 2 s, 4 s and 8 s: long enough to ride out a dropped
  /// connection or a server restart, short enough to give up before the user
  /// wonders whether the app is stuck.
  static const int _maxRetries = 3;

  final WatchSpUpdatesUsecase _watchSpUpdatesUsecase;
  final SyncSpWalletUsecase _syncSpWalletUsecase;
  final WatchSpNotificationLogUsecase _watchSpNotificationLogUsecase;
  final Stream<bool> _foregroundChanges;

  StreamSubscription<SilentUpdate>? _subscription;
  StreamSubscription<SpNotifLogLine>? _notificationSubscription;
  StreamSubscription<bool>? _foregroundSubscription;
  Timer? _retry;
  int _attempts = 0;
  bool _foreground;
  int? _lastHandledTip;

  SpTipWatcher({
    required this._watchSpUpdatesUsecase,
    required this._syncSpWalletUsecase,
    required this._watchSpNotificationLogUsecase,
    required this._foregroundChanges,
    required bool initiallyForeground,
  }) : _foreground = initiallyForeground;

  void start() {
    _subscription ??= _watchSpUpdatesUsecase.execute().listen(_onUpdate);
    _notificationSubscription ??= _watchSpNotificationLogUsecase
        .execute()
        .updates
        .listen((line) {
          switch (line.notification) {
            case SpScanFailed():
              _scheduleRetry();
            case SpScanCompleted() || SpScanStopped():
              _resetRetry();
            default:
              break;
          }
        });
    _foregroundSubscription ??= _foregroundChanges.listen(_onForeground);
  }

  Future<void> dispose() async {
    _resetRetry();
    await _notificationSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _subscription?.cancel();
    _notificationSubscription = null;
    _foregroundSubscription = null;
    _subscription = null;
    _lastHandledTip = null;
  }

  void _onUpdate(SilentUpdate update) {
    if (!_foreground || update is! SilentChainTipChanged) return;
    // One sync per height: header progress reports the same tip repeatedly
    // while it works through a batch.
    if (update.tip == _lastHandledTip) return;
    _lastHandledTip = update.tip;
    unawaited(_sync());
  }

  void _onForeground(bool foreground) {
    if (foreground == _foreground) return;
    _foreground = foreground;
    _resetRetry();
    // The normal wallet sync also runs on resume. A deferred retry covers the
    // case where that tick saw a still-running scan before the failure arrived.
    if (foreground) _scheduleRetry();
  }

  void _scheduleRetry() {
    if (!_foreground || _retry != null || _attempts >= _maxRetries) return;
    final delay = Duration(seconds: 2 << _attempts);
    _retry = Timer(delay, () {
      _retry = null;
      _attempts++;
      unawaited(_sync(resumeOnly: true));
    });
  }

  void _resetRetry() {
    _retry?.cancel();
    _retry = null;
    _attempts = 0;
  }

  Future<void> _sync({bool resumeOnly = false}) async {
    final result = await (resumeOnly
        ? _syncSpWalletUsecase.execute(resumeOnly: true)
        : _syncSpWalletUsecase.execute());
    if (result case Err(:final failure)) {
      log.warning('SpTipWatcher: sync failed: ${failure.logMessage}');
      if (resumeOnly) _scheduleRetry();
    }
  }
}
