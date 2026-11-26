import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:settings/src/domain/settings_failure.dart';
import 'package:meta/meta.dart';

class SetThemeModeUsecase {
  final Preferences _settingsRepository;

  const SetThemeModeUsecase({required this._settingsRepository});

  @useResult
  Future<Result<void, SettingsFailure>> execute(AppThemeMode themeMode) async {
    final result = await _settingsRepository.setThemeMode(themeMode);

    return result.mapErr(
      (failure) => SettingsStorageFailure(failure.logMessage),
    );
  }
}
