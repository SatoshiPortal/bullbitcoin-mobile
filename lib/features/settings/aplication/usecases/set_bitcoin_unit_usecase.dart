import 'package:bb_mobile/features/settings/aplication/ports/app_settings_repository_port.dart';
import 'package:bb_mobile/features/settings/aplication/settings_application_errors.dart';
import 'package:bb_mobile/features/settings/domain/primitives/bitcoin_unit.dart';

class SetBitcoinUnitCommand {
  final BitcoinUnit bitcoinUnit;

  SetBitcoinUnitCommand(this.bitcoinUnit);
}

class SetBitcoinUnitUsecase {
  final AppSettingsRepositoryPort _appSettingsRepository;

  SetBitcoinUnitUsecase({
    required AppSettingsRepositoryPort appSettingsRepository,
  }) : _appSettingsRepository = appSettingsRepository;

  Future<void> execute(SetBitcoinUnitCommand command) async {
    try {
      // Get current currency settings
      final appSettings = await _appSettingsRepository.loadSettings();
      final currentCurrencySettings = appSettings.currency;

      // Create new currency settings with updated bitcoin unit
      final newCurrencySettings = currentCurrencySettings.copyWith(
        bitcoinUnit: command.bitcoinUnit,
      );

      // Update the app settings with the new currency settings
      final updatedSettings = appSettings.copyWith(
        currency: newCurrencySettings,
      );

      // Save the updated settings
      await _appSettingsRepository.saveSettings(updatedSettings);
    } catch (e) {
      throw FailedToSetBitcoinUnit('Failed to set Bitcoin unit: $e');
    }
  }
}
