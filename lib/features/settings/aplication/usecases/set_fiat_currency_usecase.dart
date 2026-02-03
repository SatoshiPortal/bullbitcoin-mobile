import 'package:bb_mobile/features/settings/aplication/ports/app_settings_repository_port.dart';
import 'package:bb_mobile/features/settings/aplication/settings_application_errors.dart';
import 'package:bb_mobile/features/settings/domain/primitives/bitcoin_unit.dart';
import 'package:bb_mobile/features/settings/domain/primitives/fiat_currency.dart';

class SetFiatCurrencyCommand {
  final FiatCurrency fiatCurrency;

  SetFiatCurrencyCommand(this.fiatCurrency);
}

class SetFiatCurrencyUsecase {
  final AppSettingsRepositoryPort _appSettingsRepository;

  SetFiatCurrencyUsecase({
    required AppSettingsRepositoryPort appSettingsRepository,
  }) : _appSettingsRepository = appSettingsRepository;

  Future<void> execute(SetFiatCurrencyCommand command) async {
    try {
      // Get current currency settings
      final appSettings = await _appSettingsRepository.loadSettings();
      final currentCurrencySettings = appSettings.currency;

      // Create new currency settings with updated bitcoin unit
      final newCurrencySettings = currentCurrencySettings.copyWith(
        fiatCurrency: command.fiatCurrency,
      );

      // Update the app settings with the new currency settings
      final updatedSettings = appSettings.copyWith(
        currency: newCurrencySettings,
      );

      // Save the updated settings
      await _appSettingsRepository.saveSettings(updatedSettings);
    } catch (e) {
      throw FailedToSetFiatCurrency('Failed to set Fiat currency: $e');
    }
  }
}
