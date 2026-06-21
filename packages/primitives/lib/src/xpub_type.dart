import 'package:primitives/src/network.dart';
import 'package:primitives/src/script_type.dart';

/// Extended-public-key formats and their version bytes. Ported verbatim from
/// the app's `lib/core/utils/bip32_derivation.dart`.
enum XpubType {
  xpub([0x04, 0x88, 0xB2, 0x1E]), // Mainnet Legacy P2PKH
  ypub([0x04, 0x9D, 0x7C, 0xB2]), // Mainnet Nested SegWit (BIP49)
  zpub([0x04, 0xB2, 0x47, 0x46]), // Mainnet Native SegWit (BIP84)
  tpub([0x04, 0x35, 0x87, 0xCF]), // Testnet Legacy P2PKH
  upub([0x04, 0x4A, 0x52, 0x62]), // Testnet Nested SegWit (BIP49)
  vpub([0x04, 0x5F, 0x1C, 0xF6]); // Testnet Native SegWit (BIP84)

  final List<int> versionBytes;
  const XpubType(this.versionBytes);
}

extension ScriptTypeX on ScriptType {
  XpubType getXpubType(Network network) {
    if (network.isMainnet) {
      switch (this) {
        case ScriptType.bip44:
          return XpubType.xpub;
        case ScriptType.bip49:
          return XpubType.ypub;
        case ScriptType.bip84:
          return XpubType.zpub;
      }
    } else {
      switch (this) {
        case ScriptType.bip44:
          return XpubType.tpub;
        case ScriptType.bip49:
          return XpubType.upub;
        case ScriptType.bip84:
          return XpubType.vpub;
      }
    }
  }
}
