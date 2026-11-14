import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/swap/domain/repositories/swap_route_setting_repository.dart';
import 'package:bb_mobile/features/swap/domain/swap_failure.dart';
import 'package:meta/meta.dart';

class SetSwapExchangeFallbackUsecase {
  final SwapRouteSettingRepository _swapRouteSettingRepository;

  const SetSwapExchangeFallbackUsecase(this._swapRouteSettingRepository);

  @useResult
  Future<Result<void, SwapFailure>> execute(bool enabled) =>
      _swapRouteSettingRepository.setExchangeFallbackEnabled(enabled);
}
