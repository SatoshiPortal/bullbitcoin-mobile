
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';

class SetCurrencyUsecase {
  final SettingsRepository _settingsRepository;

  SetCurrencyUsecase({
    required SettingsRepository settingsRepository,
  }) : _settingsRepository = settingsRepository;

  Future<void> execute(String currencyCode) async {
    await _settingsRepository.setCurrency(currencyCode);
  }
}
