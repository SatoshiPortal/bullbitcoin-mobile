import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/features/buy/domain/buy_failure.dart';
import 'package:bb_mobile/features/buy/domain/get_buy_payjoin_enabled_usecase.dart';
import 'package:bb_mobile/features/buy/domain/label_completed_buy_order_usecase.dart';
import 'package:bb_mobile/features/transactions/transactions_facade.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockTransactionsFacade extends Mock implements TransactionsFacade {}

class _MockPayjoinPolicy extends Mock implements PayjoinPolicyAccess {}

class _MockOrder extends Mock implements BuyOrder {}

void main() {
  group('LabelCompletedBuyOrderUsecase', () {
    late _MockTransactionsFacade facade;
    late LabelCompletedBuyOrderUsecase usecase;

    setUp(() {
      facade = _MockTransactionsFacade();
      usecase = LabelCompletedBuyOrderUsecase(transactionsFacade: facade);
    });

    _MockOrder orderWith(OrderStatus status) {
      final order = _MockOrder();
      when(() => order.orderStatus).thenReturn(status);
      return order;
    }

    test('labels a completed order', () async {
      final order = orderWith(OrderStatus.completed);
      when(
        () => facade.labelCompletedExchangeOrders(any()),
      ).thenAnswer((_) async {});

      expect(await usecase.execute(order: order), isA<Ok<void, BuyFailure>>());
      verify(() => facade.labelCompletedExchangeOrders([order])).called(1);
    });

    // #2624: privileged exchange labels must never be written for anything but
    // an explicit completion.
    test('writes nothing for an order that has not completed', () async {
      for (final status in [
        OrderStatus.inProgress,
        OrderStatus.awaitingConfirmation,
        OrderStatus.expired,
        OrderStatus.failed,
      ]) {
        expect(
          await usecase.execute(order: orderWith(status)),
          isA<Ok<void, BuyFailure>>(),
        );
      }

      verifyNever(() => facade.labelCompletedExchangeOrders(any()));
    });

    test('a labelling failure is a sanitized value, not a throw', () async {
      final order = orderWith(OrderStatus.completed);
      when(
        () => facade.labelCompletedExchangeOrders(any()),
      ).thenThrow(Exception('label store unavailable: db path /secret'));

      final result = await usecase.execute(order: order);

      switch (result) {
        case Ok():
          fail('a labelling failure must be visible to the caller');
        case Err(:final failure):
          // Cosmetic: the caller drops this so a completed order still shows
          // as completed. It must not escape as an exception and break that.
          expect(failure, isA<BuyUnexpectedFailure>());
          expect(failure.logMessage, contains('label store unavailable'));
      }
    });
  });

  group('GetBuyPayjoinEnabledUsecase', () {
    test('reports the configured value', () async {
      final policy = _MockPayjoinPolicy();
      final value = PayjoinPolicy(
        enabled: true,
        minimumAmount: Sats.fromInt(1000),
        sessionLifetime: const Duration(hours: 1),
      );
      when(
        policy.load,
      ).thenAnswer((_) async => Ok<PayjoinPolicy, PayjoinFailure>(value));

      final result = await GetBuyPayjoinEnabledUsecase(policy).execute();

      expect((result as Ok<bool, BuyFailure>).value, isTrue);
    });

    test(
      'an unreadable policy is a sanitized failure, not a bare false',
      () async {
        final policy = _MockPayjoinPolicy();
        when(policy.load).thenAnswer(
          (_) async =>
              const Err<PayjoinPolicy, PayjoinFailure>(PayjoinStorageFailure()),
        );

        final result = await GetBuyPayjoinEnabledUsecase(policy).execute();

        switch (result) {
          case Ok():
            fail('an unreadable policy must not be reported as a real answer');
          case Err(:final failure):
            // The caller decides what "unknown" means for its screen; no
            // PayjoinFailure escapes into the buy feature.
            expect(failure, isA<BuyUnexpectedFailure>());
            expect(failure, isNot(isA<PayjoinFailure>()));
        }
      },
    );
  });
}
