import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/buy/domain/create_buy_order_usecase.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockOrderRepository extends Mock implements ExchangeOrderRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockPayjoinReceiver extends Mock implements PayjoinReceiver {}

class _MockPayjoinPolicyAccess extends Mock implements PayjoinPolicyAccess {}

class _MockBuyOrder extends Mock implements BuyOrder {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      StartPayjoinReceiver(
        walletId: 'fallback',
        network: BitcoinNetwork.testnet,
        address: 'tb1qfallback',
      ),
    );
  });

  // The receiver starts before the exchange's five-minute payout window. It
  // needs a short margin without surviving for the protocol's 24-hour default.
  test(
    'the payjoin payout session expires with the exchange, not in 24h',
    () async {
      final orders = _MockOrderRepository();
      final settings = _MockSettingsRepository();
      final receiver = _MockPayjoinReceiver();
      final policy = _MockPayjoinPolicyAccess();

      when(() => settings.fetch()).thenAnswer(
        (_) async => const SettingsEntity(
          environment: Environment.testnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
        ),
      );
      when(() => policy.load()).thenAnswer(
        (_) async => Ok(
          PayjoinPolicy(
            enabled: true,
            tradingEnabled: true,
            minimumAmount: PayjoinPolicy.minimumAllowedAmount,
            sessionLifetime: PayjoinPolicy.minimumSessionLifetime,
          ),
        ),
      );
      when(
        () => orders.placeBuyOrder(
          toAddress: 'tb1qexampleaddress',
          orderAmount: const FiatAmount(100),
          currency: FiatCurrency.cad,
          network: OrderBitcoinNetwork.bitcoin,
          isOwner: true,
          payjoinBip21: null,
        ),
      ).thenAnswer((_) async => _MockBuyOrder());

      StartPayjoinReceiver? captured;
      when(() => receiver.start(any())).thenAnswer((invocation) async {
        captured = invocation.positionalArguments.first as StartPayjoinReceiver;
        throw StateError('stop here: the expiry is what this test is about');
      });

      final usecase = CreateBuyOrderUsecase(
        mainnetExchangeOrderRepository: orders,
        testnetExchangeOrderRepository: orders,
        settingsRepository: settings,
        payjoinReceiver: receiver,
        payjoinPolicy: policy,
      );

      final before = DateTime.now();
      await usecase.execute(
        toAddress: 'tb1qexampleaddress',
        orderAmount: const FiatAmount(100),
        currency: FiatCurrency.cad,
        isLiquid: false,
        isOwner: true,
        payjoinWalletId: 'wallet-1',
        payjoinAmountSat: 50000,
      );
      final after = DateTime.now();

      final expiresAt = captured?.expiresAt;
      expect(expiresAt, isNotNull, reason: 'a payjoin session must be started');

      // Bracketed against the wall clock either side of the call: the use case
      // computes its own `now` somewhere between `before` and `after`, so the
      // deadline must land in [before + 6m, after + 6m]. Tight enough that 24h
      // fails, loose enough that a slow machine does not.
      expect(
        expiresAt!.isBefore(before.add(const Duration(minutes: 6))),
        isFalse,
      );
      expect(expiresAt.isAfter(after.add(const Duration(minutes: 6))), isFalse);
    },
  );
}
