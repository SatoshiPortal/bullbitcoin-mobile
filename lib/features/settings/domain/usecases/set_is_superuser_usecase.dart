import 'package:bb_mobile/core/settings/data/settings_repository.dart';

class SetIsSuperuserUsecase {
  final SettingsRepository _settingsRepository;

  SetIsSuperuserUsecase({required this._settingsRepository});

  Future<void> execute(bool hide) async {
    await _settingsRepository.setIsSuperuser(hide);
  }
}
