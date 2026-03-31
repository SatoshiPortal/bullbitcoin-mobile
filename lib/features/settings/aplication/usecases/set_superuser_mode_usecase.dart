import 'package:bb_mobile/features/settings/aplication/ports/app_settings_repository_port.dart';
import 'package:bb_mobile/features/settings/aplication/settings_application_errors.dart';

class SetSuperuserModeCommand {
  final bool superuserModeEnabled;

  SetSuperuserModeCommand(this.superuserModeEnabled);
}

class SetSuperuserModeUsecase {
  final AppSettingsRepositoryPort _appSettingsRepository;

  SetSuperuserModeUsecase({
    required AppSettingsRepositoryPort appSettingsRepository,
  }) : _appSettingsRepository = appSettingsRepository;

  Future<void> execute(SetSuperuserModeCommand command) async {
    try {
      // Get current environment settings
      final appSettings = await _appSettingsRepository.loadSettings();
      final currentEnvironmentSettings = appSettings.environment;

      // Create new environment settings with updated superuser mode
      final newEnvironmentSettings = currentEnvironmentSettings.copyWith(
        superuserModeEnabled: command.superuserModeEnabled,
      );

      // Update the app settings with the new environment settings
      final updatedSettings = appSettings.copyWith(
        environment: newEnvironmentSettings,
      );

      // Save the updated settings
      await _appSettingsRepository.saveSettings(updatedSettings);
    } catch (e) {
      throw FailedToSetSuperuserMode('Failed to set superuser mode: $e');
    }
  }
}
