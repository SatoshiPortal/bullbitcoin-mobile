import 'package:ark/ark.dart';
import 'package:primitives/primitives.dart';

import '../ark_failure.dart';
import '../repositories/ark_preferences_repository.dart';
import '../repositories/ark_repository.dart';

final class CreateArkReceiveUsecase {
  final ArkRepository _repository;
  final ArkPreferencesRepository _preferences;
  const CreateArkReceiveUsecase(this._repository, this._preferences);

  Future<Result<ArkReceiveDestination, ArkFailure>> execute(
    ArkAccountId account,
    ArkReceiveRequest request,
  ) async {
    if (!NetworkCapabilities.supports(account.network, NetworkCapability.ark)) {
      return const Err(ArkNetworkUnavailableFailure());
    }
    switch (await _preferences.isEnabled(account)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: false):
        return const Err(ArkDisabledFailure());
      case Ok():
        return _repository.receive(account, request);
    }
  }
}
