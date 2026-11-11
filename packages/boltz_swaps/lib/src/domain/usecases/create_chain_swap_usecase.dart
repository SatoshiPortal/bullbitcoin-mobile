import 'package:boltz_swaps/src/domain/entities/swap.dart';
import 'package:boltz_swaps/src/domain/entities/swap_failure.dart';
import 'package:boltz_swaps/src/domain/swap_repository.dart';
import 'package:boltz_swaps/src/log.dart';
import 'package:primitives/primitives.dart';

class CreateChainSwapUsecase {
  CreateChainSwapUsecase({required this._swapRepository});

  final SwapRepository _swapRepository;

  Future<Result<ChainSwap, SwapsFailure>> execute({
    required String sendWalletId,
    required int amountSat,
    required bool fromLiquid,
    String? receiveWalletId,
    String? externalRecipientAddress,
  }) async {
    try {
      final limits = await _swapRepository.limits(
        fromLiquid ? SwapType.liquidToBitcoin : SwapType.bitcoinToLiquid,
      );
      if (!limits.accepts(amountSat)) {
        return Err(
          SwapsAmountOutOfLimitsFailure(minSat: limits.min, maxSat: limits.max),
        );
      }
      return Ok(
        await _swapRepository.createChain(
          sendWalletId: sendWalletId,
          amountSat: amountSat,
          fromLiquid: fromLiquid,
          receiveWalletId: receiveWalletId,
          externalRecipientAddress: externalRecipientAddress,
        ),
      );
    } catch (e) {
      final failure = classifySwapCreationFailure(e);
      swapsLog.warning('SWAPS: chain swap creation failed: $failure');
      return Err(failure);
    }
  }
}
