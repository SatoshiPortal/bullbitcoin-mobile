import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/swap/domain/entities/swap_route.dart';
import 'package:bb_mobile/features/swap/domain/repositories/swap_route_setting_repository.dart';
import 'package:bb_mobile/features/swap/domain/swap_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SwapRouteSettingRepositoryImpl implements SwapRouteSettingRepository {
  static const _exchangeFallbackKey = 'swaps.exchange_fallback.enabled';
  static const _routeOverrideKey = 'swaps.route_override';

  @override
  Future<Result<bool, SwapFailure>> isExchangeFallbackEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return Ok(prefs.getBool(_exchangeFallbackKey) ?? false);
    } catch (e, st) {
      log.warning(
        'Failed to read the swap fallback setting: ${e.runtimeType}',
        trace: st,
      );
      return const Err(SwapStorageFailure());
    }
  }

  @override
  Future<Result<void, SwapFailure>> setExchangeFallbackEnabled(
    bool enabled,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setBool(_exchangeFallbackKey, enabled)) {
        return const Err(
          SwapStorageFailure('Failed to persist the swap fallback setting'),
        );
      }
      return const Ok(null);
    } catch (e, st) {
      log.warning(
        'Failed to persist the swap fallback setting: ${e.runtimeType}',
        trace: st,
      );
      return const Err(SwapStorageFailure());
    }
  }

  @override
  Future<Result<SwapRouteOverride, SwapFailure>> getRouteOverride() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_routeOverrideKey);
      return Ok(
        SwapRouteOverride.values.firstWhere(
          (o) => o.name == stored,
          orElse: () => SwapRouteOverride.auto,
        ),
      );
    } catch (e, st) {
      log.warning(
        'Failed to read the swap route override: ${e.runtimeType}',
        trace: st,
      );
      return const Err(SwapStorageFailure());
    }
  }

  @override
  Future<Result<void, SwapFailure>> setRouteOverride(
    SwapRouteOverride override,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(_routeOverrideKey, override.name)) {
        return const Err(
          SwapStorageFailure('Failed to persist the swap route override'),
        );
      }
      return const Ok(null);
    } catch (e, st) {
      log.warning(
        'Failed to persist the swap route override: ${e.runtimeType}',
        trace: st,
      );
      return const Err(SwapStorageFailure());
    }
  }
}
