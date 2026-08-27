import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/auto_swap_settings_repository.dart';

class GetAutoSwapSettingsUsecase {
  final AutoSwapSettingsRepository _repository;

  GetAutoSwapSettingsUsecase({required this._repository});

  Future<AutoSwap> execute() async {
    return _repository.getAutoSwapParams();
  }
}
