import 'dart:typed_data';

import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:bs58check/bs58check.dart' as base58;

bip32.Bip32Keys publicAccountKey(String xpub) {
  final decoded = base58.decode(xpub);
  return bip32.Bip32Keys.fromBase58(
    base58.encode(
      Uint8List.fromList([0x04, 0x88, 0xb2, 0x1e, ...decoded.sublist(4)]),
    ),
  );
}
