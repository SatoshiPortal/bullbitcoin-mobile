import 'package:bull_exchange/src/orders/domain/usecases/get_order_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../../withdraw/withdraw_fixtures.dart';

const _session = ExchangeSession(
  environment: ExchangeEnvironment.testnet,
  epoch: 4,
  sessionId: 's',
);

final class _Orders extends Fake implements OrdersRepository {
  final Result<Order, ExchangeFailure> order;
  final asked = <String>[];

  _Orders({this.order = const Err(ExchangeUnexpectedFailure())});

  @override
  Future<Result<Order, ExchangeFailure>> getOrder(String orderId) async {
    asked.add('get $orderId');
    return order;
  }
}

Exchange _exchange(_Orders orders, List<ExchangeEnvironment> environments) =>
    exchangeForTesting(
      orders: (environment) {
        environments.add(environment);
        return orders;
      },
    );

void main() {
  test('reads the order in the session environment', () async {
    final environments = <ExchangeEnvironment>[];
    final orders = _Orders(order: Ok(withdrawOrder()));
    final read = await GetOrderUsecase(_exchange(orders, environments))
        .execute(_session, 'w-1');
    expect(
      read,
      isA<Ok<Order, ExchangeReadFailure>>().having(
        (r) => r.value.orderId,
        'orderId',
        'w-1',
      ),
    );
    expect(orders.asked, ['get w-1']);
    expect(environments, [ExchangeEnvironment.testnet]);
  });

  test('a rejected session is not an order', () async {
    final read = await GetOrderUsecase(
      _exchange(
        _Orders(
          order: const Err(
            ExchangeSessionRejectedFailure(ExchangeSessionRejection.server),
          ),
        ),
        [],
      ),
    ).execute(_session, 'w-1');
    expect(
      read,
      isA<Err<Order, ExchangeReadFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<ExchangeSessionRejectedFailure>(),
      ),
    );
  });
}
