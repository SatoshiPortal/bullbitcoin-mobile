import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:settings/src/domain/settings_failure.dart';
import 'package:meta/meta.dart';

class SetLanguageUsecase {
  final Preferences _settingsRepository;

  const SetLanguageUsecase({required this._settingsRepository});

  @useResult
  Future<Result<void, SettingsFailure>> execute(Language language) async {
    final result = await _settingsRepository.setLanguage(language);

    return result.mapErr(
      (failure) => SettingsStorageFailure(failure.logMessage),
    );
  }
}
