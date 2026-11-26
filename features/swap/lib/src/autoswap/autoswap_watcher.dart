import 'dart:async';

import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart' show WalletKey;
import 'package:swaps/swaps.dart';

class AutoswapWatcher {
  final Stream<WalletKey> _finished;
  final Autoswap _executeAutoswap;
  StreamSubscription? _subscription;
  Future<void>? _execution;
  Future<void>? _stopping;
  int _generation = 0;

  AutoswapWatcher(this._finished, this._executeAutoswap);

  void start() {
    if (_stopping != null || _subscription != null) return;
    final generation = ++_generation;
    _subscription ??= _finished.listen((wallet) {
      if (generation != _generation ||
          wallet.network is! LiquidNetwork ||
          _execution != null) {
        return;
      }
      _execution = _run().whenComplete(() => _execution = null);
    });
  }

  Future<void> dispose() {
    final stopping = _stopping;
    if (stopping != null) return stopping;
    _generation++;
    final subscription = _subscription;
    _subscription = null;
    final completion = Completer<void>();
    _stopping = completion.future;
    unawaited(() async {
      try {
        await subscription?.cancel();
        await _execution;
        _stopping = null;
        completion.complete();
      } catch (error, trace) {
        // The stop was not confirmed. Keep admission closed.
        completion.completeError(error, trace);
      }
    }());
    return completion.future;
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
