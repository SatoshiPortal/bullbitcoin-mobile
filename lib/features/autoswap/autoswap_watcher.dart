import 'dart:async';

import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/features/autoswap/domain/autoswap_failure.dart';
import 'package:bb_mobile/features/autoswap/domain/usecases/execute_autoswap_usecase.dart';

class AutoswapWatcher {
  final WatchFinishedWalletSyncsUsecase _watchFinishedWalletSyncs;
  final ExecuteAutoswapUsecase _executeAutoswap;
  StreamSubscription? _subscription;
  Future<void>? _execution;

  AutoswapWatcher(this._watchFinishedWalletSyncs, this._executeAutoswap);

  void start() {
    _subscription ??= _watchFinishedWalletSyncs.execute().listen((wallet) {
      if (!wallet.isLiquid || _execution != null) return;
      _execution = _run().whenComplete(() => _execution = null);
    });
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _execution;
  }

  Future<void> _run() async {
    try {
      switch (await _executeAutoswap.execute()) {
        case Ok():
          log.info('[Autoswap] transfer under way');
        case Err(:final failure):
          final line = '[Autoswap] no transfer: ${_describe(failure)}';
          // Being switched off, or sitting below the trigger, is the steady
          // state rather than a problem — and this runs on every liquid sync.
          // Those stay at info, which the console shows but the log file
          // skips; warnings are reserved for something worth acting on.
          if (failure is AutoswapDisabledFailure ||
              failure is AutoswapInsufficientBalanceFailure) {
            log.info(line);
          } else {
            log.warning(line);
          }
      }
    } catch (error) {
      log.warning('[Autoswap] watcher failed (${error.runtimeType})');
    }
  }

  String _describe(AutoswapFailure failure) => switch (failure) {
    AutoswapFeeLimitExceededFailure(
      :final feePercent,
      :final thresholdPercent,
    ) =>
      'fee ${feePercent.toStringAsFixed(2)}% is above the '
          '${thresholdPercent.toStringAsFixed(2)}% ceiling',
    AutoswapInsufficientBalanceFailure(:final requiredThresholdSats?) =>
      'balance is below the trigger of $requiredThresholdSats sats',
    // Raised without a threshold when fees eat the whole excess.
    AutoswapInsufficientBalanceFailure() =>
      'nothing left to transfer once fees are covered',
    AutoswapInvalidSettingsFailure(:final violation) =>
      'invalid settings (${violation.name})',
    AutoswapProviderFailure() || AutoswapExecutionFailure() =>
      '${failure.runtimeType} (${failure.logMessage})',
    _ => failure.runtimeType.toString(),
  };
}
