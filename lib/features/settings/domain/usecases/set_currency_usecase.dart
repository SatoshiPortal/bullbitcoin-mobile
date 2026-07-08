import 'package:bb_mobile/core/settings/data/settings_repository.dart';

class SetCurrencyUsecase {
  final SettingsRepository _settingsRepository;

  SetCurrencyUsecase({required this._settingsRepository});

  Future<void> execute(String currencyCode) async {
    await _settingsRepository.setCurrency(currencyCode);
  }
}
