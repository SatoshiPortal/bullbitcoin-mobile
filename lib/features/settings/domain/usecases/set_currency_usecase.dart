import 'package:bb_mobile/core_deprecated/settings/data/settings_repository.dart';

class SetCurrencyUsecase {
  final SettingsRepository _settingsRepository;

  SetCurrencyUsecase({
    required SettingsRepository settingsRepository,
  }) : _settingsRepository = settingsRepository;

  Future<void> execute(String currencyCode) async {
    await _settingsRepository.setCurrency(currencyCode);
  }
}
