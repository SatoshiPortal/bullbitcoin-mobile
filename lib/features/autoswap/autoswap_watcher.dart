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
      final result = await _executeAutoswap.execute();
      if (result case Err<String, AutoswapFailure>(:final failure)) {
        if (failure is AutoswapExecutionFailure ||
            failure is AutoswapProviderFailure) {
          log.warning('Autoswap failed (${failure.runtimeType})');
        }
      }
    } catch (error) {
      log.warning('Autoswap watcher failed (${error.runtimeType})');
    }
  }
}
