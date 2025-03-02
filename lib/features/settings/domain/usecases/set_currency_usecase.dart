import 'package:bb_mobile/core/domain/repositories/settings_repository.dart';

class SetCurrencyUseCase {
  final SettingsRepository _settingsRepository;

  SetCurrencyUseCase({
    required SettingsRepository settingsRepository,
  }) : _settingsRepository = settingsRepository;

  Future<void> execute(String currencyCode) async {
    await _settingsRepository.setCurrency(currencyCode);
  }
}
