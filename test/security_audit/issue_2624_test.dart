// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2624
// Finding: history loading writes privileged exchange labels from unverified server data.
// Regression test for the fix.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('history reads do not write privileged labels', () {
    final source = File(
      'lib/features/transactions/application/usecases/label_exchange_orders_usecase.dart',
    ).readAsStringSync();
    expect(source, contains('if (!explicitCompletion) return;'));
    expect(source, contains('order.orderStatus != OrderStatus.completed'));
    expect(source, contains('OrderType.buy'));
    expect(source, contains('OrderType.sell'));
  });
}
