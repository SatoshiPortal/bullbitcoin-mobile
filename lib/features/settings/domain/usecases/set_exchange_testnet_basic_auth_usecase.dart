import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:meta/meta.dart';

class SetExchangeTestnetBasicAuthUsecase {
  final ExchangeTestnetBasicAuthPreferences _preferences;

  const SetExchangeTestnetBasicAuthUsecase({required this._preferences});

  @useResult
  Future<Result<void, SettingsFailure>> execute({
    String? username,
    String? password,
  }) async {
    final result = await _preferences.setExchangeTestnetBasicAuth(
      username: username,
      password: password,
    );

    return result.mapErr(
      (failure) => SettingsStorageFailure(failure.logMessage),
    );
  }
}
