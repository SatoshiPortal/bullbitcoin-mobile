import 'package:bb_mobile/core/settings/data/settings_repository.dart';

class SetScreenCaptureProtectionUsecase {
  final SettingsRepository _settingsRepository;

  SetScreenCaptureProtectionUsecase({required this._settingsRepository});

  Future<void> execute(bool enabled) async {
    await _settingsRepository.setScreenCaptureProtectionEnabled(enabled);
  }
}
