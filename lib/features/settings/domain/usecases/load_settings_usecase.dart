import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';

import '../settings_failure.dart';

class LoadSettingsUsecase {
  final Preferences _preferences;

  const LoadSettingsUsecase(this._preferences);

  Future<Result<SettingsEntity, SettingsFailure>> execute() async =>
      (await _preferences.fetch()).mapErr(
        (failure) => SettingsUnexpectedFailure(failure.logMessage),
      );
}
