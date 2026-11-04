import 'dart:convert';
import 'dart:typed_data';

import 'package:wallet/wallet.dart';
import 'package:flutter_test/flutter_test.dart';

// Public BIP173 witness-program vector and synthetic outpoint, no wallet keys.
const _testnetAddress = 'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx';
const _mainnetAddress = 'bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4';
final _script = [
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
];

List<int> _amount(int sats) =>
    (ByteData(8)..setUint64(0, sats, Endian.little)).buffer.asUint8List();

String _fixture() {
  final transaction = [
    2, 0, 0, 0, // version
    1, // one synthetic input
    ...List.filled(32, 0), 0, 0, 0, 0, 0, 255, 255, 255, 255,
    2, // two payments to the same address
    ..._amount(10000), _script.length, ..._script,
    ..._amount(15000), _script.length, ..._script,
    0, 0, 0, 0, // locktime
  ];
  final witnessUtxo = [..._amount(30000), _script.length, ..._script];
  return base64Encode([
    0x70, 0x73, 0x62, 0x74, 0xff, // PSBT magic
    1, 0, transaction.length, ...transaction, 0, // global unsigned tx
    1, 1, witnessUtxo.length, ...witnessUtxo, 0, // input witness UTXO
    0, 0, // empty output maps
  ]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const inspection = WalletPsbtInspection();

  test('reads the unsigned transaction size and exact fee offline', () async {
    expect(await inspection.decodeTxSize(_fixture()), 113);
    expect(await inspection.getFeeAmount(_fixture()), 5000);
  });

  for (final isTestnet in [false, true]) {
    test('sums repeated destination outputs (testnet: $isTestnet)', () async {
      expect(
        await inspection.getAmountSentToAddress(
          _fixture(),
          isTestnet ? _testnetAddress : _mainnetAddress,
          isTestnet: isTestnet,
        ),
        25000,
      );
      expect(
        await inspection.getAmountSentToAddress(
          _fixture(),
          isTestnet ? _mainnetAddress : _testnetAddress,
          isTestnet: isTestnet,
        ),
        0,
      );
    });
  }

  test('preserves native parse failures for invalid PSBTs', () async {
    await expectLater(
      inspection.decodeTxSize('invalid'),
      throwsA(isA<Exception>()),
    );
    await expectLater(
      inspection.getFeeAmount('invalid'),
      throwsA(isA<Exception>()),
    );
    await expectLater(
      inspection.getAmountSentToAddress(
        'invalid',
        _testnetAddress,
        isTestnet: true,
      ),
      throwsA(isA<Exception>()),
    );
  });
}
