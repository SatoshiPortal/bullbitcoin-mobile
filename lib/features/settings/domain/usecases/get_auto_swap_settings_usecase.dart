import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/swap_repository.dart';

class GetAutoSwapSettingsUsecase {
  final SwapRepository _swapRepository;

  GetAutoSwapSettingsUsecase({required SwapRepository swapRepository})
    : _swapRepository = swapRepository;

  Future<AutoSwap> execute() async {
    return await _swapRepository.getAutoSwapParams();
  }
}
