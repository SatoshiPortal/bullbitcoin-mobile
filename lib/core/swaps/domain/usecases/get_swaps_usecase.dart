import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';

class GetSwapsUsecase {
  final BoltzSwapRepository _boltzSwapRepository;

  GetSwapsUsecase({required BoltzSwapRepository boltzSwapRepository})
    : _boltzSwapRepository = boltzSwapRepository;

  Future<List<Swap>> execute({String? walletId}) async {
    try {
      return await _boltzSwapRepository.getAllSwaps(walletId: walletId);
    } catch (e) {
      throw GetSwapsException('Failed to fetch swaps: $e');
    }
  }
}

class GetSwapsException extends BullException {
  GetSwapsException(super.message);
}
