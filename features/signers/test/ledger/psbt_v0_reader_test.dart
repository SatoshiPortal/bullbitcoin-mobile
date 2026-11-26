import 'dart:convert';
import 'dart:typed_data';

import 'package:signers/src/ledger/data/datasources/ledger_device_datasource.dart';
import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_bitcoin/ledger_bitcoin.dart';

// Version 2, one input (txid 0x01..0x20 reversed, vout 0, sequence
// 0xfffffffd) carrying a 100200 sat witness UTXO, one 100000 sat P2WPKH
// output.
const _psbt =
    'cHNidP8BAFICAAAAAQECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gAAAAAAD9////'
    'AaCGAQAAAAAAFgAUIiIiIiIiIiIiIiIiIiIiIiIiIiIAAAAAAAEBH2iHAQAAAAAAFgAUMzMz'
    'MzMzMzMzMzMzMzMzMzMzMzMAAA==';

void main() {
  test('a v0 PSBT fills the v2 globals, inputs and outputs', () async {
    final psbt = PsbtV2();
    await psbt.deserializeV0(base64.decode(_psbt));

    expect(psbt.getGlobalTxVersion(), 2);
    expect(psbt.getGlobalInputCount(), 1);
    expect(psbt.getGlobalOutputCount(), 1);
    // PSBT v2 stores the previous txid in internal byte order.
    expect(
      hex.encode(psbt.getInputPreviousTxid(0)),
      hex.encode(List.generate(32, (i) => i + 1)),
    );
    expect(psbt.getInputOutputIndex(0), 0);
    expect(psbt.getInputSequence(0), 0xfffffffd);
    expect(psbt.getOutputAmount(0), 100000);
    expect(hex.encode(psbt.getOutputScript(0)), '0014${'22' * 20}');
  });

  test('a PSBT the decoder refuses is not read', () {
    // The magic is right, the content is not.
    final bytes = [...utf8.encode('psbt'), 0xff, 0x00];
    expect(
      PsbtV2().deserializeV0(Uint8List.fromList(bytes)),
      throwsA(isA<FormatException>()),
    );
  });
}
