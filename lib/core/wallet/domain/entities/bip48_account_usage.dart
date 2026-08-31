import 'package:bb_mobile/core/utils/bip48_derivation.dart';

final class Bip48AccountUsage {
  final String seedFingerprint;
  final int coinType;
  final int account;
  final String derivationPath;
  final String xpub;

  Bip48AccountUsage({
    required this.seedFingerprint,
    required this.coinType,
    required this.account,
    required this.derivationPath,
    required this.xpub,
  }) {
    if (!RegExp(r'^[0-9a-fA-F]{8}$').hasMatch(seedFingerprint) ||
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
