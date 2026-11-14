import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/swap/domain/entities/swap_route.dart';
import 'package:bb_mobile/features/swap/domain/repositories/swap_route_setting_repository.dart';
import 'package:bull_logger/bull_logger.dart';

class GetSwapRouteUsecase {
  final SwapRouteSettingRepository _swapRouteSettingRepository;
  final SettingsRepository _settingsRepository;

  GetSwapRouteUsecase({
    required this._swapRouteSettingRepository,
    required this._settingsRepository,
  });

  Future<SwapRoute> execute() async {
    final exchangeFallbackEnabled = switch (await _swapRouteSettingRepository
        .isExchangeFallbackEnabled()) {
      Ok(:final value) => value,
      Err() => false,
    };
    final override = switch (await _swapRouteSettingRepository
        .getRouteOverride()) {
      Ok(:final value) => value,
      Err() => SwapRouteOverride.auto,
    };
    var devModeEnabled = false;
    try {
      devModeEnabled =
          (await _settingsRepository.fetch()).isDevModeEnabled ?? false;
    } catch (e) {
      log.warning('Swap route: settings unreadable (${e.runtimeType})');
    }
    return SwapRoute.resolve(
      exchangeFallbackEnabled: exchangeFallbackEnabled,
      devModeEnabled: devModeEnabled,
      override: override,
    );
  }
}
