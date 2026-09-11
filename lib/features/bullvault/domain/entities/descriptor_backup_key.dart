import 'dart:typed_data';

import 'package:bip32_keys/bip32_keys.dart';
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:bs58check/bs58check.dart' as base58;
import 'package:convert/convert.dart';

/// The exact public account key, independent of display prefix and origin.
final class DescriptorBackupKey {
  final String xpub;
  final bool isTestnet;
  final Uint8List canonicalBytes;

  DescriptorBackupKey._(this.xpub, this.isTestnet, Uint8List bytes)
    : canonicalBytes = bytes.asUnmodifiableView();

  factory DescriptorBackupKey.parse(String value) {
    if (value.length > 120) throw const FormatException('Invalid account key');
    final Uint8List bytes;
    try {
      bytes = base58.decode(value);
    } on ArgumentError {
      // bs58check reports malformed user input/checksums as ArgumentError.
      throw const FormatException('Invalid account key encoding');
    }
    if (bytes.length != 78) throw const FormatException('Invalid account key');
    final version = ByteData.sublistView(bytes).getUint32(0);
    const main = {0x0488b21e, 0x049d7cb2, 0x04b24746, 0x0295b43f, 0x02aa7ed3};
    const test = {0x043587cf, 0x044a5262, 0x045f1cf6, 0x024289ef, 0x02575483};
    if (!main.contains(version) && !test.contains(version)) {
      throw const FormatException('A public account key is required');
    }
    if (bytes[45] != 2 && bytes[45] != 3) {
      throw const FormatException('A public account key is required');
    }
    if (bytes[4] == 0 && bytes.sublist(5, 13).any((b) => b != 0)) {
      throw const FormatException('Invalid root ancestry');
    }
    ECPublic.fromHex(hex.encode(bytes.sublist(45)));
    final normalized = Uint8List.fromList(bytes);
    ByteData.sublistView(normalized).setUint32(0, 0x0488b21e);
    // Validates the point and the BIP32 serialization, including root ancestry.
    final key = Bip32Keys.fromBase58(base58.encode(normalized));
    if (!key.isNeutered) throw const FormatException('Private key forbidden');
    final isTestnet = test.contains(version);
    ByteData.sublistView(
      normalized,
    ).setUint32(0, isTestnet ? 0x043587cf : 0x0488b21e);
    return DescriptorBackupKey._(
      base58.encode(normalized),
      isTestnet,
      Uint8List.fromList([
        isTestnet ? 1 : 0,
        ...bytes.sublist(45),
        ...bytes.sublist(13, 45),
      ]),
    );
  }

  Uint8List get xOnly => Uint8List.sublistView(canonicalBytes, 2, 34);

  bool sameAccount(DescriptorBackupKey other) {
    if (canonicalBytes.length != other.canonicalBytes.length) return false;
    for (var i = 0; i < canonicalBytes.length; i++) {
      if (canonicalBytes[i] != other.canonicalBytes[i]) return false;
    }
    return true;
  }

  @override
  String toString() => 'DescriptorBackupKey(redacted)';
}
