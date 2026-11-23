import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:settings/src/domain/settings_failure.dart';
import 'package:meta/meta.dart';

class SetIsSuperuserUsecase {
  final Preferences _settingsRepository;

  const SetIsSuperuserUsecase({required this._settingsRepository});

  @useResult
  Future<Result<void, SettingsFailure>> execute(bool superuser) async {
    final result = await _settingsRepository.setIsSuperuser(superuser);

    return result.mapErr(
      (failure) => SettingsStorageFailure(failure.logMessage),
    );
  }
}
