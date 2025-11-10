import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class UpdateSendSwapLockupFeesUsecase {
  final BoltzSwapRepository _swapRepository;
  final BoltzSwapRepository _swapRepositoryTestnet;

  UpdateSendSwapLockupFeesUsecase({
    required BoltzSwapRepository swapRepository,
    required BoltzSwapRepository swapRepositoryTestnet,
  }) : _swapRepository = swapRepository,
       _swapRepositoryTestnet = swapRepositoryTestnet;

  Future<Swap> execute({
    required String swapId,
    required Network network,
    required int lockupFees,
  }) async {
    try {
      final swapRepository =
          network.isTestnet ? _swapRepositoryTestnet : _swapRepository;

      return await swapRepository.updateSendSwapLockupFees(
        swapId: swapId,
        lockupFees: lockupFees,
      );
    } catch (e) {
      rethrow;
    }
  }
}
