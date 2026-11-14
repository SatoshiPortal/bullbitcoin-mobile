import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/swap/domain/entities/swap_route.dart';
import 'package:bb_mobile/features/swap/domain/repositories/swap_route_setting_repository.dart';
import 'package:bb_mobile/features/swap/domain/swap_failure.dart';
import 'package:meta/meta.dart';

class SetSwapRouteOverrideUsecase {
  final SwapRouteSettingRepository _swapRouteSettingRepository;

  const SetSwapRouteOverrideUsecase(this._swapRouteSettingRepository);

  @useResult
  Future<Result<void, SwapFailure>> execute(SwapRouteOverride override) =>
      _swapRouteSettingRepository.setRouteOverride(override);
}
