import 'package:bull_exchange/src/limit_orders/domain/entities/limit_order_amount_limits.dart';
import 'package:bull_exchange/src/limit_orders/domain/limit_order_flow.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // userPrice 100000 => 1 fiat unit == 1000 sats.
  group('limitAmountLimits', () {
    test('on-chain has the on-chain minimum and no maximum', () {
      final limits = limitAmountLimits(BtcNetwork.bitcoin, 100000);
      expect(limits.minFiat, closeTo(100, 1e-9));
      expect(limits.maxFiat, isNull);
    });

    test('Liquid has the Liquid minimum and no maximum', () {
      final limits = limitAmountLimits(BtcNetwork.liquid, 100000);
      expect(limits.minFiat, closeTo(1, 1e-9));
      expect(limits.maxFiat, isNull);
    });

    test('Lightning has the Lightning maximum and no minimum', () {
      final limits = limitAmountLimits(BtcNetwork.lightning, 100000);
      expect(limits.minFiat, isNull);
      expect(limits.maxFiat, closeTo(25000, 1e-9));
    });

    test('the bounds are the mirrored sat limits', () {
      expect(LimitOrderAmountLimits.minOnChainSats, 100000);
      expect(LimitOrderAmountLimits.minLiquidSats, 1000);
      expect(LimitOrderAmountLimits.maxLightningSats, 25000000);
    });
  });

  group('the amount step refuses an amount out of the rail limits', () {
    final target = PricedTarget.at(
      ExchangeCatalog.cad,
      LimitOrderRate(
        currencyCode: 'CAD',
        indexPrice: 100000,
        userPrice: 100000,
      ),
    );
    const context = AmountContext(
      kycGroups: {KycGroup.identityVerified},
      balances: {FiatCurrency.cad: 1000000},
    );
    AmountCheck check(Destination destination, String text) => checkAmount(
      limitAmountPolicy(target, destination),
      AmountDraft(market: ExchangeCatalog.cad, text: text),
      RateReady(MarketRate(ExchangeCatalog.cad, target.limitPrice)),
      context,
    );

    test('below the on-chain minimum', () {
      expect(
        check(const DestinationDefaultWallet(BtcNetwork.bitcoin, 'bc1q'), '1'),
        isA<AmountCheckRefused>().having(
          (c) => c.problem,
          'problem',
          isA<AmountBelowMinimum>(),
        ),
      );
      expect(
        check(
          const DestinationDefaultWallet(BtcNetwork.bitcoin, 'bc1q'),
          '200',
        ),
        isA<AmountCheckPassed>(),
      );
    });

    test('below the Liquid minimum', () {
      expect(
        check(const DestinationDefaultWallet(BtcNetwork.liquid, 'lq1'), '0.5'),
        isA<AmountCheckRefused>(),
      );
      expect(
        check(const DestinationDefaultWallet(BtcNetwork.liquid, 'lq1'), '2'),
        isA<AmountCheckPassed>(),
      );
    });

    test('above the Lightning maximum', () {
      expect(
        check(const DestinationAddress(BtcNetwork.lightning, 'a@b.c'), '30000'),
        isA<AmountCheckRefused>().having(
          (c) => c.problem,
          'problem',
          isA<AmountAboveMaximum>(),
        ),
      );
      expect(
        check(const DestinationAddress(BtcNetwork.lightning, 'a@b.c'), '200'),
        isA<AmountCheckPassed>(),
      );
    });
  });
}
