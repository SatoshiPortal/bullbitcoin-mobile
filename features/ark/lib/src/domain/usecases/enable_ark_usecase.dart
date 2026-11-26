import 'package:ark/ark.dart';
import 'package:primitives/primitives.dart';

import '../ark_failure.dart';
import '../ark_provisioning_port.dart';
import '../repositories/ark_repository.dart';
import '../repositories/ark_preferences_repository.dart';

final class EnableArkUsecase {
  final ArkRepository _repository;
  final ArkProvisioningPort _provisioning;
  final ArkPreferencesRepository _preferences;
  const EnableArkUsecase(
    this._repository,
    this._preferences,
    this._provisioning,
  );

  Future<Result<ArkSnapshot, ArkFailure>> execute(
    ArkAccountConfig config, {
    required bool privacyDisclosureAccepted,
  }) async {
    if (!privacyDisclosureAccepted) {
      return const Err(ArkPrivacyDisclosureFailure());
    }
    if (!NetworkCapabilities.supports(
      config.id.network,
      NetworkCapability.ark,
    )) {
      return const Err(ArkNetworkUnavailableFailure());
    }
    final result = await _provisioning.run(
      config,
      () => _repository.create(config),
    );
    if (result case Ok(:final value)) {
      if (value.account != config.id) return const Err(ArkUnexpectedFailure());
      if (value.recovery != ArkRecoveryStatus.complete) {
        return const Err(ArkAccountRecoveryFailure());
      }
      final stored = await _preferences.setEnabled(config.id, true);
      if (stored case Err(:final failure)) return Err(failure);
    }
    return result;
  }
}
