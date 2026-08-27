import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:flutter_test/flutter_test.dart';

/// The outcome drives what the success screens claim, so the property under test
/// is that a payjoin is only ever claimed when the exchange reports the
/// transaction it settled through. A payout that fell back to an ordinary
/// transaction must read as a plain send, never as a payjoin.
void main() {
  Order buyOrder({
    String? bip21URI,
    OrderPayjoinDetails? payjoinDetails,
    String? bitcoinTransactionId,
  }) => Order.buy(
    orderId: 'o1',
    orderType: OrderType.buy,
    message: OrderMessage(code: '', message: ''),
    orderNumber: 1,
    payinAmount: 100,
    payinCurrency: 'CAD',
    payoutAmount: 0.001,
    payoutCurrency: 'BTC',
    payinMethod: OrderPaymentMethod.cadBalance,
    payoutMethod: OrderPaymentMethod.bitcoin,
    orderStatus: OrderStatus.inProgress,
    payinStatus: OrderPayinStatus.completed,
    payoutStatus: OrderPayoutStatus.inProgress,
    confirmationDeadline: DateTime.utc(2026, 7, 28, 12, 5),
    createdAt: DateTime.utc(2026, 7, 28, 12),
    bitcoinAddress: 'tb1qtest',
    bitcoinTransactionId: bitcoinTransactionId,
    bip21URI: bip21URI,
    payjoinDetails: payjoinDetails,
    isTestnet: true,
  );

  const endpoint = 'bitcoin:tb1qtest?amount=0.001&pj=HTTPS://PAYJO.IN/X%23EX1';
  final payjoinTxId = 'b' * 64;
  final plainTxId = 'a' * 64;

  test('no endpoint and no details is not a payjoin order at all', () {
    final outcome = buyOrder().payjoinOutcome;

    expect(outcome, OrderPayjoinOutcome.none);
    expect(outcome.hasPayjoin, isFalse);
    expect(outcome.isOngoing, isFalse);
  });

  test('an endpoint with no settlement yet is in progress', () {
    final outcome = buyOrder(bip21URI: endpoint).payjoinOutcome;

    expect(outcome, OrderPayjoinOutcome.inProgress);
    expect(outcome.isOngoing, isTrue);
  });

  test('a reported payjoin txid is a success', () {
    final outcome = buyOrder(
      bip21URI: endpoint,
      payjoinDetails: OrderPayjoinDetails(txid: payjoinTxId),
    ).payjoinOutcome;

    expect(outcome, OrderPayjoinOutcome.succeeded);
  });

  test('settled with no payjoin txid is a plain send, not a payjoin', () {
    // The exchange paid, but not through payjoin: nobody answered, or the
    // customer opted out. Claiming a payjoin here would be a lie.
    final outcome = buyOrder(
      bip21URI: endpoint,
      bitcoinTransactionId: plainTxId,
    ).payjoinOutcome;

    expect(outcome, OrderPayjoinOutcome.plainSend);
  });

  test('a payjoin txid wins over the order settlement txid', () {
    // Both are present once a payjoin confirms; the payjoin one is the truth.
    final outcome = buyOrder(
      bip21URI: endpoint,
      bitcoinTransactionId: payjoinTxId,
      payjoinDetails: OrderPayjoinDetails(txid: payjoinTxId),
    ).payjoinOutcome;

    expect(outcome, OrderPayjoinOutcome.succeeded);
  });

  test('details present but txid still null stays in progress', () {
    final outcome = buyOrder(
      bip21URI: endpoint,
      payjoinDetails: OrderPayjoinDetails(),
    ).payjoinOutcome;

    expect(outcome, OrderPayjoinOutcome.inProgress);
  });

  test('exposes the endpoint verbatim', () {
    expect(buyOrder(bip21URI: endpoint).payjoinBip21, endpoint);
    expect(buyOrder().payjoinBip21, isNull);
  });
}
