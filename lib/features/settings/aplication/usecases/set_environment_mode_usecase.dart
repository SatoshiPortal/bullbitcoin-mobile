import 'package:bb_mobile/features/settings/aplication/ports/app_settings_repository_port.dart';
import 'package:bb_mobile/features/settings/aplication/settings_application_errors.dart';
import 'package:bb_mobile/features/settings/domain/primitives/environment_mode.dart';

class SetEnvironmentModeCommand {
  final EnvironmentMode environmentMode;

  SetEnvironmentModeCommand(this.environmentMode);
}

class SetEnvironmentModeUsecase {
  final AppSettingsRepositoryPort _appSettingsRepository;

  SetEnvironmentModeUsecase({
    required AppSettingsRepositoryPort appSettingsRepository,
  }) : _appSettingsRepository = appSettingsRepository;

  Future<void> execute(SetEnvironmentModeCommand command) async {
    try {
      // Get current environment settings
      final appSettings = await _appSettingsRepository.loadSettings();
      final currentEnvironmentSettings = appSettings.environment;

      // Create new environment settings with updated environment mode
      final newEnvironmentSettings = currentEnvironmentSettings.copyWith(
        environmentMode: command.environmentMode,
      );

      // Update the app settings with the new environment settings
      final updatedSettings = appSettings.copyWith(
        environment: newEnvironmentSettings,
      );

      // Save the updated settings
      await _appSettingsRepository.saveSettings(updatedSettings);
    } catch (e) {
      throw FailedToSetEnvironmentMode('Failed to set environment mode: $e');
    }
  }
}
