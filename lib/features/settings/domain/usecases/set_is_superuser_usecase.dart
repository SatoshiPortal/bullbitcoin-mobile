import 'package:bb_mobile/core_deprecated/settings/data/settings_repository.dart';

class SetIsSuperuserUsecase {
  final SettingsRepository _settingsRepository;

  SetIsSuperuserUsecase({required SettingsRepository settingsRepository})
    : _settingsRepository = settingsRepository;

  Future<void> execute(bool hide) async {
    await _settingsRepository.setIsSuperuser(hide);
  }
}
