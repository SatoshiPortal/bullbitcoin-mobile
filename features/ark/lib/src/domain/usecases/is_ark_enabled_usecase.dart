import 'package:ark/ark.dart';
import 'package:primitives/primitives.dart';

import '../ark_failure.dart';
import '../repositories/ark_preferences_repository.dart';

final class IsArkEnabledUsecase {
  final ArkPreferencesRepository _preferences;
  const IsArkEnabledUsecase(this._preferences);
  Future<Result<bool, ArkFailure>> execute(ArkAccountId account) =>
      _preferences.isEnabled(account);
}
