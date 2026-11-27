import 'package:bull_exchange/src/buy/domain/buy_payjoin_uris.dart';
import 'package:bull_exchange/src/buy/domain/usecases/refresh_buy_order_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../buy_fixtures.dart';
import '../../buy_test_ports.dart';

void main() {
  test('the fresh quote keeps the URI its create attached', () async {
    final environments = <ExchangeEnvironment>[];
    final orders = BuyTestOrders()..refreshed = Ok(buyOrder());
    final uris = BuyPayjoinUris()..attachToOrder('b-1', 'bitcoin:x?pj=y');
    final read = await RefreshBuyOrderUsecase(
      exchangeForTesting(
        orders: (environment) {
          environments.add(environment);
          return orders;
        },
      ),
      uris,
    ).execute(buySession, 'b-1');
    expect(
      (read as Ok<BuyOrder, ExchangeReadFailure>).value.bip21URI,
      'bitcoin:x?pj=y',
    );
    expect(orders.log, ['refresh b-1']);
    expect(environments, [ExchangeEnvironment.mainnet]);
  });

  test('a failed refresh is the answer', () async {
    final orders = BuyTestOrders()
      ..refreshed = const Err(ExchangeNetworkFailure());
    final read = await RefreshBuyOrderUsecase(
      exchangeForTesting(orders: (_) => orders),
      BuyPayjoinUris(),
    ).execute(buySession, 'b-1');
    expect(
      read,
      isA<Err<BuyOrder, ExchangeReadFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<ExchangeUnreachableFailure>(),
      ),
    );
  });
}
