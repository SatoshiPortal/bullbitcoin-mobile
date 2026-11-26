import 'package:bull_exchange/src/pay/domain/usecases/refresh_pay_order_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../pay_fixtures.dart';

final class _Orders extends Fake implements OrdersRepository {
  final Result<FiatPaymentOrder, ExchangeFailure> answer;
  final asked = <String>[];

  _Orders(this.answer);

  @override
  Future<Result<FiatPaymentOrder, ExchangeFailure>> refreshPayOrder(
    String orderId,
  ) async {
    asked.add(orderId);
    return answer;
  }
}

void main() {
  test('refreshes the pay order in the session environment', () async {
    final orders = _Orders(Ok(payOrder()));
    final environments = <ExchangeEnvironment>[];
    final read = await RefreshPayOrderUsecase(
      exchangeForTesting(
        orders: (environment) {
          environments.add(environment);
          return orders;
        },
      ),
    ).execute(paySession, 'p-1');
    expect(read, isA<ReadGot<Order>>());
    expect(orders.asked, ['p-1']);
    expect(environments, [ExchangeEnvironment.mainnet]);
  });

  test('a failed refresh is never a quote', () async {
    final read = await RefreshPayOrderUsecase(
      exchangeForTesting(
        orders: (_) => _Orders(const Err(ExchangeNetworkFailure())),
      ),
    ).execute(paySession, 'p-1');
    expect(read, isA<ReadUnreachable<Order>>());
  });
}
