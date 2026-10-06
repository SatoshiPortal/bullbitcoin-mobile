import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order_amount_limits.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order_creation_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // userPrice 100000 => 1 fiat unit == 1000 sats.
  group('LimitOrderAmountLimits', () {
    test('flags a bitcoin amount below the on-chain minimum', () {
      final violation = LimitOrderAmountLimits.check(
        fiatAmount: 1, // 1000 sats < 100000
        userPrice: 100000,
        network: LimitOrderWalletType.bitcoin,
      );

      expect(violation, isNotNull);
      expect(violation!.kind, LimitOrderAmountViolationKind.belowMinimum);
      expect(violation.boundBtc, 0.001);
    });

    test('accepts a bitcoin amount at or above the on-chain minimum', () {
      expect(
        LimitOrderAmountLimits.check(
          fiatAmount: 200, // 200000 sats
          userPrice: 100000,
          network: LimitOrderWalletType.bitcoin,
        ),
        isNull,
      );
    });

    test('flags a liquid amount below the liquid minimum', () {
      final violation = LimitOrderAmountLimits.check(
        fiatAmount: 0.5, // 500 sats < 1000
        userPrice: 100000,
        network: LimitOrderWalletType.liquid,
      );

      expect(violation, isNotNull);
      expect(violation!.kind, LimitOrderAmountViolationKind.belowMinimum);
      expect(violation.boundBtc, 0.00001);
    });

    test('accepts a liquid amount at or above the liquid minimum', () {
      expect(
        LimitOrderAmountLimits.check(
          fiatAmount: 2, // 2000 sats
          userPrice: 100000,
          network: LimitOrderWalletType.liquid,
        ),
        isNull,
      );
    });

    test('flags a lightning amount above the lightning maximum', () {
      final violation = LimitOrderAmountLimits.check(
        fiatAmount: 30000, // 30,000,000 sats > 25,000,000
        userPrice: 100000,
        network: LimitOrderWalletType.lightning,
      );

      expect(violation, isNotNull);
      expect(violation!.kind, LimitOrderAmountViolationKind.aboveMaximum);
      expect(violation.boundBtc, 0.25);
    });

    test('accepts a lightning amount at or below the lightning maximum', () {
      expect(
        LimitOrderAmountLimits.check(
          fiatAmount: 10000, // 10,000,000 sats
          userPrice: 100000,
          network: LimitOrderWalletType.lightning,
        ),
        isNull,
      );
    });

    test('returns null for a non-positive amount', () {
      expect(
        LimitOrderAmountLimits.check(
          fiatAmount: 0,
          userPrice: 100000,
          network: LimitOrderWalletType.bitcoin,
        ),
        isNull,
      );
    });
  });
}
