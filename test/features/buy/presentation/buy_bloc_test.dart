import 'dart:async';

import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/features/buy/domain/accelerate_buy_order_usecase.dart';
import 'package:bb_mobile/features/buy/domain/buy_failure.dart';
import 'package:bb_mobile/features/buy/domain/cancel_abandoned_buy_payjoin_usecase.dart';
import 'package:bb_mobile/features/buy/domain/confirm_buy_order_usecase.dart';
import 'package:bb_mobile/features/buy/domain/create_buy_order_usecase.dart';
import 'package:bb_mobile/features/buy/domain/get_buy_payjoin_enabled_usecase.dart';
import 'package:bb_mobile/features/buy/domain/load_buy_context_usecase.dart';
import 'package:bb_mobile/features/buy/domain/label_completed_buy_order_usecase.dart';
import 'package:bb_mobile/features/buy/domain/refresh_buy_order_usecase.dart';
import 'package:bb_mobile/features/buy/presentation/buy_bloc.dart';
import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockConfirmBuyOrderUsecase extends Mock
    implements ConfirmBuyOrderUsecase {}

class _MockCreateBuyOrderUsecase extends Mock
    implements CreateBuyOrderUsecase {}

class _MockRefreshBuyOrderUsecase extends Mock
    implements RefreshBuyOrderUsecase {}

class _MockAccelerateBuyOrderUsecase extends Mock
    implements AccelerateBuyOrderUsecase {}

class _MockCancelAbandonedBuyPayjoinUsecase extends Mock
    implements CancelAbandonedBuyPayjoinUsecase {}

class _MockGetBuyPayjoinEnabledUsecase extends Mock
    implements GetBuyPayjoinEnabledUsecase {}

class _MockLoadBuyContextUsecase extends Mock
    implements LoadBuyContextUsecase {}

class _SeedableBuyBloc extends BuyBloc {
  _SeedableBuyBloc({
    required super.loadBuyContextUsecase,
    required super.confirmBuyOrderUsecase,
    required super.createBuyOrderUsecase,
    required super.refreshBuyOrderUsecase,
    required super.accelerateBuyOrderUsecase,
    required super.cancelAbandonedBuyPayjoinUsecase,
    required super.getBuyPayjoinEnabledUsecase,
    required super.labelCompletedBuyOrderUsecase,
  });

  void seed(BuyState state) => emit(state);
}

class _MockBuyOrder extends Mock implements BuyOrder {}

class _MockLabelCompletedBuyOrderUsecase extends Mock
    implements LabelCompletedBuyOrderUsecase {}

void main() {
  setUpAll(() => registerFallbackValue(const FiatAmount(100)));

  group('BuyBloc — quote refresh scheduling', () {
    late _SeedableBuyBloc bloc;
    late _MockRefreshBuyOrderUsecase refresh;
    late _MockConfirmBuyOrderUsecase confirm;
    late _MockCancelAbandonedBuyPayjoinUsecase cancel;
    late _MockLabelCompletedBuyOrderUsecase labels;
    late BuyOrder order;

    setUpAll(() => registerFallbackValue(_MockBuyOrder()));

    _SeedableBuyBloc build() => _SeedableBuyBloc(
      loadBuyContextUsecase: _MockLoadBuyContextUsecase(),
      confirmBuyOrderUsecase: confirm,
      createBuyOrderUsecase: _MockCreateBuyOrderUsecase(),
      refreshBuyOrderUsecase: refresh,
      accelerateBuyOrderUsecase: _MockAccelerateBuyOrderUsecase(),
      cancelAbandonedBuyPayjoinUsecase: cancel,
      getBuyPayjoinEnabledUsecase: _MockGetBuyPayjoinEnabledUsecase(),
      labelCompletedBuyOrderUsecase: labels,
    );

    Future<Result<BuyOrder, BuyFailure>> refreshCall() =>
        refresh.execute(orderId: 'quote-order');

    setUp(() {
      refresh = _MockRefreshBuyOrderUsecase();
      confirm = _MockConfirmBuyOrderUsecase();
      cancel = _MockCancelAbandonedBuyPayjoinUsecase();
      labels = _MockLabelCompletedBuyOrderUsecase();
      order = BuyOrder(
        orderId: 'quote-order',
        orderType: OrderType.buy,
        message: OrderMessage(code: '', message: ''),
        orderNumber: 1,
        payinAmount: 100,
        payinCurrency: 'CAD',
        payoutAmount: 0.001,
        payoutCurrency: 'BTC',
        payinMethod: OrderPaymentMethod.cadBalance,
        payoutMethod: OrderPaymentMethod.bitcoin,
        orderStatus: OrderStatus.inProgress,
        payinStatus: OrderPayinStatus.awaitingPayment,
        payoutStatus: OrderPayoutStatus.notStarted,
        confirmationDeadline: DateTime.now().subtract(
          const Duration(minutes: 1),
        ),
        createdAt: DateTime.now(),
        isTestnet: true,
      );
      when(() => cancel.execute(any())).thenAnswer((_) async => const Ok(null));
      when(refreshCall).thenAnswer((_) async => Ok(order));
      when(
        () => labels.execute(order: any(named: 'order')),
      ).thenAnswer((_) async => const Ok(null));
      bloc = build();
      bloc.seed(BuyState(buyOrder: order));
    });

    tearDown(() async {
      if (!bloc.isClosed) await bloc.close();
    });

    // The scheduler's timers must be born inside the fake zone, so the bloc
    // is rebuilt there from the state the outer setUp seeded.
    Future<void> inFakeTime(void Function(FakeAsync) check) async {
      final initial = bloc.state;
      await bloc.close();
      fakeAsync((time) {
        bloc = build();
        bloc.seed(initial);
        try {
          check(time);
        } finally {
          unawaited(bloc.close());
          time.flushMicrotasks();
        }
      });
    }

    test('overlapping refresh requests send one call', () async {
      final response = Completer<Result<BuyOrder, BuyFailure>>();
      when(refreshCall).thenAnswer((_) => response.future);
      bloc.add(const BuyEvent.refreshOrder());
      bloc.add(const BuyEvent.refreshOrder());
      await pumpEventQueue();
      verify(refreshCall).called(1);
      response.complete(Ok(order));
      await pumpEventQueue();
    });

    test('a lapsed quote coming back is retried after five seconds', () {
      return inFakeTime((time) {
        bloc.add(const BuyEvent.refreshOrder());
        time.flushMicrotasks();
        verify(refreshCall).called(1);
        time.elapse(const Duration(seconds: 4));
        time.flushMicrotasks();
        verifyNever(refreshCall);
        time.elapse(const Duration(seconds: 1));
        time.flushMicrotasks();
        verify(refreshCall).called(1);
      });
    });

    test('a failed refresh has a deferred successor', () {
      when(
        refreshCall,
      ).thenAnswer((_) async => const Err(BuyUnexpectedFailure('offline')));
      return inFakeTime((time) {
        bloc.add(const BuyEvent.refreshOrder());
        time.flushMicrotasks();
        verify(refreshCall).called(1);
        time.elapse(const Duration(seconds: 5));
        time.flushMicrotasks();
        verify(refreshCall).called(1);
      });
    });

    test('a fresh lock is refreshed at its exact deadline', () {
      // The countdown widget fires up to a second early; the bloc no longer
      // listens to it and arms its own timer at the instant the lock lapses.
      return inFakeTime((time) {
        when(refreshCall).thenAnswer(
          (_) async => Ok(
            order.copyWith(
              confirmationDeadline: clock.now().add(
                const Duration(milliseconds: 500),
              ),
            ),
          ),
        );
        bloc.add(const BuyEvent.refreshOrder());
        time.flushMicrotasks();
        verify(refreshCall).called(1);
        time.elapse(const Duration(milliseconds: 499));
        time.flushMicrotasks();
        verifyNever(refreshCall);
        time.elapse(const Duration(milliseconds: 1));
        time.flushMicrotasks();
        verify(refreshCall).called(1);
      });
    });

    test('retries stop with a typed failure once the budget is spent', () {
      return inFakeTime((time) {
        bloc.add(const BuyEvent.refreshOrder());
        time.flushMicrotasks();
        // Six retries, five seconds apart, after the first lapsed answer.
        time.elapse(const Duration(seconds: 30));
        time.flushMicrotasks();
        verify(refreshCall).called(7);
        expect(bloc.state.failure, isA<BuyQuoteUnavailableFailure>());
        time.elapse(const Duration(minutes: 1));
        time.flushMicrotasks();
        verifyNever(refreshCall);
      });
    });

    test('a lapsed quote is refreshed, never confirmed', () async {
      bloc.add(const BuyEvent.confirmOrder());
      await pumpEventQueue();
      verifyNever(() => confirm.execute(orderId: 'quote-order'));
      verify(refreshCall).called(1);
      expect(bloc.state.failure, isA<BuyQuoteExpiredFailure>());
    });

    test('a quote lapsing during a failed confirmation is refreshed', () async {
      bloc.seed(
        BuyState(
          buyOrder: order.copyWith(
            confirmationDeadline: DateTime.now().add(
              const Duration(milliseconds: 50),
            ),
          ),
        ),
      );
      when(() => confirm.execute(orderId: 'quote-order')).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return const Err(BuyUnexpectedFailure('confirmation failed'));
      });
      bloc.add(const BuyEvent.confirmOrder());
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await pumpEventQueue();
      verify(() => confirm.execute(orderId: 'quote-order')).called(1);
      verify(refreshCall).called(1);
    });

    test('a failed confirmation leaves a live lock to its deadline', () async {
      bloc.seed(
        BuyState(
          buyOrder: order.copyWith(
            confirmationDeadline: DateTime.now().add(
              const Duration(minutes: 5),
            ),
          ),
        ),
      );
      when(() => confirm.execute(orderId: 'quote-order')).thenAnswer(
        (_) async => const Err(BuyUnexpectedFailure('confirmation failed')),
      );
      bloc.add(const BuyEvent.confirmOrder());
      await pumpEventQueue();
      verifyNever(refreshCall);
    });

    test('a confirmed order is not refreshed for its lapsed quote', () {
      // Confirmed while the lock was live; later reads carry a lapsed one.
      bloc.seed(
        BuyState(
          buyOrder: order.copyWith(
            confirmationDeadline: DateTime.now().add(
              const Duration(minutes: 5),
            ),
          ),
        ),
      );
      when(
        () => confirm.execute(orderId: 'quote-order'),
      ).thenAnswer((_) async => Ok(order));
      return inFakeTime((time) {
        bloc.add(const BuyEvent.confirmOrder());
        time.flushMicrotasks();
        // A successful confirmation need not report payin completed yet.
        expect(bloc.state.buyOrder?.isPayinCompleted, isFalse);
        // The success screen still polls the order.
        bloc.add(const BuyEvent.refreshOrder());
        time.flushMicrotasks();
        verify(refreshCall).called(1);
        time.elapse(const Duration(seconds: 10));
        time.flushMicrotasks();
        verifyNever(refreshCall);
      });
    });

    test('an expired order read without a confirmation is not refreshed', () {
      // The accelerate route builds a fresh bloc and only reads the order.
      when(refreshCall).thenAnswer(
        (_) async => Ok(order.copyWith(orderStatus: OrderStatus.expired)),
      );
      return inFakeTime((time) {
        bloc.seed(const BuyState());
        bloc.add(const BuyEvent.refreshOrder(orderId: 'quote-order'));
        time.flushMicrotasks();
        verify(refreshCall).called(1);
        time.elapse(const Duration(seconds: 10));
        time.flushMicrotasks();
        verifyNever(refreshCall);
      });
    });

    test('a failed read after confirmation schedules no refresh', () {
      bloc.seed(
        BuyState(
          buyOrder: order.copyWith(
            confirmationDeadline: DateTime.now().add(
              const Duration(minutes: 5),
            ),
          ),
        ),
      );
      when(
        () => confirm.execute(orderId: 'quote-order'),
      ).thenAnswer((_) async => Ok(order));
      when(
        refreshCall,
      ).thenAnswer((_) async => const Err(BuyUnexpectedFailure('offline')));
      return inFakeTime((time) {
        bloc.add(const BuyEvent.confirmOrder());
        time.flushMicrotasks();
        // The success screen reads the order and the read fails.
        bloc.add(const BuyEvent.refreshOrder());
        time.flushMicrotasks();
        verify(refreshCall).called(1);
        time.elapse(const Duration(minutes: 1));
        time.flushMicrotasks();
        verifyNever(refreshCall);
      });
    });

    test('a failed read of an order not on screen schedules no refresh', () {
      // The accelerate route builds a fresh bloc and reads the order by id.
      when(
        refreshCall,
      ).thenAnswer((_) async => const Err(BuyUnexpectedFailure('offline')));
      return inFakeTime((time) {
        bloc.seed(const BuyState());
        bloc.add(const BuyEvent.refreshOrder(orderId: 'quote-order'));
        time.flushMicrotasks();
        verify(refreshCall).called(1);
        time.elapse(const Duration(minutes: 1));
        time.flushMicrotasks();
        verifyNever(refreshCall);
        expect(bloc.state.failure, isNot(isA<BuyQuoteUnavailableFailure>()));
      });
    });

    test('abandoning the order cancels the pending retry', () {
      return inFakeTime((time) {
        bloc.add(const BuyEvent.refreshOrder());
        time.flushMicrotasks();
        verify(refreshCall).called(1);
        bloc.add(const BuyEvent.orderCreationAbandoned());
        time.flushMicrotasks();
        time.elapse(const Duration(seconds: 10));
        time.flushMicrotasks();
        verifyNever(refreshCall);
      });
    });
  });

  group('BuyBloc without a price', () {
    late _SeedableBuyBloc bloc;
    late _MockLoadBuyContextUsecase load;

    setUp(() {
      load = _MockLoadBuyContextUsecase();
      final cancel = _MockCancelAbandonedBuyPayjoinUsecase();
      when(
        () => cancel.execute(any()),
      ).thenAnswer((_) async => const Ok<void, BuyFailure>(null));
      bloc = _SeedableBuyBloc(
        loadBuyContextUsecase: load,
        confirmBuyOrderUsecase: _MockConfirmBuyOrderUsecase(),
        createBuyOrderUsecase: _MockCreateBuyOrderUsecase(),
        refreshBuyOrderUsecase: _MockRefreshBuyOrderUsecase(),
        accelerateBuyOrderUsecase: _MockAccelerateBuyOrderUsecase(),
        cancelAbandonedBuyPayjoinUsecase: cancel,
        getBuyPayjoinEnabledUsecase: _MockGetBuyPayjoinEnabledUsecase(),
        labelCompletedBuyOrderUsecase: _MockLabelCompletedBuyOrderUsecase(),
      );
    });
    tearDown(() async {
      if (!bloc.isClosed) await bloc.close();
    });

    test('a currency whose price does not come says so', () async {
      bloc.seed(const BuyState(currencyInput: 'USD', exchangeRate: 70000));
      // The datasource reports an unreachable pricer as a zero rate.
      when(
        () => load.satsToCurrency(currencyCode: 'CAD'),
      ).thenAnswer((_) async => const Ok<double, BuyFailure>(0));

      bloc.add(const BuyEvent.currencyInputChanged('CAD'));
      await pumpEventQueue();

      expect(bloc.state.failure, isA<BuyQuoteUnavailableFailure>());
      expect(bloc.state.exchangeRate, 0);
    });

    test('a failed price read does not keep the previous currency rate', () {
      bloc.seed(const BuyState(currencyInput: 'USD', exchangeRate: 70000));
      when(() => load.satsToCurrency(currencyCode: 'CAD')).thenAnswer(
        (_) async => const Err<double, BuyFailure>(BuyUnexpectedFailure('x')),
      );

      bloc.add(const BuyEvent.currencyInputChanged('CAD'));
      return pumpEventQueue().then((_) {
        // 70000 is the USD price: it must not price a CAD amount.
        expect(bloc.state.exchangeRate, 0);
        expect(bloc.state.failure, isNotNull);
      });
    });
  });

  group('order preparation', () {
    late _SeedableBuyBloc bloc;
    late _MockCreateBuyOrderUsecase create;
    late _MockCancelAbandonedBuyPayjoinUsecase cancel;
    late _MockLoadBuyContextUsecase load;

    Future<Result<BuyOrder, BuyFailure>> createCall() => create.execute(
      toAddress: 'tb1qtest',
      orderAmount: any(named: 'orderAmount'),
      currency: FiatCurrency.cad,
      isLiquid: false,
      isOwner: true,
      payjoinWalletId: null,
      payjoinAmountSat: null,
    );

    setUp(() {
      create = _MockCreateBuyOrderUsecase();
      cancel = _MockCancelAbandonedBuyPayjoinUsecase();
      load = _MockLoadBuyContextUsecase();
      when(
        () => cancel.execute(any()),
      ).thenAnswer((_) async => const Ok<void, BuyFailure>(null));
      when(
        () => load.satsToCurrency(currencyCode: 'CAD'),
      ).thenAnswer((_) async => const Ok<double, BuyFailure>(100000));
      bloc = _SeedableBuyBloc(
        loadBuyContextUsecase: load,
        confirmBuyOrderUsecase: _MockConfirmBuyOrderUsecase(),
        createBuyOrderUsecase: create,
        refreshBuyOrderUsecase: _MockRefreshBuyOrderUsecase(),
        accelerateBuyOrderUsecase: _MockAccelerateBuyOrderUsecase(),
        cancelAbandonedBuyPayjoinUsecase: cancel,
        getBuyPayjoinEnabledUsecase: _MockGetBuyPayjoinEnabledUsecase(),
        labelCompletedBuyOrderUsecase: _MockLabelCompletedBuyOrderUsecase(),
      );
      bloc.seed(
        const BuyState(
          amountInput: '100',
          currencyInput: 'CAD',
          exchangeRate: 100000,
          bitcoinAddressInput: 'tb1qtest',
        ),
      );
    });
    tearDown(() async {
      if (!bloc.isClosed) await bloc.close();
    });

    test(
      'starts loading before cleanup and keeps the submitted input snapshot',
      () async {
        final cleanup = Completer<Result<void, BuyFailure>>();
        when(() => cancel.execute(null)).thenAnswer((_) => cleanup.future);
        final response = Completer<Result<BuyOrder, BuyFailure>>();
        when(createCall).thenAnswer((_) => response.future);
        final loading = bloc.stream.firstWhere((s) => s.isCreatingOrder);
        bloc.add(const BuyEvent.createOrder());
        await loading;
        verifyNever(createCall);
        bloc.add(const BuyEvent.amountInputChanged('200'));
        await Future<void>.delayed(Duration.zero);
        cleanup.complete(const Ok(null));
        await untilCalled(createCall);
        final amount =
            verify(
                  () => create.execute(
                    toAddress: 'tb1qtest',
                    orderAmount: captureAny(named: 'orderAmount'),
                    currency: FiatCurrency.cad,
                    isLiquid: false,
                    isOwner: true,
                    payjoinWalletId: null,
                    payjoinAmountSat: null,
                  ),
                ).captured.single
                as FiatAmount;
        expect(amount.amount, 100);
        final ready = bloc.stream.firstWhere(
          (s) => s.buyOrder != null && !s.isCreatingOrder,
        );
        response.complete(Ok(_MockBuyOrder()));
        await ready;
      },
    );

    test(
      'ignores a second create event while the API response is pending',
      () async {
        final response = Completer<Result<BuyOrder, BuyFailure>>();
        when(createCall).thenAnswer((_) => response.future);
        bloc.add(const BuyEvent.createOrder());
        await untilCalled(createCall);
        bloc.add(const BuyEvent.createOrder());
        await Future<void>.delayed(Duration.zero);
        verify(createCall).called(1);
        final ready = bloc.stream.firstWhere(
          (s) => s.buyOrder != null && !s.isCreatingOrder,
        );
        response.complete(Ok(_MockBuyOrder()));
        await ready;
      },
    );

    test(
      'creation failure is visible on confirmation without an order',
      () async {
        const failure = BuyUnexpectedFailure('internal diagnostic');
        when(createCall).thenAnswer((_) async => const Err(failure));
        final failed = bloc.stream.firstWhere(
          (s) => s.failure != null && !s.isCreatingOrder,
        );
        bloc.add(const BuyEvent.createOrder());
        final state = await failed;
        expect(state.buyOrder, isNull);
        expect(state.confirmFailure, failure);
      },
    );

    test(
      'back and a new attempt discard the old response and clean its receiver',
      () async {
        final first = Completer<Result<BuyOrder, BuyFailure>>();
        final second = Completer<Result<BuyOrder, BuyFailure>>();
        var calls = 0;
        when(
          createCall,
        ).thenAnswer((_) => ++calls == 1 ? first.future : second.future);
        bloc.add(const BuyEvent.createOrder());
        await untilCalled(createCall);
        final abandoned = bloc.stream.firstWhere((s) => !s.isCreatingOrder);
        bloc.add(const BuyEvent.orderCreationAbandoned());
        await abandoned;
        bloc.add(const BuyEvent.createOrder());
        await untilCalled(createCall);
        final newOrder = _MockBuyOrder();
        final ready = bloc.stream.firstWhere(
          (s) => identical(s.buyOrder, newOrder) && !s.isCreatingOrder,
        );
        second.complete(Ok(newOrder));
        await ready;
        final oldOrder = _MockBuyOrder();
        first.complete(Ok(oldOrder));
        await untilCalled(() => cancel.execute(oldOrder));
        expect(bloc.state.buyOrder, same(newOrder));
        expect(bloc.state.isCreatingOrder, isFalse);
      },
    );

    test(
      'closing during creation cleans a late order without publishing it',
      () async {
        final response = Completer<Result<BuyOrder, BuyFailure>>();
        when(createCall).thenAnswer((_) => response.future);
        bloc.add(const BuyEvent.createOrder());
        await untilCalled(createCall);
        final closing = bloc.close();
        final order = _MockBuyOrder();
        response.complete(Ok(order));
        await closing;
        await untilCalled(() => cancel.execute(order));
        expect(bloc.state.buyOrder, isNull);
      },
    );
  });

  test(
    'closing the Buy flow cleans up its current unconfirmed order',
    () async {
      final cancelAbandonedPayjoin = _MockCancelAbandonedBuyPayjoinUsecase();
      final order = _MockBuyOrder();
      when(
        () => cancelAbandonedPayjoin.execute(order),
      ).thenAnswer((_) async => const Ok<void, BuyFailure>(null));
      final bloc = _SeedableBuyBloc(
        loadBuyContextUsecase: _MockLoadBuyContextUsecase(),
        confirmBuyOrderUsecase: _MockConfirmBuyOrderUsecase(),
        createBuyOrderUsecase: _MockCreateBuyOrderUsecase(),
        refreshBuyOrderUsecase: _MockRefreshBuyOrderUsecase(),
        accelerateBuyOrderUsecase: _MockAccelerateBuyOrderUsecase(),
        cancelAbandonedBuyPayjoinUsecase: cancelAbandonedPayjoin,
        getBuyPayjoinEnabledUsecase: _MockGetBuyPayjoinEnabledUsecase(),
        labelCompletedBuyOrderUsecase: _MockLabelCompletedBuyOrderUsecase(),
      );
      bloc.seed(BuyState(buyOrder: order));

      await bloc.close();

      verify(() => cancelAbandonedPayjoin.execute(order)).called(1);
    },
  );
}
