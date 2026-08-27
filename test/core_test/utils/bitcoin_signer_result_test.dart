import 'dart:convert';

import 'package:bb_mobile/core/utils/bitcoin_signer_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PSBT resource boundaries', () {
    test('accepts exactly the decoded size cap', () {
      final bytes = <int>[0x70, 0x73, 0x62, 0x74, 0xff];
      bytes.addAll(
        List<int>.filled(maxBitcoinPsbtDecodedBytes - bytes.length, 0),
      );

      expect(base64.decode(normalizeBitcoinPsbt(base64.encode(bytes))), bytes);
    });

    test('rejects one byte over the decoded size cap', () {
      final bytes = <int>[0x70, 0x73, 0x62, 0x74, 0xff];
      bytes.addAll(
        List<int>.filled(maxBitcoinPsbtDecodedBytes + 1 - bytes.length, 0),
      );

      expect(
        () => normalizeBitcoinPsbt(base64.encode(bytes)),
        throwsFormatException,
      );
    });

    test('rejects input over the transport cap before decoding', () {
      expect(
        () => normalizeBitcoinPsbt(
          'A'.padRight(maxBitcoinPsbtTransportBytes + 1, 'A'),
        ),
        throwsFormatException,
      );
    });
  });
}
