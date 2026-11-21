import 'dart:typed_data';

import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:bs58check/bs58check.dart' as base58;
import 'package:primitives/primitives.dart' show XpubType;

class Bip32Derivation {
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

extension Uint8ListX on Uint8List {
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
