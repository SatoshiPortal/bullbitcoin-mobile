import 'dart:typed_data';

import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/new/entities/new_wallet_metadata_entity.dart';
import 'package:bip32/bip32.dart' as bip32;
import 'package:bs58check/bs58check.dart' as base58;

class NewBip32Derivation {
  static Future<bip32.BIP32> getAccountXpub({
    required Uint8List seedBytes,
    required NewScriptType scriptType,
    required NewNetwork network,
    int accountIndex = 0,
  }) async {
    final root = bip32.BIP32.fromSeed(seedBytes);
    final derivationPath =
        "m/${scriptType.purpose}'/${network.coinType}'/$accountIndex'";
    final derivedAccountKey = root.derivePath(derivationPath);
    return derivedAccountKey.neutered();
  }

  static String getXprvFromSeed(Uint8List seedBytes, NewNetwork network) {
    final nw =
        network == NewNetwork.bitcoinTestnet
            ? bip32.NetworkType(
              wif: 0x80,
              bip32: bip32.Bip32Type(public: 0x043587CF, private: 0x04358394),
            )
            : null;
    final root = bip32.BIP32.fromSeed(seedBytes, nw);
    return root.toBase58();
  }

  static bip32.BIP32 getBip32Xpub(String xpub) {
    final decoded = base58.decode(xpub);
    final keyBytes = decoded.sublist(4); // Remove xpub version bytes
    // Add xpub version bytes, since the bip32 library expects them like that
    final xpubBytes = Uint8List.fromList([
      ...NewXpubType.xpub.versionBytes,
      ...keyBytes,
    ]);
    return bip32.BIP32.fromBase58(base58.encode(xpubBytes));
  }
}

/// Enum to represent different extended public key formats
enum NewXpubType {
  xpub([0x04, 0x88, 0xB2, 0x1E]), // Mainnet Legacy P2PKH
  ypub([0x04, 0x9D, 0x7C, 0xB2]), // Mainnet Nested SegWit (BIP49)
  zpub([0x04, 0xB2, 0x47, 0x46]), // Mainnet Native SegWit (BIP84)
  tpub([0x04, 0x35, 0x87, 0xCF]), // Testnet Legacy P2PKH
  upub([0x04, 0x4A, 0x52, 0x62]), // Testnet Nested SegWit (BIP49)
  vpub([0x04, 0x5F, 0x1C, 0xF6]); // Testnet Native SegWit (BIP84)

  final List<int> versionBytes;
  const NewXpubType(this.versionBytes);
}

extension NewScriptTypeX on NewScriptType {
  NewXpubType getXpubType(NewNetwork network) {
    if (network.isMainnet) {
      switch (this) {
        case NewScriptType.bip44:
          return NewXpubType.xpub;
        case NewScriptType.bip49:
          return NewXpubType.ypub;
        case NewScriptType.bip84:
          return NewXpubType.zpub;
      }
    } else {
      switch (this) {
        case NewScriptType.bip44:
          return NewXpubType.tpub;
        case NewScriptType.bip49:
          return NewXpubType.upub;
        case NewScriptType.bip84:
          return NewXpubType.vpub;
      }
    }
  }
}

extension NewBip32X on bip32.BIP32 {
  /// Get the fingerprint of the BIP32 key as a hex string
  String get fingerprintHex {
    final fingerprintBytes = fingerprint;
    return fingerprintBytes.toHexString();
  }

  /// Converts an xpub to different extended public key formats
  String convert(NewXpubType targetType) {
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

extension NewUint8ListX on Uint8List {
  String toHexString() {
    return map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static Uint8List fromHexString(String hex) {
    final length = hex.length;
    final bytes = Uint8List(length ~/ 2);
    for (var i = 0; i < length; i += 2) {
      bytes[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return bytes;
  }
}
