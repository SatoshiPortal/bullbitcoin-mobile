import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';

import '../entities/swap_failure.dart';
import '../entities/swap_route.dart';

abstract interface class SwapRouteSettingRepository {
  @useResult
  Future<Result<bool, SwapsFailure>> isExchangeFallbackEnabled();

  @useResult
  Future<Result<void, SwapsFailure>> setExchangeFallbackEnabled(bool enabled);

  @useResult
  Future<Result<SwapRouteOverride, SwapsFailure>> getRouteOverride();

  @useResult
  Future<Result<void, SwapsFailure>> setRouteOverride(
    SwapRouteOverride override,
  );
}
