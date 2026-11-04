import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wallet/wallet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Public BIP173 witness-program vector; no wallet or secret is required.
  final witnessProgram = Uint8List.fromList([
    0x00,
    0x14,
    0x75,
    0x1e,
    0x76,
    0xe8,
    0x19,
    0x91,
    0x96,
    0xd4,
    0x54,
    0x94,
    0x1c,
    0x45,
    0xd1,
    0xb3,
    0xa3,
    0x23,
    0xf1,
    0x43,
    0x3b,
    0xd6,
  ]);

  test('converts the same witness program on both Bitcoin networks', () async {
    expect(
      await AddressScriptConversions.bitcoinAddressFromScriptPubkey(
        witnessProgram,
        isTestnet: false,
      ),
      'bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4',
    );
    expect(
      await AddressScriptConversions.bitcoinAddressFromScriptPubkey(
        witnessProgram,
        isTestnet: true,
      ),
      'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx',
    );
  });

  test('non-address outputs retain the nullable conversion contract', () async {
    expect(
      await AddressScriptConversions.bitcoinAddressFromScriptPubkey(
        Uint8List.fromList([0x6a, 0x01, 0x00]),
        isTestnet: false,
      ),
      isNull,
    );
  });
}
