import 'package:bull_payjoin/setup.dart';

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart'
    show bitcoinAddressScript, bitcoinPsbtTransactionId;

// One input spending 1111…11:0 and one 100000 sat P2WPKH output to 2222…22.
const _psbt =
    'cHNidP8BAFICAAAAARERERERERERERERERERERERERERERERERERERERERERAAAAAAD9////'
    'AaCGAQAAAAAAFgAUIiIiIiIiIiIiIiIiIiIiIiIiIiIAAAAAAAEBH2iHAQAAAAAAFgAUMzMz'
    'MzMzMzMzMzMzMzMzMzMzMzMAAA==';

const _mainnetAddress = 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq';

void main() {
  const codec = AppPayjoinCodecAdapter();

  test('a PSBT reaches Payjoin as its id, outpoints and outputs', () {
    final transaction = codec.decodePsbt(_psbt);

    expect(transaction.txid, bitcoinPsbtTransactionId(_psbt));
    expect(transaction.inputs, [(txId: '11' * 32, vout: 0)]);
    expect(transaction.outputs.single.value, Sats.fromInt(100000));
    expect(
      transaction.outputs.single.scriptPubkey,
      Uint8List.fromList([0, 20, ...List.filled(20, 0x22)]),
    );
  });

  test('undecodable data stays a format error', () {
    expect(() => codec.decodePsbt('cHNidP8='), throwsFormatException);
    expect(
      () => codec.decodeTransaction(Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
  });

  test('an address decodes only on its own network', () {
    final script = codec.addressScript(_mainnetAddress, BitcoinNetwork.mainnet);
    expect(script, switch (bitcoinAddressScript(
      _mainnetAddress,
      BitcoinNetwork.mainnet,
    )) {
      Ok(:final value) => value,
      Err() => fail('the fixture address must decode'),
    });
    expect(
      codec.addressScript(_mainnetAddress, BitcoinNetwork.testnet),
      isNull,
    );
    expect(
      codec.addressScript('not an address', BitcoinNetwork.mainnet),
      isNull,
    );
  });
}
