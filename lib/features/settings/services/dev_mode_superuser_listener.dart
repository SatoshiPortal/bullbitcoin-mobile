import 'dart:async';

import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_is_dev_mode_usecase.dart';

class DevModeSuperuserListener {
  final SettingsRepository _settingsRepository;
  final SetIsDevModeUsecase _setIsDevModeUsecase;
  StreamSubscription? _subscription;

  DevModeSuperuserListener({
    required SettingsRepository settingsRepository,
    required SetIsDevModeUsecase setIsDevModeUsecase,
  })  : _settingsRepository = settingsRepository,
        _setIsDevModeUsecase = setIsDevModeUsecase;

  void start() {
    _subscription =
        _settingsRepository.superuserModeChangeStream.listen((isEnabled) {
      if (!isEnabled) {
        _handleSuperuserModeDisabled();
      }
    });
  }

  Future<void> _handleSuperuserModeDisabled() async {
    try {
      await _setIsDevModeUsecase.execute(false);
      log.info('Dev mode disabled due to superuser mode being turned off');
    } catch (e) {
      log.severe('Failed to disable dev mode when superuser mode was disabled: $e');
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
  }
}
