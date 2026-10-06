import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_update.dart';
import 'package:bb_mobile/features/sp/domain/usecases/sync_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/watch_sp_updates_usecase.dart';
import 'package:bull_logger/bull_logger.dart';

/// Re-runs the SP sync when the chain tip lands.
///
/// A sync tick judges the scan policy with whatever tip it has, and at app start
/// it usually runs before the header store has reported one, so it declines and
/// nothing would resume the scan until the next foreground. Watching for the tip
/// keeps that decision from depending on which finishes first.
class SpTipWatcher {
  final WatchSpUpdatesUsecase _watchSpUpdatesUsecase;
  final SyncSpWalletUsecase _syncSpWalletUsecase;

  StreamSubscription<SpUpdate>? _subscription;
  int? _lastHandledTip;

  SpTipWatcher({
    required this._watchSpUpdatesUsecase,
    required this._syncSpWalletUsecase,
  });

  void start() {
    _subscription ??= _watchSpUpdatesUsecase.execute().listen(_onUpdate);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _lastHandledTip = null;
  }

  void _onUpdate(SpUpdate update) {
    if (update is! SpChainTipChanged) return;
    // One sync per height: header progress reports the same tip repeatedly
    // while it works through a batch.
    if (update.tip == _lastHandledTip) return;
    _lastHandledTip = update.tip;
    unawaited(_sync());
  }

  Future<void> _sync() async {
    final result = await _syncSpWalletUsecase.execute();
    if (result case Err(:final failure)) {
      log.warning('SpTipWatcher: sync failed: ${failure.logMessage}');
    }
  }
}
