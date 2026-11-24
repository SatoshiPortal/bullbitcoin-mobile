import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:settings/src/domain/settings_failure.dart';
import 'package:meta/meta.dart';

class SetHideAmountsUsecase {
  final Preferences _settingsRepository;

  const SetHideAmountsUsecase({required this._settingsRepository});

  @useResult
  Future<Result<void, SettingsFailure>> execute(bool hide) async {
    final result = await _settingsRepository.setHideAmounts(hide);

    return result.mapErr(
      (failure) => SettingsStorageFailure(failure.logMessage),
    );
  }
}
