import 'package:bull_exchange/src/limit_orders/domain/usecases/get_active_limit_orders_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../limit_order_fixtures.dart';
import '../../limit_test_orders.dart';

void main() {
  test('reads the active orders', () async {
    final orders = LimitTestOrders()..active = Ok([limitOrder()]);
    final read = await GetActiveLimitOrdersUsecase(
      exchangeForTesting(limitOrders: orders),
    ).execute();
    expect((read as ReadGot<List<LimitOrder>>).value.single.id, 'lo-1');
    expect(orders.log, ['active']);
  });

  test('a failed read is never a list', () async {
    final read = await GetActiveLimitOrdersUsecase(
      exchangeForTesting(
        limitOrders: LimitTestOrders()
          ..active = const Err(ExchangeNetworkFailure()),
      ),
    ).execute();
    expect(read, isA<ReadUnreachable<List<LimitOrder>>>());
  });
}
