import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_preferences_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_failure.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_registration.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_wallet.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/lookup_wallet_owned_lightning_address_registration_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/prepare_lightning_address_wallet_usecase.dart';

class LightningAddressReceiveReadiness {
  final LightningAddressStatus registration;
  final bool localSetupFailed;
  final bool localSetupRetryable;
  final bool autoSweepEnabled;

  const LightningAddressReceiveReadiness({
    required this.registration,
    this.localSetupFailed = false,
    this.localSetupRetryable = false,
    this.autoSweepEnabled = false,
  });

  bool get receiveReady => registration.active && !localSetupFailed;
}

class LookupLightningAddressReceiveReadinessUsecase {
  final LookupWalletOwnedLightningAddressRegistrationUsecase
  _lookupRegistration;
  final PrepareLightningAddressWalletUsecase _prepareWallet;
  final GetWalletPreferencesUsecase _getWalletPreferences;

  const LookupLightningAddressReceiveReadinessUsecase(
    this._lookupRegistration,
    this._prepareWallet,
    this._getWalletPreferences,
  );

  Future<Result<LightningAddressReceiveReadiness, LightningAddressFailure>>
  execute() async {
    final registrationResult = await _lookupRegistration.execute();
    final LightningAddressStatus registration;
    switch (registrationResult) {
      case Ok(:final value):
        registration = value;
      case Err(:final failure):
        return Err(failure);
    }
    if (!registration.active) {
      return Ok(LightningAddressReceiveReadiness(registration: registration));
    }

    final preparedResult = await _prepareWallet.execute();
    final PreparedLightningAddressWallet prepared;
    switch (preparedResult) {
      case Ok(:final value):
        prepared = value;
      case Err(:final failure):
        if (failure.kind != LightningAddressFailureKind.localPreparation) {
          return Err(failure);
        }
        return Ok(
          LightningAddressReceiveReadiness(
            registration: registration,
            localSetupFailed: true,
            localSetupRetryable: failure.retryable,
          ),
        );
    }

    // R2-D1b: the "autosweep enabled" copy must reflect the wallet's actual
    // behavior metadata, not the intended default. Defaults are applied only
    // when missing, so a wallet a user previously opted out of stays opted
    // out; read the persisted value back and only claim autosweep when it is
    // truly on. A read failure softens the claim rather than failing
    // readiness - the receive wallet itself is prepared.
    final preferences = await _getWalletPreferences.execute();
    final autoSweepEnabled = switch (preferences) {
      Ok(:final value) =>
        value
                .where((item) => item.walletRef == prepared.walletId)
                .firstOrNull
                ?.autoSweepEnabled ??
            false,
      Err() => false,
    };

    return Ok(
      LightningAddressReceiveReadiness(
        registration: registration,
        autoSweepEnabled: autoSweepEnabled,
      ),
    );
  }
}
