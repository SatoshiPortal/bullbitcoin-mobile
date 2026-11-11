import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/swap/domain/entities/swap_route.dart';
import 'package:bb_mobile/features/swap/domain/swap_failure.dart';
import 'package:meta/meta.dart';

abstract interface class SwapRouteSettingRepository {
  @useResult
  Future<Result<bool, SwapFailure>> isExchangeFallbackEnabled();

  @useResult
  Future<Result<void, SwapFailure>> setExchangeFallbackEnabled(bool enabled);

  @useResult
  Future<Result<SwapRouteOverride, SwapFailure>> getRouteOverride();

  @useResult
  Future<Result<void, SwapFailure>> setRouteOverride(
    SwapRouteOverride override,
  );
}
