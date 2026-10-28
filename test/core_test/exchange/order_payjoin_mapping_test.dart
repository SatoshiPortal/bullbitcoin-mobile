import 'package:bb_mobile/bbx_api_setup.dart';
import 'package:bb_mobile/core/exchange/data/mappers/bbx_api_mapper.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:flutter_test/flutter_test.dart';

/// The exchange reports a payjoin on an order through two fields: `bip21URI`,
/// the customer endpoint, and `payjoinDetails`, whose `txid` names the
/// transaction the exchange considers final.
///
/// The property these tests pin is that a payjoin is only ever claimed when the
/// exchange actually reports one. A payout that silently fell back to a plain
/// transaction, or an order from a backend that predates the fields, must map to
/// null rather than to something a screen could read as a completed payjoin.
void main() {
  bbx.OrderSummary summaryOf(Map<String, dynamic> json) =>
      bbx.OrderSummaryModel.fromJson(
        json,
        fallbacks: BbxApiSetup.orderSummaryParsing.fallbacks,
      );

  Order orderOf(Map<String, dynamic> json) =>
      BbxApiMapper.orderFromSummary(summaryOf(json), isTestnet: true);

  Map<String, dynamic> orderJson({
    required String type,
    String? bip21URI,
    Map<String, dynamic>? payjoinDetails,
  }) => {
    'orderId': 'order-1',
    'orderType': type,
    'orderNumber': 1,
    'exchangeRateAmount': 100000,
    'exchangeRateCurrency': 'CAD',
    'payinAmount': 100.0,
    'payinCurrency': 'CAD',
    'payoutAmount': 0.001,
    'payoutCurrency': 'BTC',
    'orderStatus': 'In progress',
    'payinStatus': 'Awaiting payment',
    'payoutStatus': 'Not started',
    'createdAt': '2026-07-28T12:00:00.000Z',
    'confirmationDeadline': '2026-07-28T12:05:00.000Z',
    'message': <String, dynamic>{'code': '', 'message': ''},
    'payinMethod': 'CAD Balance',
    'payoutMethod': 'Bitcoin On-Chain',
    'triggerType': 'MANUAL',
    'bip21URI': ?bip21URI,
    'payjoinDetails': ?payjoinDetails,
  };

  ({String? uri, OrderPayjoinDetails? details}) payjoinOf(Order order) =>
      switch (order) {
        BuyOrder(:final bip21URI, :final payjoinDetails) => (
          uri: bip21URI,
          details: payjoinDetails,
        ),
        SellOrder(:final bip21URI, :final payjoinDetails) => (
          uri: bip21URI,
          details: payjoinDetails,
        ),
        FiatPaymentOrder(:final bip21URI, :final payjoinDetails) => (
          uri: bip21URI,
          details: payjoinDetails,
        ),
        _ => throw StateError('unexpected order variant: $order'),
      };

  const uri =
      'bitcoin:tb1q6q6de88mj8qkg0q5lupmpfexwnqjsr4d2gvx2p?amount=0.001'
      '&pjos=0&pj=HTTPS://PAYJO.IN/TXJCGKTKXLUUZ%23EX1WKV8CEC-OH1QYPM-RK1Q0DJS';
  final payjoinTxId = 'b' * 64;

  // Every order type that can carry a payjoin: buy makes the app the receiver,
  // sell and payment make it the sender.
  for (final type in ['Buy Bitcoin', 'Sell Bitcoin', 'Fiat Payment']) {
    group('$type order', () {
      test('carries the endpoint and the payjoin txid', () {
        final order = orderOf(
          orderJson(
            type: type,
            bip21URI: uri,
            payjoinDetails: {'txid': payjoinTxId},
          ),
        );

        final payjoin = payjoinOf(order);
        expect(payjoin.uri, equals(uri));
        expect(payjoin.details?.txid, equals(payjoinTxId));
      });

      test('maps to null when the exchange reports no payjoin', () {
        final order = orderOf(orderJson(type: type));

        final payjoin = payjoinOf(order);
        expect(payjoin.uri, isNull);
        expect(
          payjoin.details,
          isNull,
          reason: 'an order without payjoin must not look like one',
        );
      });

      test('reports an attempted but unseen payjoin as a null txid', () {
        // The exchange knows about the payjoin and has not observed the
        // transaction yet. That is distinct from "no payjoin at all": the object
        // exists, its txid does not.
        final order = orderOf(
          orderJson(
            type: type,
            bip21URI: uri,
            payjoinDetails: <String, dynamic>{'txid': null},
          ),
        );

        final payjoin = payjoinOf(order);
        expect(payjoin.details, isNotNull);
        expect(payjoin.details?.txid, isNull);
      });
    });
  }

  group('the endpoint survives mapping byte for byte', () {
    test('no re-encoding of the pj parameter', () {
      final order = orderOf(orderJson(type: 'Sell Bitcoin', bip21URI: uri));

      // The URI goes to the payjoin PDK verbatim; percent-encoding the `://` of
      // the endpoint is exactly how it gets corrupted.
      expect(payjoinOf(order).uri, equals(uri));
      expect(payjoinOf(order).uri, contains('HTTPS://'));
      expect(payjoinOf(order).uri, isNot(contains('%3A%2F%2F')));
    });
  });

  group('matching an order by txid', () {
    bool matches(
      String txId, {
      String? bitcoinTransactionId,
      String? liquidTransactionId,
      Map<String, dynamic>? payjoinDetails,
    }) => BbxApiMapper.orderMatchesTxId(
      summaryOf({
        ...orderJson(type: 'Sell Bitcoin', payjoinDetails: payjoinDetails),
        'bitcoinTransactionId': ?bitcoinTransactionId,
        'liquidTransactionId': ?liquidTransactionId,
      }),
      txId,
    );

    test('matches the payjoin txid', () {
      // The order's own txid is the original transaction, which a payjoin
      // replaces — without this the payjoin send loses its order.
      expect(
        matches(payjoinTxId, payjoinDetails: {'txid': payjoinTxId}),
        isTrue,
      );
    });

    test('still matches the bitcoin and liquid txids', () {
      expect(matches('a' * 64, bitcoinTransactionId: 'a' * 64), true);
      expect(matches('c' * 64, liquidTransactionId: 'c' * 64), true);
    });

    test('does not match an unrelated txid', () {
      expect(
        matches(
          'd' * 64,
          bitcoinTransactionId: 'a' * 64,
          payjoinDetails: {'txid': payjoinTxId},
        ),
        isFalse,
      );
    });

    test('a null payjoin txid never matches', () {
      expect(
        matches('', payjoinDetails: <String, dynamic>{'txid': null}),
        isFalse,
      );
    });
  });
}
