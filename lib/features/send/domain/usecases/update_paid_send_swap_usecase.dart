import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';

class UpdatePaidSendSwapUsecase {
  final BoltzSwapRepository _swapRepository;

  UpdatePaidSendSwapUsecase({required BoltzSwapRepository swapRepository})
    : _swapRepository = swapRepository;

  Future<void> execute({
    required String txid,
    required String swapId,
    required int absoluteFees,
  }) async {
    try {
      return await _swapRepository.updatePaidSendSwap(
        swapId: swapId,
        txid: txid,
        absoluteFees: absoluteFees,
      );
    } catch (e) {
      rethrow;
    }
  }
}
