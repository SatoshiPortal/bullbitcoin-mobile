import 'package:preferences/preferences.dart' show AmountInputPreferences;
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';

class SetAmountInputModeUsecase {
  final AmountInputPreferences _preferences;

  const SetAmountInputModeUsecase(this._preferences);

  @useResult
  Future<Result<void, SettingsFailure>> execute({required bool fiat}) async =>
      (await _preferences.setStartAmountsInFiat(fiat))
          .mapErr((failure) => SettingsStorageFailure(failure.logMessage));
}
