import 'package:primitives/primitives.dart';

import '../domain/wallet_registration.dart';

WalletRegistration walletRegistrationForTesting({
  required String id,
  required Network network,
  bool isDefault = false,
  ScriptType scriptType = ScriptType.bip84,
  String? derivationPath,
  String? label,
  WalletSigner signer = WalletSigner.none,
  Fingerprint? masterFingerprint,
  Fingerprint? secretFingerprint,
}) => WalletRegistration(
  id: id,
  network: network,
  scriptType: scriptType,
  signer: signer,
  masterFingerprint: masterFingerprint,
  secretFingerprint: secretFingerprint,
  derivationPath: derivationPath,
  label: label,
  birthday: null,
  isDefault: isDefault,
);

WalletSelection walletSelectionForTesting(
  List<WalletRegistration> wallets, {
  bool isComplete = true,
}) => WalletSelection(wallets, isComplete: isComplete);
