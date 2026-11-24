import 'package:meta/meta.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';

import '../log.dart';
import 'entities/swap_failure.dart';
import 'entities/swap_route.dart';
import 'repositories/swap_route_setting_repository.dart';

/// Reads and changes the swap provider choices without exposing their storage.
abstract interface class SwapRouting {
  /// Resolves the operating route, using safe defaults for unreadable choices.
  Future<SwapRoute> resolveRoute();

  /// Reads the stored choices for editing, without masking storage failures.
  @useResult
  Future<Result<SwapRouteSettings, SwapsFailure>> readRouteSettings();

  @useResult
  Future<Result<void, SwapsFailure>> setExchangeFallbackEnabled(bool enabled);

  @useResult
  Future<Result<void, SwapsFailure>> setRouteOverride(
    SwapRouteOverride override,
  );
}

final class StoredSwapRouting implements SwapRouting {
  final SwapRouteSettingRepository _repository;
  final Preferences _preferences;

  const StoredSwapRouting(this._repository, this._preferences);

  @override
  Future<SwapRoute> resolveRoute() async {
    final fallback = (await _repository.isExchangeFallbackEnabled()).fold(
      (value) => value,
      (_) => false,
    );
    final override = (await _repository.getRouteOverride()).fold(
      (value) => value,
      (_) => SwapRouteOverride.auto,
    );
    return SwapRoute.resolve(
      exchangeFallbackEnabled: fallback,
      devModeEnabled: await _devMode(),
      override: override,
    );
  }

  @override
  Future<Result<SwapRouteSettings, SwapsFailure>> readRouteSettings() async {
    final bool fallback;
    switch (await _repository.isExchangeFallbackEnabled()) {
      case Ok(:final value):
        fallback = value;
      case Err(:final failure):
        return Err(failure);
    }
    final SwapRouteOverride override;
    switch (await _repository.getRouteOverride()) {
      case Ok(:final value):
        override = value;
      case Err(:final failure):
        return Err(failure);
    }
    return Ok((
      exchangeFallbackEnabled: fallback,
      override: override,
      devModeEnabled: await _devMode(),
    ));
  }

  @override
  Future<Result<void, SwapsFailure>> setExchangeFallbackEnabled(bool enabled) =>
      _repository.setExchangeFallbackEnabled(enabled);

  @override
  Future<Result<void, SwapsFailure>> setRouteOverride(
    SwapRouteOverride override,
  ) => _repository.setRouteOverride(override);

  Future<bool> _devMode() async {
    try {
      switch (await _preferences.fetch()) {
        case Ok(:final value):
          return value.isDevModeEnabled ?? false;
        case Err(:final failure):
          swapsLog.warning(
            'Swap route: settings unreadable (${failure.runtimeType})',
          );
      }
    } on Exception catch (error) {
      swapsLog.warning(
        'Swap route: settings unreadable (${error.runtimeType})',
      );
    }
    return false;
  }
}
