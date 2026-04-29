import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';

class UpdateSendSwapLockupFeesUsecase {
  final BoltzSwapRepository _swapRepository;

  UpdateSendSwapLockupFeesUsecase({required BoltzSwapRepository swapRepository})
    : _swapRepository = swapRepository;

  Future<Swap> execute({
    required String swapId,
    required int lockupFees,
  }) async {
    try {
      return await _swapRepository.updateSendSwapLockupFees(
        swapId: swapId,
        lockupFees: lockupFees,
      );
    } catch (e) {
      rethrow;
    }
  }
}
