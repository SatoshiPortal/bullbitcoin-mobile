import 'package:bull_exchange/src/sell/domain/usecases/refresh_sell_order_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../../pay/pay_fixtures.dart';
import '../../../withdraw/withdraw_fixtures.dart';
import '../../sell_fixtures.dart';

final class _Orders extends Fake implements OrdersRepository {
  final asked = <String>[];

  @override
  Future<Result<SellOrder, ExchangeFailure>> refreshSellOrder(
    String orderId,
  ) async {
    asked.add('refresh sell $orderId');
    return Ok(sellOrder());
  }

  @override
  Future<Result<FiatPaymentOrder, ExchangeFailure>> refreshPayOrder(
    String orderId,
  ) async {
    asked.add('refresh pay $orderId');
    return const Err(ExchangeNetworkFailure());
  }

  @override
  Future<Result<Order, ExchangeFailure>> getOrder(String orderId) async {
    asked.add('get $orderId');
    return Ok(withdrawOrder());
  }
}

void main() {
  test('a sell order is refreshed as a sell, in the session '
      'environment', () async {
    final orders = _Orders();
    final environments = <ExchangeEnvironment>[];
    final read = await RefreshSellOrderUsecase(
      exchangeForTesting(
        orders: (environment) {
          environments.add(environment);
          return orders;
        },
      ),
    ).execute(sellSession, sellOrder());
    expect(read, isA<Ok<Order, ExchangeReadFailure>>());
    expect(orders.asked, ['refresh sell s-1']);
    expect(environments, [ExchangeEnvironment.mainnet]);
  });

  test('a pay order (sell to a recipient) is refreshed as a pay '
      'order', () async {
    final orders = _Orders();
    final read = await RefreshSellOrderUsecase(
      exchangeForTesting(orders: (_) => orders),
    ).execute(sellSession, payOrder());
    expect(
      read,
      isA<Err<Order, ExchangeReadFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<ExchangeUnreachableFailure>(),
      ),
    );
    expect(orders.asked, ['refresh pay ${payOrder().orderId}']);
  });

  test('any other order is only re-read', () async {
    final orders = _Orders();
    await RefreshSellOrderUsecase(exchangeForTesting(orders: (_) => orders))
        .execute(sellSession, withdrawOrder());
    expect(orders.asked, ['get w-1']);
  });
}
