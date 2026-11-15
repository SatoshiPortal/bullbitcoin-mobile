import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sync/sync.dart';

// One input spending 1111…11:0 and one 100000 sat P2WPKH output to 2222…22.
const _psbt =
    'cHNidP8BAFICAAAAARERERERERERERERERERERERERERERERERERERERERERAAAAAAD9////'
    'AaCGAQAAAAAAFgAUIiIiIiIiIiIiIiIiIiIiIiIiIiIAAAAAAAEBH2iHAQAAAAAAFgAUMzMz'
    'MzMzMzMzMzMzMzMzMzMzMzMAAA==';

final _script = Uint8List.fromList([0, 20, ...List.filled(20, 0x22)]);

/// The PSBT's unsigned transaction, serialized on its own.
Uint8List _rawTransaction() =>
    Uint8List.sublistView(base64.decode(_psbt), 8, 8 + 0x52);

void main() {
  test('a PSBT decodes to its id, spent outpoints and outputs', () {
    final decoded = decodeBitcoinPsbt(_psbt);

    expect(decoded.txid, bitcoinPsbtTransactionId(_psbt));
    expect(decoded.inputs, [(txId: '11' * 32, vout: 0)]);
    expect(decoded.outputs, hasLength(1));
    expect(decoded.outputs.single.valueSat, 100000);
    expect(decoded.outputs.single.scriptPubkey, _script);
  });

  test('a raw transaction decodes like the PSBT that carries it', () {
    final bytes = _rawTransaction();
    final decoded = decodeBitcoinTransaction(bytes);

    expect(decoded.txid, bitcoinRawTransactionId(bytes));
    expect(decoded.txid, decodeBitcoinPsbt(_psbt).txid);
    expect(decoded.inputs, [(txId: '11' * 32, vout: 0)]);
    expect(decoded.outputs.single.valueSat, 100000);
    expect(decoded.outputs.single.scriptPubkey, _script);
  });

  test('undecodable input is a format error, never a native exception', () {
    expect(() => decodeBitcoinPsbt('cHNidP8='), throwsFormatException);
    expect(() => decodeBitcoinPsbt('not base64'), throwsFormatException);
    expect(
      () => decodeBitcoinTransaction(Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
  });
}
