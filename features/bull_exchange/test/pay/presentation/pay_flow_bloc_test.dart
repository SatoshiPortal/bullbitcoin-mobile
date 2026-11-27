import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fees/fees.dart';
import 'package:bull_exchange/src/pay/domain/pay_state.dart';
import 'package:bull_exchange/src/pay/domain/pay_event.dart';
import 'package:bull_exchange/src/pay/presentation/pay_flow_bloc.dart';
import 'package:bull_exchange/src/payin/payin_runner.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../orders/order_usecase_fakes.dart';
import '../../payin/payin_usecase_fakes.dart';
import '../../payout/payout_requirements_fakes.dart';
import '../pay_fixtures.dart';
import '../pay_usecase_fakes.dart';

import 'package:primitives/primitives.dart';

/// The pay use cases as fakes; every call is logged with the session it
/// got.
final class _Usecases {
  final log = <String>[];
  final sessions = <ExchangeSession>{};

  /// The order the create answers with.
  final FiatPaymentOrder? created;

  /// The payin use cases; by default the build fails for lack of funds.
  final PayinUsecases Function(List<String> log)? payin;

  _Usecases({this.created, this.payin});

  void _called(ExchangeSession session, String call) {
    sessions.add(session);
    log.add(call);
  }

  PayFlowBloc bloc({
    required ExchangeSession? session,
    required Stream<ExchangeAccess> accessChanges,
  }) => PayFlowBloc(
    session: session,
    accessChanges: accessChanges,
    loadContext: FakeLoadPayContextUsecase((session) async {
      _called(session, 'load');
      return Ok(payContext);
    }),
    getMarketRate: FakeGetMarketRateUsecase((_, market) async {
      log.add('rate ${market.currency.code}');
      return const Ok(50000.0);
    }),
    createOrder: FakeCreatePayOrderUsecase((session, effect) async {
      _called(session, 'create ${effect.attempt}');
      return OrderCreateAnswered(
        effect.attempt,
        Ok<Order, ExchangeWriteFailure>(created ?? payOrder()),
      );
    }),
    findCreatedOrder: FakeFindCreatedOrderUsecase((
      session,
      journal,
      sentAt,
    ) async {
      _called(session, 'find');
      return const Err(ExchangeMissingFailure());
    }),
    refreshOrder: FakeRefreshPayOrderUsecase((session, orderId) async {
      _called(session, 'refresh $orderId');
      return Ok<Order, ExchangeReadFailure>(payOrder());
    }),
    getOrder: FakeGetOrderUsecase((session, orderId) async {
      _called(session, 'read $orderId');
      return Ok<Order, ExchangeReadFailure>(payOrder());
    }),
    requirements: unusedPayoutRequirements(),
    payin:
        payin?.call(log) ??
        fakePayin(
          build: FakeBuildPayinUsecase((effect) async {
            log.add('build ${effect.walletId}');
            return const Err(
              ExchangePayinBuildFailure(PayinBuildProblem.insufficientFunds),
            );
          }),
          getOrder: FakeGetOrderUsecase(
            (session, orderId) async =>
                Ok<Order, ExchangeReadFailure>(payOrder()),
          ),
        ),
    spendOptions: fakeSpendOptions(
      getFees: FakeGetFeeOptionsUsecase((session) async {
        _called(session, 'fees');
        return payFees;
      }),
      getCoins: FakeGetWalletCoinsUsecase((walletId) async => const []),
      previewPresets: FakePreviewFeePresetsUsecase(
        (shape, fees) async => const {},
      ),
      previewCustom: FakePreviewCustomFeeUsecase(
        (shape, fee) async => const BitcoinFeePreviewSlot(),
      ),
    ),
  );
}

Future<void> _settle() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test(
    'creates once, then Confirm builds the payin from the wallet',
    () => withClock(Clock.fixed(payNow), () async {
      final calls = _Usecases();
      final bloc = calls.bloc(
        session: paySession,
        accessChanges: const Stream.empty(),
      );
      addTearDown(bloc.close);
      await _settle();
      bloc.add(PayRecipientPicked(payBankRecipient));
      // The rate is read once the recipient fixes the currency.
      await _settle();
      for (final event in const [
        PayAmountChanged(AmountTyped('10')),
        PayAmountChanged(AmountContinuePressed()),
        PaySourcePicked(payAppWallet),
      ]) {
        bloc.add(event);
      }
      await _settle();
      expect(
        (bloc.state as PayOrdering).order,
        isA<OrderQuoted<PayRequest, Order>>(),
      );
      bloc
        ..add(PayConfirmPressed(payNow))
        ..add(PayConfirmPressed(payNow));
      await _settle();
      expect(calls.log, ['load', 'rate CAD', 'create 1', 'fees', 'build w-1']);
      expect(calls.sessions, {paySession});
      expect(
        (bloc.state as PayPaying).payin,
        isA<PayinSendFailed<PayinSpend>>(),
      );
    }),
  );

  test('a SINPE payout watches for the receipt with the flow session', () {
    fakeAsync((async) {
      withClock(Clock.fixed(payNow), () {
        final sinpe = payOrder(payoutMethod: OrderPaymentMethod.sinpe);
        final seen = payOrder(
          payinStatus: OrderPayinStatus.underReview,
          payoutMethod: OrderPaymentMethod.sinpe,
        );
        final calls = _Usecases(
          created: sinpe,
          payin: (log) => fakePayin(
            build: FakeBuildPayinUsecase(
              (effect) async => Ok(
                PayinBuilt(
                  effect.spend,
                  'tx-1',
                  const SignedBitcoinPayin<String>('signed'),
                ),
              ),
            ),
            send: FakeSendPayinUsecase(
              (session, effect) async => PayinSendAnswered(
                effect.attempt,
                const Ok(PayinBroadcastAccepted('tx-1')),
              ),
            ),
            getOrder: FakeGetOrderUsecase((session, orderId) async {
              log.add('payin read $orderId');
              return Ok<Order, ExchangeReadFailure>(seen);
            }),
          ),
        );
        final bloc = calls.bloc(
          session: paySession,
          accessChanges: const Stream.empty(),
        );
        async.flushMicrotasks();
        bloc.add(PayRecipientPicked(payBankRecipient));
        async.flushMicrotasks();
        for (final event in const [
          PayAmountChanged(AmountTyped('10')),
          PayAmountChanged(AmountContinuePressed()),
          PaySourcePicked(payAppWallet),
        ]) {
          bloc.add(event);
        }
        async.flushMicrotasks();
        bloc.add(PayConfirmPressed(payNow));
        async
          ..flushMicrotasks()
          ..elapse(const Duration(minutes: 2));
        expect(bloc.state, isA<PayDone>());
        expect(calls.log, contains('payin read ${sinpe.orderId}'));
        expect(calls.log, contains('read ${sinpe.orderId}'));
        expect(calls.sessions, {paySession});
        unawaited(bloc.close());
        async.flushMicrotasks();
      });
    });
  });
}
