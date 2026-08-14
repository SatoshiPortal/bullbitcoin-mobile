import 'package:primitives/src/network.dart';
import 'package:primitives/src/script_type.dart';

/// Extended-public-key formats and their version bytes.
enum XpubType {
  xpub([0x04, 0x88, 0xB2, 0x1E]),
  ypub([0x04, 0x9D, 0x7C, 0xB2]),
  zpub([0x04, 0xB2, 0x47, 0x46]),
  tpub([0x04, 0x35, 0x87, 0xCF]),
  upub([0x04, 0x4A, 0x52, 0x62]),
  vpub([0x04, 0x5F, 0x1C, 0xF6]);

  final List<int> versionBytes;

  const XpubType(this.versionBytes);
}

extension ScriptTypeX on ScriptType {
  XpubType getXpubType(BitcoinNetwork network) {
    if (network.isMainnet) {
      return switch (this) {
        ScriptType.bip44 => XpubType.xpub,
        ScriptType.bip49 => XpubType.ypub,
        ScriptType.bip84 => XpubType.zpub,
      };
    }
    return switch (this) {
      ScriptType.bip44 => XpubType.tpub,
      ScriptType.bip49 => XpubType.upub,
      ScriptType.bip84 => XpubType.vpub,
    };
  }
}
