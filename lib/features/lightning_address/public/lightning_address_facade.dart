import 'package:bb_mobile/features/lightning_address/domain/lightning_address_registration.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_wallet.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_wallet_registration.dart';

export 'package:bb_mobile/features/lightning_address/domain/lightning_address_error.dart';
export 'package:bb_mobile/features/lightning_address/domain/lightning_address_registration.dart';
export 'package:bb_mobile/features/lightning_address/domain/lightning_address_wallet_registration.dart'
    show WalletOwnedLightningAddressRegistration;
export 'package:bb_mobile/features/lightning_address/domain/lightning_address_wallet.dart'
    show PreparedLightningAddressWallet;

class LightningAddressFacade {
  final Future<PreparedLightningAddressWallet> Function() _prepareWallet;
  final Future<LightningAddressStatus> Function({required String npubHex})
  _lookupRegistration;
  final Future<WalletOwnedLightningAddressRegistration> Function({
    required String nym,
  })
  _registerWalletOwned;
  final Future<LightningAddressStatus> Function()
  _lookupWalletOwnedRegistration;

  const LightningAddressFacade({
    required this._prepareWallet,
    required this._lookupRegistration,
    required this._registerWalletOwned,
    required this._lookupWalletOwnedRegistration,
  });

  Future<PreparedLightningAddressWallet> prepareWallet() {
    return _prepareWallet();
  }

  Future<WalletOwnedLightningAddressRegistration> registerWalletOwned({
    required String nym,
  }) {
    return _registerWalletOwned(nym: nym);
  }

  Future<LightningAddressStatus> lookupWalletOwnedRegistration() {
    return _lookupWalletOwnedRegistration();
  }

  Future<LightningAddressStatus> lookupRegistration({required String npubHex}) {
    return _lookupRegistration(npubHex: npubHex);
  }
}
