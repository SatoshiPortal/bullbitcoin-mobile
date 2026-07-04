import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_error.dart';
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
  final GetWalletUsecase _getWallet;

  const LookupLightningAddressReceiveReadinessUsecase({
    required this._lookupRegistration,
    required this._prepareWallet,
    required this._getWallet,
  });

  Future<LightningAddressReceiveReadiness> execute() async {
    final registration = await _lookupRegistration.execute();
    if (!registration.active) {
      return LightningAddressReceiveReadiness(registration: registration);
    }

    final PreparedLightningAddressWallet prepared;
    try {
      prepared = await _prepareWallet.execute();
    } on LightningAddressException catch (e) {
      if (e.kind != LightningAddressErrorKind.localPreparationFailed) {
        rethrow;
      }
      return LightningAddressReceiveReadiness(
        registration: registration,
        localSetupFailed: true,
        localSetupRetryable: e.retryable,
      );
    }

    // R2-D1b: the "autosweep enabled" copy must reflect the wallet's actual
    // behavior metadata, not the intended default. Defaults are applied only
    // when missing, so a wallet a user previously opted out of stays opted
    // out; read the persisted value back and only claim autosweep when it is
    // truly on. A read failure softens the claim rather than failing
    // readiness - the receive wallet itself is prepared.
    var autoSweepEnabled = false;
    try {
      final wallet = await _getWallet.execute(prepared.walletId);
      autoSweepEnabled = wallet?.autoSweepEnabled ?? false;
    } on GetWalletException {
      autoSweepEnabled = false;
    }

    return LightningAddressReceiveReadiness(
      registration: registration,
      autoSweepEnabled: autoSweepEnabled,
    );
  }
}
