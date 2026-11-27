import 'package:bull_exchange/src/limit_orders/domain/usecases/get_limit_order_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../limit_order_fixtures.dart';
import '../../limit_test_orders.dart';

Future<ExchangeRead<LimitOrder>> _read(LimitTestOrders orders) =>
    GetLimitOrderUsecase(exchangeForTesting(limitOrders: orders))
        .execute(limitSession, 'lo-1');

void main() {
  test('reads the order by id', () async {
    final orders = LimitTestOrders()..read = Ok(limitOrder());
    final read = await _read(orders);
    expect((read as ReadGot<LimitOrder>).value.id, 'lo-1');
    expect(orders.log, ['get lo-1']);
  });

  test('an order the exchange does not know is missing, not a network '
      'failure', () async {
    expect(
      await _read(
        LimitTestOrders()
          ..read = const Err(
            ExchangeLimitOrderFailure(
              ExchangeLimitOrderProblem.notFound,
              '404',
            ),
          ),
      ),
      isA<ReadMissing<LimitOrder>>(),
    );
    expect(
      await _read(
        LimitTestOrders()..read = const Err(ExchangeNetworkFailure()),
      ),
      isA<ReadUnreachable<LimitOrder>>(),
    );
  });
}
