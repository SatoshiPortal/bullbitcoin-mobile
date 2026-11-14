import 'package:swaps/src/domain/entities/swap.dart';
import 'package:swaps/src/domain/entities/swap_failure.dart';
import 'package:swaps/src/domain/swap_repository.dart';
import 'package:swaps/src/domain/swap_watcher.dart';
import 'package:swaps/src/log.dart';
import 'package:primitives/primitives.dart';

class CreateLightningSendSwapUsecase {
  CreateLightningSendSwapUsecase({
    required this._swapRepository,
    required this._swapWatcher,
  });

  final SwapRepository _swapRepository;
  final SwapWatcher _swapWatcher;

  Future<Result<LnSendSwap, SwapsFailure>> execute({
    required String walletId,
    required String invoice,
    required int invoiceAmountSat,
    required bool fromLiquid,
  }) async {
    try {
      final pending = await _swapRepository.pendingLightningSend(
        invoice: invoice,
        walletId: walletId,
        fromLiquid: fromLiquid,
      );
      if (pending != null) {
        _swapWatcher.ensureRunning();
        await _swapRepository.reconcile([pending.id]);
        final current = await _swapRepository.get(pending.id);
        if (current is LnSendSwap &&
            current.status == SwapStatus.pending &&
            current.sendTxid == null) {
          return Ok(current);
        }
        return const Err(
          SwapsBoltzRejectedFailure('a swap for this invoice is in progress'),
        );
      }
      final limits = await _swapRepository.limits(
        fromLiquid ? SwapType.liquidToLightning : SwapType.bitcoinToLightning,
      );
      if (!limits.accepts(invoiceAmountSat)) {
        return Err(
          SwapsAmountOutOfLimitsFailure(minSat: limits.min, maxSat: limits.max),
        );
      }
      _swapWatcher.ensureRunning();
      return Ok(
        await _swapRepository.createLightningSend(
          walletId: walletId,
          invoice: invoice,
          fromLiquid: fromLiquid,
        ),
      );
    } catch (e) {
      final failure = classifySwapCreationFailure(e);
      swapsLog.warning('SWAPS: lightning send swap creation failed: $failure');
      return Err(failure);
    }
  }
}
