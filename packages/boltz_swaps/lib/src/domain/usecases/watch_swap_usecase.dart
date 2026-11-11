import 'package:boltz_swaps/src/domain/entities/swap.dart';
import 'package:boltz_swaps/src/domain/swap_repository.dart';

class WatchSwapUsecase {
  final SwapRepository _swapRepository;

  WatchSwapUsecase({required this._swapRepository});

  Stream<Swap> execute(String swapId) => _swapRepository.watch(swapId);
}
