import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_failure.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_registration.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_registration_liveness.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_wallet.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_wallet_registration.dart';

export 'package:bb_mobile/features/lightning_address/domain/lightning_address_failure.dart';
export 'package:bb_mobile/features/lightning_address/domain/lightning_address_registration.dart';
export 'package:bb_mobile/features/lightning_address/domain/lightning_address_registration_liveness.dart';
export 'package:bb_mobile/features/lightning_address/domain/lightning_address_wallet.dart'
    show PreparedLightningAddressWallet;
export 'package:bb_mobile/features/lightning_address/domain/lightning_address_wallet_registration.dart'
    show WalletOwnedLightningAddressRegistration;

final class LightningAddressFacade {
  final Future<Result<PreparedLightningAddressWallet, LightningAddressFailure>>
  Function({bool recordAsRecovery})
  _prepareWallet;
  final Future<
    Result<WalletOwnedLightningAddressRegistration, LightningAddressFailure>
  >
  Function({required String nym})
  _registerWalletOwned;
  final Future<Result<LightningAddressStatus, LightningAddressFailure>>
  Function()
  _lookupRegistration;
  final Future<LightningAddressHealOutcome> Function({
    DateTime? deadline,
    bool allowReregister,
  })
  _ensureRegistrationLive;

  const LightningAddressFacade(
    Future<Result<PreparedLightningAddressWallet, LightningAddressFailure>>
    Function({bool recordAsRecovery})
    prepareWallet,
    Future<
      Result<WalletOwnedLightningAddressRegistration, LightningAddressFailure>
    >
    Function({required String nym})
    registerWalletOwned,
    Future<Result<LightningAddressStatus, LightningAddressFailure>> Function()
    lookupWalletOwnedRegistration,
    Future<LightningAddressHealOutcome> Function({
      DateTime? deadline,
      bool allowReregister,
    })
    ensureRegistrationLive,
  ) : _prepareWallet = prepareWallet,
      _registerWalletOwned = registerWalletOwned,
      _lookupRegistration = lookupWalletOwnedRegistration,
      _ensureRegistrationLive = ensureRegistrationLive;

  Future<Result<PreparedLightningAddressWallet, LightningAddressFailure>>
  prepareWallet({bool recordAsRecovery = false}) =>
      _prepareWallet(recordAsRecovery: recordAsRecovery);

  Future<
    Result<WalletOwnedLightningAddressRegistration, LightningAddressFailure>
  >
  registerWalletOwned({required String nym}) => _registerWalletOwned(nym: nym);

  Future<Result<LightningAddressStatus, LightningAddressFailure>>
  lookupWalletOwnedRegistration() => _lookupRegistration();

  Future<LightningAddressHealOutcome> ensureRegistrationLive({
    DateTime? deadline,
    bool allowReregister = true,
  }) => _ensureRegistrationLive(
    deadline: deadline,
    allowReregister: allowReregister,
  );
}
