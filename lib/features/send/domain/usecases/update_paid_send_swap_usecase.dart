import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class UpdatePaidSendSwapUsecase {
  final BoltzSwapRepository _swapRepository;
  final BoltzSwapRepository _swapRepositoryTestnet;

  UpdatePaidSendSwapUsecase({
    required BoltzSwapRepository swapRepository,
    required BoltzSwapRepository swapRepositoryTestnet,
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
