// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2655
// Finding: fetched parent transaction identity is not checked against the requested txid.
// Regression test for the fix.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2655 parent transaction identity', () {
    test('review usecase verifies fetched parent identity', () {
      final source = File(
        'lib/features/broadcast_signed_tx/application/build_reviewable_transaction_usecase.dart',
      ).readAsStringSync();
      expect(
        source,
        matches(
          RegExp(
            r'final parentTx = await _transactionPort.fetch\(\s*'
            r'txid: input.previousTxId,\s*walletId: walletId,\s*\);',
          ),
        ),
      );
      expect(
        source,
        contains('final parentOutput = parentTx.outputs[input.previousVout];'),
      );
      final fetch = source.indexOf('final parentTx = await');
      final identity = source.indexOf('parentTx.txid != input.previousTxId');
      final output = source.indexOf('final parentOutput = parentTx.outputs');
      expect(identity, greaterThan(fetch));
      expect(output, greaterThan(identity));
      expect(
        source.substring(identity, output),
        contains('TransactionReviewInputResolutionFailure('),
      );
    });
  });
}
