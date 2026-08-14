// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2600
// Finding: the SeedSigner fallback passes raw transaction bytes to a PSBT parser.
// Regression test for the fix.

import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

void main() {
  group('Security audit #2600 SeedSigner fallback', () {
    test('SeedSigner fallback finalizes the combined PSBT before extraction', () {
      // version 1, zero inputs, zero outputs, locktime 0: raw tx, not PSBT.
      final rawTransaction = <int>[1, 0, 0, 0, 0, 0, 0, 0, 0, 0];

      expect(() => Psbt.deserialize(rawTransaction), throwsA(anything));
      final source = File(
        'lib/features/broadcast_signed_tx/presentation/broadcast_signed_tx_cubit.dart',
      ).readAsStringSync();
      expect(source, contains('tx.finalize();'));
      expect(source, contains('tx.extractTx().serialize()'));
      expect(
        source,
        isNot(contains('Psbt.deserialize(tx.extractTx().serialize())')),
      );
    });
  });
}
