import 'package:satoshifier/satoshifier.dart';

/// Enum to represent different extended public key formats
enum XpubType {
  xpub([0x04, 0x88, 0xB2, 0x1E]), // Mainnet Legacy P2PKH
  ypub([0x04, 0x9D, 0x7C, 0xB2]), // Mainnet Nested SegWit (BIP49)
  zpub([0x04, 0xB2, 0x47, 0x46]), // Mainnet Native SegWit (BIP84)
  tpub([0x04, 0x35, 0x87, 0xCF]), // Testnet Legacy P2PKH
  upub([0x04, 0x4A, 0x52, 0x62]), // Testnet Nested SegWit (BIP49)
  vpub([0x04, 0x5F, 0x1C, 0xF6]); // Testnet Native SegWit (BIP84)

  final List<int> version;
  const XpubType(this.version);

  static XpubType fromString(String pubkey) {
    if (pubkey.startsWith('xpub')) return XpubType.xpub;
    if (pubkey.startsWith('ypub')) return XpubType.ypub;
    if (pubkey.startsWith('zpub')) return XpubType.zpub;
    if (pubkey.startsWith('tpub')) return XpubType.tpub;
    if (pubkey.startsWith('upub')) return XpubType.upub;
    if (pubkey.startsWith('vpub')) return XpubType.vpub;

    throw 'Invalid xpub type';
  }

  static XpubType fromDerivation(Derivation derivation, Network network) {
    if (network == Network.bitcoinMainnet) {
      if (derivation == Derivation.bip44) return XpubType.xpub;
      if (derivation == Derivation.bip49) return XpubType.ypub;
      if (derivation == Derivation.bip84) return XpubType.zpub;
    }

    if (network == Network.bitcoinTestnet) {
      if (derivation == Derivation.bip44) return XpubType.tpub;
      if (derivation == Derivation.bip49) return XpubType.upub;
      if (derivation == Derivation.bip84) return XpubType.vpub;
    }

    throw 'Invalid derivation: $derivation for network: $network';
  }
}
