import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';

class SetThemeModeUsecase {
  final SettingsRepository _settingsRepository;

  SetThemeModeUsecase({required SettingsRepository settingsRepository})
    : _settingsRepository = settingsRepository;

  Future<void> execute(AppThemeMode themeMode) async {
    await _settingsRepository.setThemeMode(themeMode);
  }
}
