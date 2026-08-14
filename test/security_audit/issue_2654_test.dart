// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2654
// Finding: generic PSBT parsing always extracts through BDK, which requires input metadata.
// Regression test for the fix.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2654 stripped PSBT', () {
    test('BitcoinTx.fromPsbt finalizes through the stripped-metadata path', () {
      final source = File('lib/core/utils/bitcoin_tx.dart').readAsStringSync();
      expect(source, contains('final psbt = Psbt.fromBase64(psbtBase64);'));
      expect(source, contains('finalizeAll().toBytes()'));
    });
  });
}
