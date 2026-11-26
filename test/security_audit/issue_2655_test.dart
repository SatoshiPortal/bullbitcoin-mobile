// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2655
// Finding: fetched parent transaction identity is not checked against the requested txid.
// Regression test for the fix.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2655 parent transaction identity', () {
    test('review usecase verifies fetched parent identity', () {
      final source = File(
        'features/send/lib/src/broadcast_signed_tx/application/build_reviewable_transaction_usecase.dart',
      ).readAsStringSync();
      expect(source, contains('_electrum.fetch('));
      expect(source, matches(r'_electrum\.fetch\(\s*input\.previousTxId'));
      expect(source, contains('parentTx.outputs[input.previousVout]'));
      expect(source, contains('parentTx.txid != input.previousTxId'));
    });
  });
}
