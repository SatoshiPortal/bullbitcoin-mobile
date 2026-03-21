import 'package:bb_mobile/features/settings/aplication/ports/app_settings_repository_port.dart';
import 'package:bb_mobile/features/settings/aplication/settings_application_errors.dart';
import 'package:bb_mobile/features/settings/domain/primitives/theme_mode.dart';

class SetThemeModeCommand {
  final ThemeMode themeMode;

  SetThemeModeCommand(this.themeMode);
}

class SetThemeModeUsecase {
  final AppSettingsRepositoryPort _appSettingsRepository;

  SetThemeModeUsecase({
    required AppSettingsRepositoryPort appSettingsRepository,
  }) : _appSettingsRepository = appSettingsRepository;

  Future<void> execute(SetThemeModeCommand command) async {
    try {
      // Get current display settings
      final appSettings = await _appSettingsRepository.loadSettings();
      final currentDisplaySettings = appSettings.display;

      // Create new display settings with updated theme mode
      final newDisplaySettings = currentDisplaySettings.copyWith(
        themeMode: command.themeMode,
      );

      // Update the app settings with the new display settings
      final updatedSettings = appSettings.copyWith(
        display: newDisplaySettings,
      );

      // Save the updated settings
      await _appSettingsRepository.saveSettings(updatedSettings);
    } catch (e) {
      throw FailedToSetThemeMode('Failed to set theme mode: $e');
    }
  }
}
