import 'dart:typed_data';

import 'package:bb_mobile/core_deprecated/utils/uint_8_list_x.dart';
import 'package:bb_mobile/core_deprecated/wallet/domain/entities/wallet.dart';
import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:bs58check/bs58check.dart' as base58;

class Bip32Derivation {
  static Future<bip32.Bip32Keys> getAccountXpub({
    required Uint8List seedBytes,
    required ScriptType scriptType,
    required Network network,
    int accountIndex = 0,
  }) async {
    final root = bip32.Bip32Keys.fromSeed(seedBytes);
    final derivationPath =
        "m/${scriptType.purpose}'/${network.coinType}'/$accountIndex'";
    final derivedAccountKey = root.derivePath(derivationPath);
    return derivedAccountKey.neutered;
  }

  static String getXprvFromSeed(Uint8List seedBytes, Network network) {
    final nw =
        network == Network.bitcoinTestnet
            ? bip32.NetworkType(
              wif: 0x80,
              bip32: bip32.Bip32Type(public: 0x043587CF, private: 0x04358394),
            )
            : null;
    final root = bip32.Bip32Keys.fromSeed(seedBytes, network: nw);
    return root.toBase58();
  }

  static bip32.Bip32Keys getBip32Xpub(String xpub) {
    final decoded = base58.decode(xpub);
    final keyBytes = decoded.sublist(4); // Remove xpub version bytes
    // Add xpub version bytes, since the bip32 library expects them like that
    final xpubBytes = Uint8List.fromList([
      ...XpubType.xpub.versionBytes,
      ...keyBytes,
    ]);
    return bip32.Bip32Keys.fromBase58(base58.encode(xpubBytes));
  }
}

/// Enum to represent different extended public key formats
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

extension Bip32X on bip32.Bip32Keys {
  /// Get the fingerprint of the BIP32 key as a hex string
  String get fingerprintHex => fingerprint.toHexString();

  /// Converts an xpub to different extended public key formats
  String convert(XpubType targetType) {
    final xpub = toBase58();
    final decoded = base58.decode(xpub);
    final versionBytes = Uint8List.fromList(targetType.versionBytes);
    final keyBytes = decoded.sublist(4); // Remove existing xpub version bytes
    final newBytes = Uint8List.fromList([
      ...versionBytes,
      ...keyBytes,
    ]); // Apply new prefix
    return base58.encode(newBytes);
  }
}
