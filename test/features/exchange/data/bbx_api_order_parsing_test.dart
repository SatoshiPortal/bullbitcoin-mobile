import 'package:exchange/exchange.dart';
import 'package:bb_mobile/features/exchange/data/bbx_api_order_mapper.dart';
import 'package:bbx_api/bbx_api_testing.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../core/exchange/order_json_fixture.dart';

Order _parse(Map<String, dynamic> json) =>
    orderFromBbxApi(orderSummaryForTesting(json), isTestnet: false);

void main() {
  group('orderFromBbxApi status parsing', () {
    test("orderStatus 'Expired' parses instead of throwing", () {
      final order = _parse(orderJsonFixture(orderStatus: 'Expired'));

      expect(order.orderStatus, OrderStatus.orderExpired);
      expect(order.isExpired(), isTrue);
    });

    test("'Payment deadline expired' stays a distinct status", () {
      final order = _parse(
        orderJsonFixture(orderStatus: 'Payment deadline expired'),
      );

      expect(order.orderStatus, OrderStatus.expired);
      expect(order.isExpired(), isTrue);
    });

    test("payoutStatus 'Failed' parses", () {
      final order = _parse(orderJsonFixture(payoutStatus: 'Failed'));

      expect(order.payoutStatus, OrderPayoutStatus.failed);
    });

    test('statuses the app does not know fall back to unknown', () {
      final order = _parse(
        orderJsonFixture(
          orderStatus: 'Some Future Status',
          payinStatus: '',
          payoutStatus: 'Another Future Status',
        ),
      );

      expect(order.orderStatus, OrderStatus.unknown);
      expect(order.payinStatus, OrderPayinStatus.unknown);
      expect(order.payoutStatus, OrderPayoutStatus.unknown);
    });
  });

  group('orderFromBbxApi order type parsing', () {
    test("orderType 'Sell USDT' parses onto a generic order", () {
      final order = _parse(orderJsonFixture(orderType: 'Sell USDT'));

      expect(order, isA<GenericOrder>());
      expect(order.orderType, OrderType.sellUsdt);
      expect((order as GenericOrder).orderTypeName, 'Sell USDT');
    });

    test('an unknown order type keeps the server-sent name for display', () {
      final order = _parse(orderJsonFixture(orderType: 'Buy Gold Bars'));

      expect(order, isA<GenericOrder>());
      expect(order.orderType, OrderType.unknown);
      // The list row renders from these three, so none of them may be lost.
      expect((order as GenericOrder).orderTypeName, 'Buy Gold Bars');
      expect(order.orderStatus, OrderStatus.completed);
      expect(order.amountAndCurrencyToDisplay(), (100000, 'sats'));
    });
  });

  group('orderFromBbxApi nullable server fields', () {
    test('an integer unbatched buy fee parses as a double', () {
      final order = _parse(
        orderJsonFixture(overrides: const {'unbatchedBuyOnchainFees': 125}),
      ) as BuyOrder;

      expect(order.unbatchedBuyOnchainFees, 125.0);
    });

    test('a null exchange rate and deadline parse', () {
      final order = _parse(
        orderJsonFixture(
          overrides: const {
            'exchangeRateAmount': null,
            'exchangeRateCurrency': null,
            'confirmationDeadline': null,
          },
        ),
      ) as BuyOrder;

      expect(order.exchangeRateAmount, isNull);
      expect(order.exchangeRateCurrency, isNull);
      expect(order.confirmationDeadline, isNull);
    });

    test('absent triggerType parses instead of throwing', () {
      final json = orderJsonFixture()..remove('triggerType');

      expect(orderSummaryForTesting(json).triggerType, isNull);
      expect(_parse(json), isA<BuyOrder>());
    });

    test('absent exchange rate, deadline and amounts parse', () {
      final json = orderJsonFixture()
        ..remove('exchangeRateAmount')
        ..remove('exchangeRateCurrency')
        ..remove('confirmationDeadline')
        ..remove('payinAmount')
        ..remove('payinCurrency');

      final order = _parse(json) as BuyOrder;

      expect(order.exchangeRateAmount, isNull);
      expect(order.confirmationDeadline, isNull);
      expect(order.payinAmount, 0);
      expect(order.payinCurrency, '');
    });
  });

  group('reward orders', () {
    // The pay-in side of an admin-initiated reward is empty; the BTC credit is
    // on the payout side. Reading the pay-in side displayed '0 sats'.
    test('display the payout-side amount', () {
      final order = _parse(
        orderJsonFixture(
          orderType: 'Reward',
          overrides: const {
            'payinAmount': 0,
            'payinCurrency': '',
            'payoutAmount': 0.0005,
            'payoutCurrency': 'BTC',
            'exchangeRateAmount': null,
            'exchangeRateCurrency': null,
            'confirmationDeadline': null,
          },
        ),
      );

      expect(order, isA<RewardOrder>());
      expect(order.amountAndCurrencyToDisplay(), (50000, 'sats'));
      expect(order.displaysFiatAmount, isFalse);
    });
  });
}
