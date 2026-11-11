import 'dart:async';

import 'package:boltz_swaps/src/domain/entities/swap.dart';
import 'package:boltz_swaps/src/domain/entities/swap_failure.dart';
import 'package:boltz_swaps/src/domain/swap_repository.dart';
import 'package:boltz_swaps/src/domain/swap_watcher.dart';
import 'package:boltz_swaps/src/log.dart';
import 'package:primitives/primitives.dart';

/// Records our broadcast lockup on the swap and hands the swap to the
/// [SwapWatcher] at once, so claim/refund driving does not wait for the next
/// backend event or heartbeat.
class RecordSwapLockupUsecase {
  RecordSwapLockupUsecase({
    required this._swapRepository,
    required this._swapWatcher,
  });

  final SwapRepository _swapRepository;
  final SwapWatcher _swapWatcher;

  Future<Result<Swap, SwapsFailure>> execute({
    required String swapId,
    required String txid,
    int? lockupFeeSat,
  }) async {
    try {
      await _swapRepository.markLockupBroadcast(
        swapId: swapId,
        txid: txid,
        lockupFeeSat: lockupFeeSat,
      );
      final swap = await _swapRepository.get(swapId);
      unawaited(_swapWatcher.processSwap(swap));
      return Ok(swap);
    } catch (e) {
      swapsLog.warning('SWAPS: lockup of $swapId not recorded: $txid');
      swapsLog.severe(
        'SWAPS: a broadcast lockup was not recorded',
        error: e.runtimeType,
      );
      await swapsLog.flush();
      return Err(classifySwapsFailure(e));
    }
  }
}
