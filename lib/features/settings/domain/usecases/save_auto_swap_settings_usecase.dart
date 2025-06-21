import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/swap_repository.dart';

class SaveAutoSwapSettingsUsecase {
  final SwapRepository _swapRepository;

  SaveAutoSwapSettingsUsecase({required SwapRepository swapRepository})
    : _swapRepository = swapRepository;

  Future<void> execute(AutoSwap params) async {
    await _swapRepository.updateAutoSwapParams(params);
  }
}
