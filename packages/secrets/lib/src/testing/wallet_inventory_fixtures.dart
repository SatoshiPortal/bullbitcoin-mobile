import 'package:primitives/primitives.dart';

import '../domain/wallet_registration.dart';

WalletRegistration walletRegistrationForTesting({
  required String id,
  required Network network,
  WalletSigner signer = WalletSigner.none,
}) => WalletRegistration(
  id: id,
  network: network,
  scriptType: ScriptType.bip84,
  signer: signer,
  secretFingerprint: null,
  derivationPath: null,
  label: null,
  birthday: null,
  isDefault: false,
);

WalletSelection walletSelectionForTesting(List<WalletRegistration> wallets) =>
    WalletSelection(wallets);
