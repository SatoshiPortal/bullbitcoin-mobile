import 'package:bb_mobile/core/exchange/data/models/order_model.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../order_json_fixture.dart';

void main() {
  group('OrderModel status parsing', () {
    test("orderStatus 'Expired' parses instead of throwing", () {
      final order = OrderModel.fromJson(
        orderJsonFixture(orderStatus: 'Expired'),
      ).toEntity(isTestnet: false);

      expect(order.orderStatus, OrderStatus.orderExpired);
      expect(order.isExpired(), isTrue);
    });

    test("'Payment deadline expired' stays a distinct status", () {
      final order = OrderModel.fromJson(
        orderJsonFixture(orderStatus: 'Payment deadline expired'),
      ).toEntity(isTestnet: false);

      expect(order.orderStatus, OrderStatus.expired);
      expect(order.isExpired(), isTrue);
    });

    test("payoutStatus 'Failed' parses", () {
      final order = OrderModel.fromJson(
        orderJsonFixture(payoutStatus: 'Failed'),
      ).toEntity(isTestnet: false);

      expect(order.payoutStatus, OrderPayoutStatus.failed);
    });

    test('statuses the app does not know fall back to unknown', () {
      final order = OrderModel.fromJson(
        orderJsonFixture(
          orderStatus: 'Some Future Status',
          payinStatus: '',
          payoutStatus: 'Another Future Status',
        ),
      ).toEntity(isTestnet: false);

      expect(order.orderStatus, OrderStatus.unknown);
      expect(order.payinStatus, OrderPayinStatus.unknown);
      expect(order.payoutStatus, OrderPayoutStatus.unknown);
    });
  });

  group('OrderModel order type parsing', () {
    test("orderType 'Sell USDT' parses onto a generic order", () {
      final order = OrderModel.fromJson(
        orderJsonFixture(orderType: 'Sell USDT'),
      ).toEntity(isTestnet: false);

      expect(order, isA<GenericOrder>());
      expect(order.orderType, OrderType.sellUsdt);
      expect(order.orderTypeLabel, 'Sell USDT');
    });

    test('an unknown order type keeps the server-sent name for display', () {
      final order = OrderModel.fromJson(
        orderJsonFixture(orderType: 'Buy Gold Bars'),
      ).toEntity(isTestnet: false);

      expect(order, isA<GenericOrder>());
      expect(order.orderType, OrderType.unknown);
      // The list row renders from these three, so none of them may be lost.
      expect(order.orderTypeLabel, 'Buy Gold Bars');
      expect(order.orderStatus, OrderStatus.completed);
      expect(order.amountAndCurrencyToDisplay(), (100000, 'sats'));
    });
  });

  group('OrderModel nullable server fields', () {
    test('a null exchange rate and deadline parse', () {
      final order =
          OrderModel.fromJson(
                orderJsonFixture(
                  overrides: const {
                    'exchangeRateAmount': null,
                    'exchangeRateCurrency': null,
                    'confirmationDeadline': null,
                  },
                ),
              ).toEntity(isTestnet: false)
              as BuyOrder;

      expect(order.exchangeRateAmount, isNull);
      expect(order.exchangeRateCurrency, isNull);
      expect(order.confirmationDeadline, isNull);
    });

    test('absent exchange rate, deadline and amounts parse', () {
      final json = orderJsonFixture()
        ..remove('exchangeRateAmount')
        ..remove('exchangeRateCurrency')
        ..remove('confirmationDeadline')
        ..remove('payinAmount')
        ..remove('payinCurrency');

      final order =
          OrderModel.fromJson(json).toEntity(isTestnet: false) as BuyOrder;

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
      final order = OrderModel.fromJson(
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
      ).toEntity(isTestnet: false);

      expect(order, isA<RewardOrder>());
      expect(order.amountAndCurrencyToDisplay(), (50000, 'sats'));
      expect(order.displaysFiatAmount, isFalse);
    });
  });
}
