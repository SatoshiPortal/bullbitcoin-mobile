import 'package:bip32_keys/bip32_keys.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:satoshifier/_test_value.dart';

void main() {
  // A fixture can carry a valid base58check trailer and still not be a key:
  // testnetTpub decoded cleanly while its 33-byte key field began with 0x00,
  // and a compressed public key must begin with 0x02 or 0x03. Nothing ever
  // decoded it, so the descriptor tests worked around it by pairing a mainnet
  // xpub with testnet paths — exactly the mismatch the network cross-check now
  // rejects.
  final extendedKeys = <String, String>{
    'xpub': TestValue.xpub,
    'xpubBip49': TestValue.xpubBip49,
    'xpubBip49ToYpub': TestValue.xpubBip49ToYpub,
    'xpubBip84': TestValue.xpubBip84,
    'xpubBip84ToZpub': TestValue.xpubBip84ToZpub,
    'xpubToTpub': TestValue.xpubToTpub,
    'xpubToUpub': TestValue.xpubToUpub,
    'xpubToVpub': TestValue.xpubToVpub,
    'ypub': TestValue.ypub,
    'ypubToXpub': TestValue.ypubToXpub,
    'zpub': TestValue.zpub,
    'zpubToXpub': TestValue.zpubToXpub,
    'testnetTpub': TestValue.testnetTpub,
  };

  test('every extended public key fixture is a decodable key', () {
    for (final entry in extendedKeys.entries) {
      expect(
        () => Bip32Keys.fromBase58(entry.value, bypassVersion: true),
        returnsNormally,
        reason: entry.key,
      );
    }
  });
}
