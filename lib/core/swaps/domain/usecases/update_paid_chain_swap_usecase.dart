import 'package:bb_mobile/core/swaps/domain/repositories/swap_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class UpdatePaidChainSwapUsecase {
  final SwapRepository _swapRepository;
  final SwapRepository _swapRepositoryTestnet;

  UpdatePaidChainSwapUsecase({
    required SwapRepository swapRepository,
    required SwapRepository swapRepositoryTestnet,
  }) : _swapRepository = swapRepository,
       _swapRepositoryTestnet = swapRepositoryTestnet;

  Future<void> execute({
    required String txid,
    required String swapId,
    required Network network,
    required int absoluteFees,
  }) async {
    try {
      final swapRepository =
          network.isTestnet ? _swapRepositoryTestnet : _swapRepository;

      return await swapRepository.updatePaidSendSwap(
        swapId: swapId,
        txid: txid,
        absoluteFees: absoluteFees,
      );
    } catch (e) {
      rethrow;
    }
  }
}
