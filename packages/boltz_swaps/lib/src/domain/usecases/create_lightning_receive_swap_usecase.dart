import 'package:boltz_swaps/src/domain/entities/swap.dart';
import 'package:boltz_swaps/src/domain/entities/swap_failure.dart';
import 'package:boltz_swaps/src/domain/swap_repository.dart';
import 'package:boltz_swaps/src/domain/swap_watcher.dart';
import 'package:boltz_swaps/src/log.dart';
import 'package:primitives/primitives.dart';

class CreateLightningReceiveSwapUsecase {
  CreateLightningReceiveSwapUsecase({
    required this._swapRepository,
    required this._swapWatcher,
  });

  final SwapRepository _swapRepository;
  final SwapWatcher _swapWatcher;

  Future<Result<LnReceiveSwap, SwapsFailure>> execute({
    required String walletId,
    required int amountSat,
    required bool toLiquid,
    String? description,
  }) async {
    try {
      final limits = await _swapRepository.limits(
        toLiquid ? SwapType.lightningToLiquid : SwapType.lightningToBitcoin,
      );
      if (!limits.accepts(amountSat)) {
        return Err(
          SwapsAmountOutOfLimitsFailure(minSat: limits.min, maxSat: limits.max),
        );
      }
      _swapWatcher.ensureRunning();
      return Ok(
        await _swapRepository.createLightningReceive(
          walletId: walletId,
          amountSat: amountSat,
          toLiquid: toLiquid,
          description: description,
        ),
      );
    } catch (e) {
      final failure = classifySwapCreationFailure(e);
      swapsLog.warning(
        'SWAPS: lightning receive swap creation failed: $failure',
      );
      return Err(failure);
    }
  }
}
