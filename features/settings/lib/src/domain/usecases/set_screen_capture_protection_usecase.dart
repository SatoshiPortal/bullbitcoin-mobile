import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:settings/src/domain/settings_failure.dart';
import 'package:meta/meta.dart';

class SetScreenCaptureProtectionUsecase {
  final Preferences _settingsRepository;

  const SetScreenCaptureProtectionUsecase({required this._settingsRepository});

  @useResult
  Future<Result<void, SettingsFailure>> execute(bool enabled) async {
    final result = await _settingsRepository.setScreenCaptureProtectionEnabled(
      enabled,
    );

    return result.mapErr(
      (failure) => SettingsStorageFailure(failure.logMessage),
    );
  }
}
