import 'package:bb_mobile/core/swaps/domain/repositories/swap_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class UpdatePaidSendSwapUsecase {
  final SwapRepository _swapRepository;
  final SwapRepository _swapRepositoryTestnet;

  UpdatePaidSendSwapUsecase({
    required SwapRepository swapRepository,
    required SwapRepository swapRepositoryTestnet,
  })  : _swapRepository = swapRepository,
        _swapRepositoryTestnet = swapRepositoryTestnet;

  Future<void> execute({
    required String txid,
    required String swapId,
    required Network network,
  }) async {
    try {
      final swapRepository =
          network.isTestnet ? _swapRepositoryTestnet : _swapRepository;

      return await swapRepository.updatePaidSendSwap(
        swapId: swapId,
        txid: txid,
      );
    } catch (e) {
      rethrow;
    }
  }
}
