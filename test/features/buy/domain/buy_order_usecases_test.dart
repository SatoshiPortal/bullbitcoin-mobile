import 'package:bull_exchange/testing.dart';
import 'package:exchange/testing.dart';
import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockExchangeOrders extends Mock implements ExchangeOrders {}

class _MockSettingsRepository extends Mock implements Preferences {}

class _MockSettings extends Mock implements SettingsEntity {}

class _MockBuyOrder extends Mock implements BuyOrder {}

/// A reason of the shape the exchange API produces, quoting a key.

void main() {
  late _MockExchangeOrders mainnet;
  late _MockExchangeOrders testnet;
  late _MockSettingsRepository settingsRepository;

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
    ConfirmBuyOrderUsecase build() => ConfirmBuyOrderUsecase(
      exchange: exchangeForTesting(
        orders: (environment) =>
            environment == ExchangeEnvironment.testnet ? testnet : mainnet,
      ),
      settingsRepository: settingsRepository,
    );

    test('confirms without reading an unverified payout address', () async {
      final order = _MockBuyOrder();
      when(() => order.toAddress).thenReturn('bc1qpayoutaddress');
      when(() => mainnet.confirmBuyOrder('order-1'))
          .thenAnswer((_) async => WriteDone(order));

      final result = await build().execute(orderId: 'order-1');

      expect(result, isA<Ok<BuyOrder, BuyFailure>>());
      verifyNever(() => order.toAddress);
    });

    test('a refusal is a plain failure without a re-read', () async {
      when(() => mainnet.confirmBuyOrder('order-1')).thenAnswer(
        (_) async => const WriteRefused(ExchangeRefusal(rpcCode: -1)),
      );

      final result = await build().execute(orderId: 'order-1');

      switch (result) {
        case Ok():
          fail('a failed confirmation must not report a confirmed order');
        case Err(:final failure):
          expect(failure, isA<BuyUnexpectedFailure>());
      }
      verifyNever(() => mainnet.getOrder(any()));
    });

    test('a rejected session is unauthenticated', () async {
      when(() => mainnet.confirmBuyOrder('order-1'))
          .thenAnswer((_) async => const WriteSessionRejected());

      expect(
        await build().execute(orderId: 'order-1'),
        isA<Err<BuyOrder, BuyFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<BuyUnauthenticatedFailure>(),
        ),
      );
    });

    group('an unknown outcome re-reads the order (INT-12, BUY-4)', () {
      setUp(() {
        when(
          () => mainnet.confirmBuyOrder('order-1'),
        ).thenAnswer((_) async => const WriteOutcomeUnknown('receive timeout'));
      });

      void reread(OrderStatus status) {
        final order = _MockBuyOrder();
        when(() => order.orderStatus).thenReturn(status);
        when(() => mainnet.getOrder('order-1'))
            .thenAnswer((_) async => Ok(order));
      }

      for (final status in [OrderStatus.inProgress, OrderStatus.completed]) {
        test('a ${status.name} order was confirmed', () async {
          reread(status);
          expect(
            await build().execute(orderId: 'order-1'),
            isA<Ok<BuyOrder, BuyFailure>>(),
          );
        });
      }

      for (final status in [
        OrderStatus.awaitingConfirmation,
        OrderStatus.canceled,
        OrderStatus.expired,
        OrderStatus.orderExpired,
        OrderStatus.rejected,
        OrderStatus.failed,
      ]) {
        test('a ${status.name} order was not confirmed', () async {
          reread(status);
          expect(
            await build().execute(orderId: 'order-1'),
            isA<Err<BuyOrder, BuyFailure>>().having(
              (r) => r.failure,
              'failure',
              isA<BuyUnexpectedFailure>(),
            ),
          );
        });
      }

      test('an unknown status keeps the outcome unknown', () async {
        reread(OrderStatus.unknown);
        expect(
          await build().execute(orderId: 'order-1'),
          isA<Err<BuyOrder, BuyFailure>>().having(
            (r) => r.failure,
            'failure',
            isA<BuyConfirmOutcomeUnknownFailure>(),
          ),
        );
      });

      test('a failed re-read keeps the outcome unknown', () async {
        when(() => mainnet.getOrder('order-1'))
            .thenAnswer((_) async => const Err(ExchangeNetworkFailure()));
        expect(
          await build().execute(orderId: 'order-1'),
          isA<Err<BuyOrder, BuyFailure>>().having(
            (r) => r.failure,
            'failure',
            isA<BuyConfirmOutcomeUnknownFailure>(),
          ),
        );
        verify(() => mainnet.confirmBuyOrder('order-1')).called(1);
      });
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
          .thenAnswer((_) async => WriteDone(order));

      expect(
        (await build().execute('order-1') as Ok<BuyOrder, BuyFailure>).value,
        order,
      );
    });

    test('sanitizes a refusal', () async {
      when(() => mainnet.accelerateBuyOrder('order-1')).thenAnswer(
        (_) async => const WriteRefused(ExchangeRefusal(rpcCode: -1)),
      );

      final result = await build().execute('order-1');

      switch (result) {
        case Ok():
          fail('a failed acceleration must not report an order');
        case Err(:final failure):
          expect(failure, isA<BuyUnexpectedFailure>());
      }
    });

    test('an unknown outcome is never sent again (INT-12)', () async {
      when(
        () => mainnet.accelerateBuyOrder('order-1'),
      ).thenAnswer((_) async => const WriteOutcomeUnknown('receive timeout'));

      expect(
        await build().execute('order-1'),
        isA<Err<BuyOrder, BuyFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<BuyAccelerateOutcomeUnknownFailure>(),
        ),
      );
    });
  });
}
