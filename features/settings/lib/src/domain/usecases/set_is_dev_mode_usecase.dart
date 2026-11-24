import 'package:bull_logger/bull_logger.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:settings/src/domain/settings_failure.dart';
import 'package:meta/meta.dart';

class SetIsDevModeUsecase {
  final Preferences _settingsRepository;

  const SetIsDevModeUsecase({required this._settingsRepository});

  @useResult
  Future<Result<void, SettingsFailure>> execute(bool isEnabled) async {
    final result = await _settingsRepository.setIsDevMode(isEnabled);

    if (result is Ok) {
      log.config(
        'Developer mode saved enabled=$isEnabled${isEnabled ? '' : ' network=mainnet'}',
      );
    }
    return result.mapErr(
      (failure) => SettingsStorageFailure(failure.logMessage),
    );
  }
}
