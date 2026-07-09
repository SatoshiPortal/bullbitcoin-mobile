import 'package:bb_mobile/core/settings/data/settings_repository.dart';

class SetHideExchangeFeaturesUsecase {
  final SettingsRepository _settingsRepository;

  SetHideExchangeFeaturesUsecase({required this._settingsRepository});

  Future<void> execute(bool hide) async {
    await _settingsRepository.setHideExchangeFeatures(hide);
  }
}
