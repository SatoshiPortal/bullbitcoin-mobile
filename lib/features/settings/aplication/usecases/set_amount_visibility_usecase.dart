import 'package:bb_mobile/features/settings/aplication/ports/app_settings_repository_port.dart';
import 'package:bb_mobile/features/settings/aplication/settings_application_errors.dart';

class SetAmountVisibilityCommand {
  final bool hideAmounts;

  SetAmountVisibilityCommand(this.hideAmounts);
}

class SetAmountVisibilityUsecase {
  final AppSettingsRepositoryPort _appSettingsRepository;

  SetAmountVisibilityUsecase({
    required AppSettingsRepositoryPort appSettingsRepository,
  }) : _appSettingsRepository = appSettingsRepository;

  Future<void> execute(SetAmountVisibilityCommand command) async {
    try {
      // Get current display settings
      final appSettings = await _appSettingsRepository.loadSettings();
      final currentDisplaySettings = appSettings.display;

      // Create new display settings with updated amount visibility
      final newDisplaySettings = currentDisplaySettings.copyWith(
        hideAmounts: command.hideAmounts,
      );

      // Update the app settings with the new display settings
      final updatedSettings = appSettings.copyWith(
        display: newDisplaySettings,
      );

      // Save the updated settings
      await _appSettingsRepository.saveSettings(updatedSettings);
    } catch (e) {
      throw FailedToSetAmountVisibility('Failed to set amount visibility: $e');
    }
  }
}
