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
    ).execute(limitSession);
    expect(
      (read as Ok<List<LimitOrder>, ExchangeReadFailure>).value.single.id,
      'lo-1',
    );
    expect(orders.log, ['active']);
    expect(orders.sessions, [limitSession]);
  });

  test('without a session the answer is the signed-out one', () async {
    final orders = LimitTestOrders();
    final read = await GetActiveLimitOrdersUsecase(
      exchangeForTesting(limitOrders: orders),
    ).execute(null);
    expect(
      read,
      isA<Err<List<LimitOrder>, ExchangeReadFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<ExchangeSessionRejectedFailure>(),
      ),
    );
    expect(orders.log, isEmpty);
  });

  test('a failed read is never a list', () async {
    final read = await GetActiveLimitOrdersUsecase(
      exchangeForTesting(
        limitOrders: LimitTestOrders()
          ..active = const Err(ExchangeNetworkFailure()),
      ),
    ).execute(limitSession);
    expect(
      read,
      isA<Err<List<LimitOrder>, ExchangeReadFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<ExchangeUnreachableFailure>(),
      ),
    );
  });
}
