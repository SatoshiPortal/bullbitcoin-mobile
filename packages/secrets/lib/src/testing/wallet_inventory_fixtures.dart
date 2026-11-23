import 'package:primitives/primitives.dart';

import '../domain/wallet_registration.dart';

WalletRegistration walletRegistrationForTesting({
  required String id,
  required Network network,
  bool isDefault = false,
  WalletSigner signer = WalletSigner.none,
  Fingerprint? fingerprint,
}) => WalletRegistration(
  id: id,
  network: network,
  scriptType: ScriptType.bip84,
  signer: signer,
  secretFingerprint: signer == WalletSigner.local ? fingerprint : null,
  masterFingerprint: fingerprint,
  derivationPath: null,
  label: null,
  birthday: null,
  isDefault: isDefault,
);

WalletSelection walletSelectionForTesting(
  List<WalletRegistration> wallets, {
  bool isComplete = true,
}) => WalletSelection(wallets, isComplete: isComplete);
