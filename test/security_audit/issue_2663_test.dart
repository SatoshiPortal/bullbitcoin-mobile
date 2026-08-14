// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2663
// Finding: exchange orders bind to wallet transactions using only server txid.
// Regression test for the fix.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('source validates order binding beyond the server transaction ID', () {
    final source = File(
      'lib/features/transactions/application/usecases/get_transactions_usecase.dart',
    ).readAsStringSync();
    expect(source, contains('o.toAddress != wt.toAddress'));
    expect(source, contains('expectedDirection'));
  });
}
