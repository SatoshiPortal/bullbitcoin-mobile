import 'package:bb_mobile/core/settings/data/settings_repository.dart';

class SetIsDevModeUsecase {
  final SettingsRepository _settingsRepository;

  SetIsDevModeUsecase({required SettingsRepository settingsRepository})
    : _settingsRepository = settingsRepository;

  Future<void> execute(bool isEnabled) async {
    await _settingsRepository.setIsDevMode(isEnabled);
  }
}
