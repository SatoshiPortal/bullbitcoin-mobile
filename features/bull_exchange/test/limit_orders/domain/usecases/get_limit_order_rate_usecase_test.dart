import 'package:bull_exchange/src/limit_orders/domain/usecases/get_limit_order_rate_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../limit_order_fixtures.dart';
import '../../limit_test_orders.dart';

void main() {
  test('reads the rate in the market currency', () async {
    final orders = LimitTestOrders()
      ..rate = Ok(limitOrderRate(indexPrice: 90000));
    final read = await GetLimitOrderRateUsecase(
      exchangeForTesting(limitOrders: orders),
    ).execute(limitSession, ExchangeCatalog.eur);
    expect(
      (read as Ok<LimitOrderRate, ExchangeReadFailure>).value.indexPrice,
      90000,
    );
    expect(orders.log, ['rate EUR']);
  });

  test('a failed read is never a rate', () async {
    final read = await GetLimitOrderRateUsecase(
      exchangeForTesting(
        limitOrders: LimitTestOrders()
          ..rate = const Err(ExchangeNetworkFailure()),
      ),
    ).execute(limitSession, ExchangeCatalog.cad);
    expect(
      read,
      isA<Err<LimitOrderRate, ExchangeReadFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<ExchangeUnreachableFailure>(),
      ),
    );
  });
}
