import 'package:bb_mobile/core/utils/bip48_derivation.dart';

final class Bip48AccountUsage {
  final String seedFingerprint;

  /// The local seed cryptographically matched before this signer was marked
  /// local. It differs from [seedFingerprint] for passphrase accounts.
  final String? localSeedFingerprint;
  final int coinType;
  final int account;
  final String derivationPath;
  final String xpub;

  Bip48AccountUsage({
    required this.seedFingerprint,
    this.localSeedFingerprint,
    required this.coinType,
    required this.account,
    required this.derivationPath,
    required this.xpub,
  }) {
    if (!RegExp(r'^[0-9a-fA-F]{8}$').hasMatch(seedFingerprint) ||
        (localSeedFingerprint != null &&
            !RegExp(r'^[0-9a-fA-F]{8}$').hasMatch(localSeedFingerprint!)) ||
        (coinType != 0 && coinType != 1) ||
        account < 0 ||
        account > Bip48Derivation.maxAccount ||
        Bip48Derivation.account(derivationPath, coinType: coinType) !=
            account ||
        xpub.isEmpty) {
      throw ArgumentError('Invalid BIP48 account usage');
    }
  }
}
