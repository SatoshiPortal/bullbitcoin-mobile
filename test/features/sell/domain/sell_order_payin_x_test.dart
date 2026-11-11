import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/features/sell/domain/sell_order_payin_x.dart';
import 'package:flutter_test/flutter_test.dart';

SellOrder _order({
  required OrderPaymentMethod payinMethod,
  String? bitcoinAddress,
  String? liquidAddress,
}) => SellOrder(
  orderId: 'order',
  orderType: OrderType.sell,
  message: OrderMessage(code: '', message: ''),
  orderNumber: 1,
  payinAmount: 0.001,
  payinCurrency: 'BTC',
  payoutAmount: 100,
  payoutCurrency: 'EUR',
  payinMethod: payinMethod,
  payoutMethod: OrderPaymentMethod.eurBalance,
  orderStatus: OrderStatus.inProgress,
  payinStatus: OrderPayinStatus.awaitingPayment,
  payoutStatus: OrderPayoutStatus.notStarted,
  createdAt: DateTime(2026),
  bitcoinAddress: bitcoinAddress,
  liquidAddress: liquidAddress,
  isTestnet: true,
);

void main() {
  const btc = 'bc1qbitcoinaddress';
  const lbtc = 'lq1qliquidaddress';

  test(
    'a Liquid payin returns the Liquid address even when both are present',
    () {
      final order = _order(
        payinMethod: OrderPaymentMethod.liquid,
        bitcoinAddress: btc,
        liquidAddress: lbtc,
      );
      expect(order.sellPayinAddress, lbtc);
    },
  );

  test(
    'a Bitcoin payin returns the Bitcoin address even when both are present',
    () {
      final order = _order(
        payinMethod: OrderPaymentMethod.bitcoin,
        bitcoinAddress: btc,
        liquidAddress: lbtc,
      );
      expect(order.sellPayinAddress, btc);
    },
  );

  test('a Lightning payin carries no on-chain payin address', () {
    final order = _order(
      payinMethod: OrderPaymentMethod.lnInvoice,
      bitcoinAddress: btc,
      liquidAddress: lbtc,
    );
    expect(order.sellPayinAddress, isNull);
  });
}
