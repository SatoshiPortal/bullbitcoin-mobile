import 'package:bull_exchange/src/buy/domain/buy_payjoin_uris.dart';
import 'package:bull_exchange/src/buy/domain/usecases/get_buy_order_usecase.dart';
import 'package:bull_exchange/src/orders/domain/usecases/get_order_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../../payin/payin_fixtures.dart';
import '../../buy_fixtures.dart';
import '../../buy_test_ports.dart';

Future<ExchangeRead<BuyOrder>> _get(
  BuyTestOrders orders,
  BuyPayjoinUris uris,
) => GetBuyOrderUsecase(
  GetOrderUsecase(exchangeForTesting(orders: (_) => orders)),
  uris,
).execute(buySession, 'b-1');

void main() {
  test('a buy order keeps the URI its create attached', () async {
    final orders = BuyTestOrders()..read = Ok(buyOrder());
    final uris = BuyPayjoinUris()..attachToOrder('b-1', 'bitcoin:x?pj=y');
    final read = await _get(orders, uris);
    expect((read as ReadGot<BuyOrder>).value.bip21URI, 'bitcoin:x?pj=y');
    expect(orders.log, ['read b-1']);
  });

  test('another order class is malformed; a failure passes', () async {
    final sell = BuyTestOrders()..read = Ok(payinOrder());
    expect(await _get(sell, BuyPayjoinUris()), isA<ReadMalformed<BuyOrder>>());
    final failed = BuyTestOrders()..read = const Err(ExchangeNetworkFailure());
    expect(
      await _get(failed, BuyPayjoinUris()),
      isA<ReadUnreachable<BuyOrder>>(),
    );
  });
}
