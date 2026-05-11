import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';

class GetSwapUsecase {
  final BoltzSwapRepository _boltzSwapRepository;

  GetSwapUsecase({required BoltzSwapRepository boltzSwapRepository})
    : _boltzSwapRepository = boltzSwapRepository;

  Future<Swap> execute(String swapId) async {
    try {
      return await _boltzSwapRepository.getSwap(swapId: swapId);
    } catch (e) {
      throw GetSwapException('$e');
    }
  }
}

class GetSwapException extends BullException {
  GetSwapException(super.message);
}
