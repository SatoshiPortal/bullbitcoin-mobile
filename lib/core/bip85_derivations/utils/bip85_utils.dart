import 'package:bb_mobile/core/bip85_derivations/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/features/bip85_entropy/errors.dart';
import 'package:bip85/bip85.dart' as bip85;

class Bip85Utils {
  static String getDerivedData({
    required Bip85DerivationEntity derivation,
    required String xprvBase58,
  }) {
    switch (derivation.application) {
      case Bip85Application.bip39:
        final path = bip85.MnemonicApplication.parsePath(derivation.path);
        return bip85.Bip85Entropy.deriveMnemonic(
          xprvBase58,
          path.language,
          path.length,
          path.index,
        ).sentence;
      case Bip85Application.hex:
        final path = bip85.HexApplication.parsePath(derivation.path);
        return bip85.Bip85Entropy.deriveHex(
          xprvBase58,
          path.numBytes,
          path.index,
        );
      default:
        throw Bip85EntropyError('Unhandled application');
    }
  }
}
