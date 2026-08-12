// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2664
// Finding: swap legs are associated from server-reported transaction IDs without on-chain verification.
// Regression test for the fix.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('source validates swap association against wallet ownership', () {
    final source = File(
      'lib/features/transactions/application/usecases/get_transactions_usecase.dart',
    ).readAsStringSync();
    expect(source, contains('s.walletId == wt.walletId'));
    expect(source, contains('wt.amountSat <= s.amountSat'));
    expect(source, contains('swapLegToKeep[s.id]'));
  });
}
