import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2593
// Finding: editing the payment after hardware signing leaves the old signed transaction usable.
// Regression test for the fix.
void main() {
  group('Security audit #2593 post-sign edits', () {
    test('back navigation invalidates signedBitcoinTx', () {
      final source = File(
        'lib/features/send/presentation/bloc/send_cubit.dart',
      ).readAsStringSync();
      final back = source.substring(
        source.indexOf('void backClicked()'),
        source.indexOf('Future<void> loadWalletWithRatesAndFees()'),
      );
      expect(back, contains('step: SendStep.amount'));
      expect(back, contains('_invalidateSignedTransaction();'));
      expect(source, contains('signedBitcoinTx: null'));
    });
  });
}
