import 'dart:typed_data';

import 'package:bip32_keys/bip32_keys.dart';
import 'package:bs58/bs58.dart';
import 'package:satoshifier/enums/xpub_type.dart';

class Bip32Utils {
  static Uint8List fingerprint(List<int> pubkey, XpubType type) {
    final keyWithoutVersion = pubkey.sublist(4);
    final key = Uint8List.fromList([...type.version, ...keyWithoutVersion]);
    final bip32Key = Bip32Keys.fromBase58(
      base58.encode(key),
      bypassVersion: (type == XpubType.xpub) ? false : true,
    );
    return bip32Key.fingerprint;
  }

  static String convertToXpub(List<int> pubkey) {
    final pubkeyB58 = base58.encode(Uint8List.fromList(pubkey));
    final format = Slip132Format.parse(pubkeyB58);
    final bip32Key = Bip32Keys.fromBase58(pubkeyB58, network: format.network);
    return bip32Key.toSlip132(Slip132Format.xpub);
  }

  static String convertToYpub(List<int> pubkey) {
    final pubkeyB58 = base58.encode(Uint8List.fromList(pubkey));
    final format = Slip132Format.parse(pubkeyB58);
    final bip32Key = Bip32Keys.fromBase58(pubkeyB58, network: format.network);
    return bip32Key.toSlip132(Slip132Format.ypub);
  }

  static String convertToZpub(List<int> pubkey) {
    final pubkeyB58 = base58.encode(Uint8List.fromList(pubkey));
    final format = Slip132Format.parse(pubkeyB58);
    final bip32Key = Bip32Keys.fromBase58(pubkeyB58, network: format.network);
    return bip32Key.toSlip132(Slip132Format.zpub);
  }
}
