import 'package:exchange/testing.dart';
import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/buy/domain/accelerate_buy_order_usecase.dart';
import 'package:bb_mobile/features/buy/domain/buy_failure.dart';
import 'package:bb_mobile/features/buy/domain/confirm_buy_order_usecase.dart';
import 'package:bb_mobile/features/buy/domain/refresh_buy_order_usecase.dart';
import 'package:labels/labels.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockExchangeOrders extends Mock implements ExchangeOrders {}

class _MockSettingsRepository extends Mock implements Preferences {}

class _MockSettings extends Mock implements SettingsEntity {}

class _MockLabels extends Mock implements Labels {}

class _MockBuyOrder extends Mock implements BuyOrder {}

class _FakeNewLabel extends Fake implements NewLabel {}

class _FakeLabel extends Fake implements Label {}

/// A reason of the shape the exchange API produces, quoting a key.

void main() {
  late _MockExchangeOrders mainnet;
  late _MockExchangeOrders testnet;
  late _MockSettingsRepository settingsRepository;

  setUpAll(() => registerFallbackValue(_FakeNewLabel()));

  setUp(() {
    mainnet = _MockExchangeOrders();
    testnet = _MockExchangeOrders();
    settingsRepository = _MockSettingsRepository();
    final settings = _MockSettings();
    when(() => settings.environment).thenReturn(Environment.mainnet);
    when(settingsRepository.fetch).thenAnswer((_) async => Ok(settings));
  });

  test(
    'regtest refuses buy order operations before any backend access',
    () async {
      final settings = _MockSettings();
      when(() => settings.environment).thenReturn(Environment.regtest);
      when(settingsRepository.fetch).thenAnswer((_) async => Ok(settings));
      final labels = _MockLabels();
      final refresh = RefreshBuyOrderUsecase(
        exchange: exchangeForTesting(
          orders: (environment) =>
              environment == ExchangeEnvironment.testnet ? testnet : mainnet,
        ),
        settingsRepository: settingsRepository,
      );
      final results = [
        await refresh.execute(orderId: 'order-1'),
        await refresh.execute(orderId: 'order-1', confirmed: true),
        await ConfirmBuyOrderUsecase(
          exchange: exchangeForTesting(
            orders: (environment) =>
                environment == ExchangeEnvironment.testnet ? testnet : mainnet,
          ),
          settingsRepository: settingsRepository,
          labelsFacade: labels,
        ).execute(orderId: 'order-1'),
        await AccelerateBuyOrderUsecase(
          exchange: exchangeForTesting(
            orders: (environment) =>
                environment == ExchangeEnvironment.testnet ? testnet : mainnet,
          ),
          settingsRepository: settingsRepository,
        ).execute('order-1'),
      ];
      for (final result in results) {
        expect(
          result,
          isA<Err<BuyOrder, BuyFailure>>().having(
            (result) => result.failure,
            'failure',
            isA<BuyUnsupportedNetworkFailure>(),
          ),
        );
      }
      verifyZeroInteractions(mainnet);
      verifyZeroInteractions(testnet);
      verifyZeroInteractions(labels);
    },
  );

  group('RefreshBuyOrderUsecase', () {
    RefreshBuyOrderUsecase build() => RefreshBuyOrderUsecase(
      exchange: exchangeForTesting(
        orders: (environment) =>
            environment == ExchangeEnvironment.testnet ? testnet : mainnet,
      ),
      settingsRepository: settingsRepository,
    );

    test('returns the refreshed order', () async {
      final order = _MockBuyOrder();
      when(() => mainnet.refreshBuyOrder('order-1'))
          .thenAnswer((_) async => Ok(order));

      final result = await build().execute(orderId: 'order-1');

      expect((result as Ok<BuyOrder, BuyFailure>).value, order);
    });

    // A confirmed order has no quote left: reading it must not ask the
    // exchange for a new one.
    test('reads a confirmed order without asking for a new quote', () async {
      final order = _MockBuyOrder();
      when(() => mainnet.getOrder('order-1'))
          .thenAnswer((_) async => Ok(order));

      final result = await build().execute(orderId: 'order-1', confirmed: true);

      expect((result as Ok<BuyOrder, BuyFailure>).value, order);
      verifyNever(() => mainnet.refreshBuyOrder(any()));
    });

    test('drops foreign diagnostic text from a failed refresh', () async {
      when(() => mainnet.refreshBuyOrder('order-1'))
          .thenAnswer((_) async => const Err(ExchangeOrderLoadFailure()));

      final result = await build().execute(orderId: 'order-1');

      switch (result) {
        case Ok():
          fail('a failed refresh must not report an order');
        case Err(:final failure):
          expect(failure, isA<BuyUnexpectedFailure>());
          expect(failure.logMessage, isNot(contains('secret123')));
      }
    });

    test('maps a missing or inactive API key to unauthenticated', () async {
      {
        when(
          () => mainnet.refreshBuyOrder('order-1'),
        ).thenAnswer((_) async => const Err(ExchangeNotAuthenticatedFailure()));

        final result = await build().execute(orderId: 'order-1');

        expect(
          (result as Err<BuyOrder, BuyFailure>).failure,
          isA<BuyUnauthenticatedFailure>(),
        );
      }
    });

    test('uses the testnet repository on testnet', () async {
      final settings = _MockSettings();
      when(() => settings.environment).thenReturn(Environment.testnet);
      when(settingsRepository.fetch).thenAnswer((_) async => Ok(settings));
      when(() => testnet.refreshBuyOrder('order-1'))
          .thenAnswer((_) async => Ok(_MockBuyOrder()));

      expect(
        await build().execute(orderId: 'order-1'),
        isA<Ok<BuyOrder, BuyFailure>>(),
      );
      verifyNever(() => mainnet.refreshBuyOrder(any()));
    });
  });

  group('ConfirmBuyOrderUsecase', () {
    late _MockLabels labels;

    ConfirmBuyOrderUsecase build() => ConfirmBuyOrderUsecase(
      exchange: exchangeForTesting(
        orders: (environment) =>
            environment == ExchangeEnvironment.testnet ? testnet : mainnet,
      ),
      settingsRepository: settingsRepository,
      labelsFacade: labels,
    );

    setUp(() {
      labels = _MockLabels();
      when(() => labels.store(any()))
          .thenAnswer((_) async => Ok<Label, LabelFailure>(_FakeLabel()));
    });

    test('confirms and labels the payout address', () async {
      final order = _MockBuyOrder();
      when(() => order.toAddress).thenReturn('bc1qpayoutaddress');
      when(() => mainnet.confirmBuyOrder('order-1'))
          .thenAnswer((_) async => Ok(order));

      final result = await build().execute(orderId: 'order-1');

      expect(result, isA<Ok<BuyOrder, BuyFailure>>());
      verify(() => labels.store(any())).called(1);
    });

    test('labels nothing when the order has no payout address', () async {
      final order = _MockBuyOrder();
      when(() => order.toAddress).thenReturn(null);
      when(() => mainnet.confirmBuyOrder('order-1'))
          .thenAnswer((_) async => Ok(order));

      expect(
        await build().execute(orderId: 'order-1'),
        isA<Ok<BuyOrder, BuyFailure>>(),
      );
      verifyNever(() => labels.store(any()));
    });

    test('sanitizes a failure', () async {
      when(() => mainnet.confirmBuyOrder('order-1'))
          .thenAnswer((_) async => const Err(ExchangeOrderLoadFailure()));

      final result = await build().execute(orderId: 'order-1');

      switch (result) {
        case Ok():
          fail('a failed confirmation must not report a confirmed order');
        case Err(:final failure):
          expect(failure, isA<BuyUnexpectedFailure>());
      }
    });
  });

  group('AccelerateBuyOrderUsecase', () {
    AccelerateBuyOrderUsecase build() => AccelerateBuyOrderUsecase(
      exchange: exchangeForTesting(
        orders: (environment) =>
            environment == ExchangeEnvironment.testnet ? testnet : mainnet,
      ),
      settingsRepository: settingsRepository,
    );

    test('returns the accelerated order', () async {
      final order = _MockBuyOrder();
      when(() => mainnet.accelerateBuyOrder('order-1'))
          .thenAnswer((_) async => Ok(order));

      expect(
        (await build().execute('order-1') as Ok<BuyOrder, BuyFailure>).value,
        order,
      );
    });

    test('sanitizes a failure', () async {
      when(() => mainnet.accelerateBuyOrder('order-1'))
          .thenAnswer((_) async => const Err(ExchangeOrderLoadFailure()));

      final result = await build().execute('order-1');

      switch (result) {
        case Ok():
          fail('a failed acceleration must not report an order');
        case Err(:final failure):
          expect(failure, isA<BuyUnexpectedFailure>());
      }
    });
  });
}
