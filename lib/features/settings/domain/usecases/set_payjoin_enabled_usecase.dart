import 'package:bb_mobile/core/settings/data/settings_repository.dart';

class SetPayjoinEnabledUsecase {
  final SettingsRepository _settingsRepository;

  SetPayjoinEnabledUsecase({required this._settingsRepository});

  Future<void> execute(bool enabled) async {
    await _settingsRepository.setPayjoinEnabled(enabled);
  }
}
