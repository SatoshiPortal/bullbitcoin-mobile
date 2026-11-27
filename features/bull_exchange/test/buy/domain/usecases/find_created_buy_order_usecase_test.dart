import 'package:bull_exchange/src/buy/domain/buy_state.dart';
import 'package:bull_exchange/src/buy/domain/buy_event.dart';
import 'package:bull_exchange/src/buy/domain/buy_payjoin_uris.dart';
import 'package:bull_exchange/src/buy/domain/usecases/find_created_buy_order_usecase.dart';
import 'package:bull_exchange/src/orders/domain/usecases/find_created_order_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../buy_fixtures.dart';
import '../../buy_test_ports.dart';

const _bip21 = 'bitcoin:bc1qreceive?pj=https://relay.example/abc';

BuyRequest _request() =>
    (applyBuy(buyEntryState, const [
              BuyAmountChanged(AmountTyped('10')),
              BuyContinuePressed(),
            ]).state
            as BuyOrdering)
        .request;

/// buyOrder() is created at 2026-11-24 10:00 UTC for 10 CAD.
final _sentAt = DateTime.utc(2026, 11, 24, 10);

Future<Result<BuyOrder, ExchangeReadFailure>> _find(
  BuyTestOrders orders,
  BuyPayjoinUris uris,
  BuyRequest request,
) => FindCreatedBuyOrderUsecase(
  FindCreatedOrderUsecase(exchangeForTesting(orders: (_) => orders)),
  uris,
).execute(buySession, request, _sentAt);

void main() {
  test('finds the buy order and gives it the URI its unknown create '
      'attached', () async {
    final orders = BuyTestOrders()..listed = Ok([buyOrder()]);
    final uris = BuyPayjoinUris();
    final request = _request();
    uris.attachToRequest(request, _bip21);
    final read = await _find(orders, uris, request);
    expect((read as Ok<BuyOrder, ExchangeReadFailure>).value.bip21URI, _bip21);
    expect(orders.log, ['list buy']);
    expect(uris.withBip21(buyOrder()).bip21URI, _bip21);
  });

  test('no match is missing and attaches nothing', () async {
    final orders = BuyTestOrders()..listed = const Ok([]);
    final read = await _find(orders, BuyPayjoinUris(), _request());
    expect(
      read,
      isA<Err<BuyOrder, ExchangeReadFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<ExchangeMissingFailure>(),
      ),
    );
  });

  test('a failed list is never a found order', () async {
    final orders = BuyTestOrders()
      ..listed = const Err(ExchangeNetworkFailure());
    final read = await _find(orders, BuyPayjoinUris(), _request());
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
