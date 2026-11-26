import 'package:ark/ark.dart';
import 'package:primitives/primitives.dart';

import '../ark_failure.dart';
import '../repositories/ark_repository.dart';
import '../repositories/ark_preferences_repository.dart';

final class SetArkEnabledUsecase {
  final ArkRepository _repository;
  final ArkPreferencesRepository _preferences;
  const SetArkEnabledUsecase(this._repository, this._preferences);

  Future<Result<void, ArkFailure>> execute(
    ArkAccountId account,
    bool enabled,
  ) async {
    // Off never closes or deletes native state, including funded accounts.
    if (!enabled) return _preferences.setEnabled(account, false);
    if (!NetworkCapabilities.supports(account.network, NetworkCapability.ark)) {
      return const Err(ArkNetworkUnavailableFailure());
    }
    switch (await _repository.read(account)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        if (value.account != account) return const Err(ArkUnexpectedFailure());
        if (value.recovery != ArkRecoveryStatus.complete) {
          return const Err(ArkAccountRecoveryFailure());
        }
        return _preferences.setEnabled(account, true);
    }
  }
}
