import 'package:primitives/primitives.dart' show Fingerprint;

import 'wallet.dart';

/// Public account material derived from a stored secret: no seed, no words,
/// no private key.
final class WalletAccountKeys {
  final String xpub;
  final String xpubFingerprint;
  final String externalDescriptor;
  final String internalDescriptor;

  const WalletAccountKeys({
    required this.xpub,
    required this.xpubFingerprint,
    required this.externalDescriptor,
    required this.internalDescriptor,
  });
}

/// Derives a seed-derived wallet's public account from the host's secret
/// store, so this package never handles key material.
abstract interface class WalletAccountDerivationPort {
  Future<WalletAccountKeys> deriveAccount({
    required Fingerprint secretId,
    required Network network,
    required ScriptType scriptType,
  });
}
