import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';

class UpdatePaidChainSwapUsecase {
  final BoltzSwapRepository _swapRepository;

  UpdatePaidChainSwapUsecase({required BoltzSwapRepository swapRepository})
    : _swapRepository = swapRepository;

  Future<void> execute({required String txid, required String swapId}) async {
    try {
      return await _swapRepository.updatePaidSendSwap(
        swapId: swapId,
        txid: txid,
      );
    } catch (e) {
      rethrow;
    }
  }
}
