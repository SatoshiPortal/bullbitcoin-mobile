import 'package:primitives/primitives.dart';

import '../domain/wallet_registration.dart';

WalletRegistration walletRegistrationForTesting({
  required String id,
  required Network network,
  bool isDefault = false,
  WalletSigner signer = WalletSigner.none,
  Fingerprint? masterFingerprint,
  Fingerprint? secretFingerprint,
