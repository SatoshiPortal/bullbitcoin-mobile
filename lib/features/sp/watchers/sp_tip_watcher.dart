import 'dart:async';

import 'package:bb_mobile/features/sp/domain/entities/sp_notif_log.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_notification.dart';
import 'package:bb_mobile/features/sp/domain/usecases/watch_sp_notification_log_usecase.dart';
import 'package:flutter/widgets.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_update.dart';
import 'package:bb_mobile/features/sp/domain/usecases/sync_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/watch_sp_updates_usecase.dart';
import 'package:bull_logger/bull_logger.dart';

/// Re-runs SP sync when the chain tip lands or a foreground scan fails.
///
/// A sync tick judges the scan policy with whatever tip it has, and at app start
/// it usually runs before the header store has reported one, so it declines and
/// nothing would resume the scan until the next foreground. Watching for the tip
/// keeps that decision from depending on which finishes first.
class SpTipWatcher {
  final WatchSpUpdatesUsecase _watchSpUpdatesUsecase;
  final SyncSpWalletUsecase _syncSpWalletUsecase;

  final WatchSpNotificationLogUsecase _watchSpNotificationLogUsecase;
  final Stream<AppLifecycleState> _lifecycleStates;
  StreamSubscription<AppLifecycleState>? _lifecycleSubscription;
  StreamSubscription<SpNotifLogLine>? _notificationSubscription;
  StreamSubscription<SpUpdate>? _subscription;
  Timer? _retry;
  int _attempts = 0;
  bool _foreground;
  int? _lastHandledTip;

  SpTipWatcher({
    required this._watchSpUpdatesUsecase,
    required this._syncSpWalletUsecase,
    required this._watchSpNotificationLogUsecase,
    required this._lifecycleStates,
    required bool initiallyForeground,
  }) : _foreground = initiallyForeground;

  void start() {
    _subscription ??= _watchSpUpdatesUsecase.execute().listen(_onUpdate);
    _lifecycleSubscription ??= _lifecycleStates.listen(_onLifecycle);
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
  }

  Future<void> dispose() async {
    _resetRetry();
    await _notificationSubscription?.cancel();
    await _lifecycleSubscription?.cancel();
    await _subscription?.cancel();
    _notificationSubscription = null;
    _lifecycleSubscription = null;
    _subscription = null;
    _lastHandledTip = null;
  }

  void _onUpdate(SpUpdate update) {
    if (!_foreground || update is! SpChainTipChanged) return;
    // One sync per height: header progress reports the same tip repeatedly
    // while it works through a batch.
    if (update.tip == _lastHandledTip) return;
    _lastHandledTip = update.tip;
    unawaited(_sync());
  }

  void _onLifecycle(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) return;
    final foreground = state == AppLifecycleState.resumed;
    if (foreground == _foreground) return;
    _foreground = foreground;
    _resetRetry();
    // The normal wallet sync also runs on resume. A deferred retry covers the
    // case where that tick saw a still-running scan before the failure arrived.
    if (foreground) _scheduleRetry();
  }

  void _scheduleRetry() {
    if (!_foreground || _retry != null || _attempts >= 3) return;
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
