import 'dart:async';

import 'package:primitives/primitives.dart';
import 'package:swaps/src/domain/entities/swap.dart';
import 'package:swaps/src/domain/entities/swap_failure.dart';
import 'package:swaps/src/domain/swap_resolver.dart';
import 'package:swaps/src/domain/swap_watcher.dart';
import 'package:swaps/src/log.dart';

/// Records our broadcast lockup on the swap and hands the swap to the
/// [SwapWatcher] at once, so claim/refund driving does not wait for the next
/// provider event or heartbeat.
class RecordSwapLockupUsecase {
  final SwapResolver _resolver;
  final SwapWatcher _swapWatcher;

  const RecordSwapLockupUsecase(this._resolver, this._swapWatcher);

  Future<Result<Swap, SwapsFailure>> execute({
    required String swapId,
    required String txid,
    int? lockupFeeSat,
  }) async {
    final recorded = await _resolver.recordLockup(
      swapId: swapId,
      txid: txid,
      lockupFeeSat: lockupFeeSat,
    );
    switch (recorded) {
      case Ok(:final value):
        _swapWatcher.ensureRunning();
        unawaited(_swapWatcher.processSwap(value));
      case Err(:final failure):
        swapsLog.severe(
          'SWAPS: a broadcast lockup was not recorded',
          error: failure.runtimeType,
        );
        await swapsLog.flush();
    }
    return recorded;
  }
}
