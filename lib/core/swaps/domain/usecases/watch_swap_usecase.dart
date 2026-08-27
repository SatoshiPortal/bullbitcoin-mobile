import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';

class WatchSwapUsecase {
  final BoltzSwapRepository _swapRepository;

  WatchSwapUsecase({required this._swapRepository});

  Stream<Swap> execute(String swapId) {
    try {
      return _swapRepository.watchSwap(swapId: swapId);
    } catch (e) {
      throw WatchSwapException(e.toString());
    }
  }
}

class WatchSwapException extends BullException {
  WatchSwapException(super.message);
}
