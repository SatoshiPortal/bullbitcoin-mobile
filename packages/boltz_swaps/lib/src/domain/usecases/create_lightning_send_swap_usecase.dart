import 'package:boltz_swaps/src/domain/entities/swap.dart';
import 'package:boltz_swaps/src/domain/entities/swap_failure.dart';
import 'package:boltz_swaps/src/domain/swap_repository.dart';
import 'package:boltz_swaps/src/log.dart';
import 'package:primitives/primitives.dart';

class CreateLightningSendSwapUsecase {
  CreateLightningSendSwapUsecase({required this._swapRepository});

  final SwapRepository _swapRepository;

  Future<Result<LnSendSwap, SwapsFailure>> execute({
    required String walletId,
    required String invoice,
    required int invoiceAmountSat,
    required bool fromLiquid,
  }) async {
    try {
      final limits = await _swapRepository.limits(
        fromLiquid ? SwapType.liquidToLightning : SwapType.bitcoinToLightning,
      );
      if (!limits.accepts(invoiceAmountSat)) {
        return Err(
          SwapsAmountOutOfLimitsFailure(minSat: limits.min, maxSat: limits.max),
        );
      }
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
