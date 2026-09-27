import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order_draft.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order_rate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LimitOrderStatus', () {
    test('parses every known wire value', () {
      expect(LimitOrderStatus.fromValue('ACTIVE'), LimitOrderStatus.active);
      expect(LimitOrderStatus.fromValue('EXECUTED'), LimitOrderStatus.executed);
      expect(
        LimitOrderStatus.fromValue('CANCELLED'),
        LimitOrderStatus.cancelled,
      );
      expect(LimitOrderStatus.fromValue('EXPIRED'), LimitOrderStatus.expired);
    });

    test('treats an unknown wire value as failed', () {
      expect(LimitOrderStatus.fromValue('WAT'), LimitOrderStatus.failed);
    });
  });

  group('LimitOrderDraft', () {
    test('derives the estimated bitcoin amount', () {
      final draft = LimitOrderDraft(
        limitPrice: 50000,
        fiatAmount: 100,
        currencyCode: 'CAD',
        address: 'bc1qexample',
      );

      expect(draft.estimatedBtcAmount, closeTo(0.002, 1e-9));
    });

    test('cannot be built with a non-positive amount', () {
      expect(
        () => LimitOrderDraft(
          limitPrice: 50000,
          fiatAmount: 0,
          currencyCode: 'CAD',
          address: 'bc1qexample',
        ),
        throwsArgumentError,
      );
    });

    test('cannot be built with a blank address', () {
      expect(
        () => LimitOrderDraft(
          limitPrice: 50000,
          fiatAmount: 100,
          currencyCode: 'CAD',
          address: '   ',
        ),
        throwsArgumentError,
      );
    });
  });

  group('LimitOrder', () {
    test('cannot be built with a non-positive limit price', () {
      expect(
        () => LimitOrder(
          id: 'lo-1',
          number: 'LO-1',
          fiatAmount: 100,
          currencyCode: 'CAD',
          limitPrice: 0,
          estimatedBtcAmount: 0.001,
          status: LimitOrderStatus.active,
          createdAt: DateTime.utc(2026),
          expiresAt: DateTime.utc(2027),
          address: 'bc1qexample',
        ),
        throwsArgumentError,
      );
    });
  });

  group('LimitOrderRate', () {
    final rate = LimitOrderRate(
      currencyCode: 'CAD',
      indexPrice: 100000,
      userPrice: 98000,
    );

    test('converts a discount to a target price', () {
      expect(rate.priceForDiscount(10), closeTo(90000, 1e-9));
    });

    test('clamps the discount to the supported 1-99 range', () {
      expect(rate.priceForDiscount(0), closeTo(99000, 1e-9));
      expect(rate.priceForDiscount(120), closeTo(1000, 1e-9));
    });

    test('round-trips a target price back to its discount', () {
      expect(
        rate.discountForPrice(rate.priceForDiscount(25)),
        closeTo(25, 1e-9),
      );
    });

    test('applies the user spread to the estimated buy price', () {
      expect(rate.estimatedBuyPrice(90000), closeTo(88200, 1e-9));
    });
  });
}
