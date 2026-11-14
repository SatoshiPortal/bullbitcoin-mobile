import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/swap/domain/entities/swap_route.dart';
import 'package:bb_mobile/features/swap/domain/repositories/swap_route_setting_repository.dart';
import 'package:bb_mobile/features/swap/domain/swap_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

class GetSwapRouteSettingsUsecase {
  final SwapRouteSettingRepository _swapRouteSettingRepository;
  final SettingsRepository _settingsRepository;

  GetSwapRouteSettingsUsecase({
    required this._swapRouteSettingRepository,
    required this._settingsRepository,
  });

  @useResult
  Future<Result<SwapRouteSettings, SwapFailure>> execute() async {
    final bool exchangeFallbackEnabled;
    switch (await _swapRouteSettingRepository.isExchangeFallbackEnabled()) {
      case Ok(:final value):
        exchangeFallbackEnabled = value;
      case Err(:final failure):
        return Err(failure);
    }
    final SwapRouteOverride override;
    switch (await _swapRouteSettingRepository.getRouteOverride()) {
      case Ok(:final value):
        override = value;
      case Err(:final failure):
        return Err(failure);
    }
    var devModeEnabled = false;
    try {
      devModeEnabled =
          (await _settingsRepository.fetch()).isDevModeEnabled ?? false;
    } catch (e) {
      log.warning('Swap settings: settings unreadable (${e.runtimeType})');
    }
    return Ok((
      exchangeFallbackEnabled: exchangeFallbackEnabled,
      override: override,
      devModeEnabled: devModeEnabled,
    ));
  }
}
