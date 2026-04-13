import 'package:bb_mobile/features/settings/aplication/ports/app_settings_repository_port.dart';
import 'package:bb_mobile/features/settings/aplication/settings_application_errors.dart';
import 'package:bb_mobile/features/settings/domain/primitives/language.dart';

class SetLanguageCommand {
  final Language language;

  SetLanguageCommand(this.language);
}

class SetLanguageUsecase {
  final AppSettingsRepositoryPort _appSettingsRepository;

  SetLanguageUsecase({
    required AppSettingsRepositoryPort appSettingsRepository,
  }) : _appSettingsRepository = appSettingsRepository;

  Future<void> execute(SetLanguageCommand command) async {
    try {
      // Get current display settings
      final appSettings = await _appSettingsRepository.loadSettings();
      final currentDisplaySettings = appSettings.display;

      // Create new display settings with updated language
      final newDisplaySettings = currentDisplaySettings.copyWith(
        language: command.language,
      );

      // Update the app settings with the new display settings
      final updatedSettings = appSettings.copyWith(
        display: newDisplaySettings,
      );

      // Save the updated settings
      await _appSettingsRepository.saveSettings(updatedSettings);
    } catch (e) {
      throw FailedToSetLanguage('Failed to set language: $e');
    }
  }
}
