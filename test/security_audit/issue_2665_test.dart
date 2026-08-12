// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2665
// Finding: transaction aggregation exposes raw exception text in its thrown failure.
// Regression test for the fix.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('source maps aggregation failures without exposing raw details', () {
    final source = File(
      'lib/features/transactions/application/usecases/get_transactions_usecase.dart',
    ).readAsStringSync();
    expect(source, contains('TransactionAggregationFailure'));
    expect(source, isNot(contains("Failed to fetch transactions: \$e")));
  });
}
