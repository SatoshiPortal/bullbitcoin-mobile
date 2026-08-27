import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/auto_swap_settings_repository.dart';

class WatchAutoSwapSettingsUsecase {
  final AutoSwapSettingsRepository _repository;

  WatchAutoSwapSettingsUsecase({required this._repository});

  Stream<AutoSwap> execute() => _repository.watchAutoSwapParams();
}
