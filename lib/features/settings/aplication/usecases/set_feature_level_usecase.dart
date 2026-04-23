import 'package:bb_mobile/features/settings/aplication/ports/app_settings_repository_port.dart';
import 'package:bb_mobile/features/settings/aplication/settings_application_errors.dart';
import 'package:bb_mobile/features/settings/domain/primitives/feature_level.dart';

class SetFeatureLevelCommand {
  final FeatureLevel featureLevel;

  SetFeatureLevelCommand(this.featureLevel);
}

class SetFeatureLevelUsecase {
  final AppSettingsRepositoryPort _appSettingsRepository;

  SetFeatureLevelUsecase({
    required AppSettingsRepositoryPort appSettingsRepository,
  }) : _appSettingsRepository = appSettingsRepository;

  Future<void> execute(SetFeatureLevelCommand command) async {
    try {
      // Get current environment settings
      final appSettings = await _appSettingsRepository.loadSettings();
      final currentEnvironmentSettings = appSettings.environment;

      // Create new environment settings with updated feature level
      final newEnvironmentSettings = currentEnvironmentSettings.copyWith(
        featureLevel: command.featureLevel,
      );

      // Update the app settings with the new environment settings
      final updatedSettings = appSettings.copyWith(
        environment: newEnvironmentSettings,
      );

      // Save the updated settings
      await _appSettingsRepository.saveSettings(updatedSettings);
    } catch (e) {
      throw FailedToSetFeatureLevel('Failed to set feature level: $e');
    }
  }
}
