import 'package:bull_exchange/src/payin/spend_options.dart';
import 'package:fees/fees.dart';
import 'package:bull_exchange/src/pay/presentation/pay_flow.dart';
import 'package:bull_exchange/src/payin/payin_runner.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_test/flutter_test.dart';

import '../pay_fixtures.dart';

final _states = <String, PayFlowState>{
  'loading': payLoadingState,
  'recipient': payRecipientState,
  'requirements': payRequirementsState,
  'amount': payAmountState,
  'source': paySourceState,
  'ordering': payOrderingState,
  'review': payReviewState,
  'paying': payPayingState,
  'done': payDoneState,
  'receipt': payReceiptState,
  'sessionEnded': const PaySessionEnded(),
  'closed': const PayClosed(),
};

final _events = <String, PayFlowEvent>{
  'contextLoaded': PayContextLoaded(1, ReadGot(payContext)),
  'retry': const PayRetryPressed(),
  'picked': PayRecipientPicked(payBankRecipient),
  'requirements': const PayRequirementsChanged(
    RequirementInteracEvent(InteracQuestionTyped('Colour?')),
  ),
  'amount': const PayAmountChanged(AmountTyped('5')),
  'kycReturned': const PayKycReturned(),
  'detourLoaded': PayDetourLoaded(ReadGot(payContext)),
  'source': const PaySourcePicked(payAppWallet),
  'order': PayOrderChanged(
    OrderCreateAnswered(1, GateAdmitted(WriteDone<Order>(payOrder()))),
  ),
  'confirm': PayConfirmPressed(payNow),
  'spendFees': const PaySpendChanged(SpendFeesLoaded(1, payFees)),
  'spendRbf': const PaySpendChanged(SpendRbfChanged(enabled: false)),
  'payin': PayPayinChanged(
    PayinBuildAnswered<PayinSpend>(
      1,
      const PayinBuildFailed(PayinBuildProblem.insufficientFunds),
      payNow,
    ),
  ),
  'receipt': PayReceiptChanged(
    WatchPolled(
      'p-1',
      1,
      ReadGot<Order>(
        payOrder(
          payinStatus: OrderPayinStatus.inProgress,
          payoutStatus: OrderPayoutStatus.completed,
          payoutMethod: OrderPaymentMethod.sinpe,
        ),
      ),
    ),
  ),
  'back': const PayBackPressed(),
  'donePressed': const PayDonePressed(),
  'visibility': const PayVisibilityChanged(visible: false),
  'session': const PaySessionChanged(payOtherSession),
};

const _moves = <(String, String), Type>{
  ('loading', 'contextLoaded'): PayRecipient,
  ('loading', 'back'): PayClosed,
  ('loading', 'donePressed'): PayClosed,
  ('loading', 'session'): PaySessionEnded,
  ('recipient', 'picked'): PayAmount,
  ('recipient', 'back'): PayClosed,
  ('recipient', 'session'): PaySessionEnded,
  ('requirements', 'requirements'): PayRequirements,
  ('requirements', 'back'): PayRecipient,
  ('requirements', 'session'): PaySessionEnded,
  ('amount', 'amount'): PayAmount,
  ('amount', 'back'): PayRecipient,
  ('amount', 'session'): PaySessionEnded,
  ('source', 'source'): PayOrdering,
  ('source', 'back'): PayAmount,
  ('source', 'session'): PaySessionEnded,
  ('ordering', 'order'): PayOrdering,
  ('ordering', 'spendFees'): PayOrdering,
  ('ordering', 'session'): PaySessionEnded,
  ('review', 'confirm'): PayPaying,
  ('review', 'spendRbf'): PayOrdering,
  ('review', 'back'): PaySource,
  ('review', 'session'): PaySessionEnded,
  ('paying', 'payin'): PayPaying,
  ('paying', 'back'): PayOrdering,
  ('paying', 'session'): PaySessionEnded,
  ('done', 'back'): PayClosed,
  ('done', 'donePressed'): PayClosed,
  ('done', 'session'): PaySessionEnded,
  ('receipt', 'receipt'): PayDone,
  ('receipt', 'visibility'): PayDone,
  ('receipt', 'back'): PayClosed,
  ('receipt', 'donePressed'): PayClosed,
  ('receipt', 'session'): PaySessionEnded,
  ('sessionEnded', 'back'): PayClosed,
  ('sessionEnded', 'donePressed'): PayClosed,
};

void main() {
  test('the sample states are the ones they name', () {
    expect(payRecipientState, isA<PayRecipient>());
    expect(payRequirementsState, isA<PayRequirements>());
    expect(
      (payAmountState as PayAmount).amount,
      isA<AmountEditing>().having((s) => s.quote, 'quote', isA<RateReady>()),
    );
    expect(paySourceState, isA<PaySource>());
    expect(
      (payOrderingState as PayOrdering).order,
      isA<OrderCreating<PayRequest, Order>>(),
    );
    expect(
      (payReviewState as PayOrdering).order,
      isA<OrderQuoted<PayRequest, Order>>(),
    );
    expect(
      (payPayingState as PayPaying).payin,
      isA<PayinBuilding<PayinSpend>>(),
    );
  });

  group('every (state, event) pair', () {
    for (final MapEntry(key: stateName, value: state) in _states.entries) {
      for (final MapEntry(key: eventName, value: event) in _events.entries) {
        final expected = _moves[(stateName, eventName)];
        test('$stateName + $eventName', () {
          final next = transitionPayFlow(state, event);
          if (expected == null) {
            expect(identical(next.state, state), isTrue, reason: '$next');
            expect(next.effects, isEmpty);
          } else {
            expect(next.state.runtimeType, expected);
            expect(identical(next.state, state), isFalse);
          }
        });
      }
    }
  });

  test('every state is reachable', () {
    final reached = <Type>{payFlowStart(paySession).state.runtimeType};
    for (final state in _states.values) {
      reached.add(state.runtimeType);
      for (final event in _events.values) {
        reached.add(transitionPayFlow(state, event).state.runtimeType);
      }
    }
    expect(reached, {
      PayLoading,
      PayRecipient,
      PayRequirements,
      PayAmount,
      PaySource,
      PayOrdering,
      PayPaying,
      PayDone,
      PaySessionEnded,
      PayClosed,
    });
  });

  test('the order carries the recipient and the Interac answer', () {
    final ordering = payOrderingState as PayOrdering;
    expect(ordering.request.payout.recipientId, 'r-bank');
    expect(ordering.request.journal.type, OrderType.fiatPayment);
    expect(ordering.request.amount.market, ExchangeCatalog.cad);
  });

  test('the amount is fixed to the recipient\'s currency', () {
    final amount = payAmountState as PayAmount;
    expect(
      amount.policy.currencySource,
      isA<CurrencyFixed>().having(
        (c) => c.market,
        'market',
        ExchangeCatalog.cad,
      ),
    );
    expect(amount.policy.withDescription, isTrue);
  });

  test('an unknown create re-reads; Retry never resends', () {
    final next = transitionPayFlow(
      payOrderingState,
      const PayOrderChanged(
        OrderCreateAnswered(1, GateAdmitted(WriteOutcomeUnknown('lost'))),
      ),
    );
    expect(
      (next.state as PayOrdering).order,
      isA<OrderVerifying<PayRequest, Order>>(),
    );
    final again = transitionPayFlow(next.state, const PayRetryPressed());
    expect(identical(again.state, next.state), isTrue);
  });

  test('a SINPE payin seen by the exchange watches for the receipt', () {
    final paying = payPayingState as PayPaying;
    final sinpe = payOrder(payoutMethod: OrderPaymentMethod.sinpe);
    final watching = PayPaying(
      paying.open,
      paying.request,
      paying.quoted,
      PayinWatching<PayinSpend>(
        sinpe,
        const OnchainDeposit('bc1qdeposit'),
        'tx-1',
        WatchWatching<Order>(sinpe, 0, 0, 1),
      ),
      paying.spend,
    );
    final next = transitionPayFlow(
      watching,
      PayPayinChanged(
        PayinWatchEvent(
          WatchPolled(
            'p-1',
            1,
            ReadGot<Order>(
              payOrder(
                payinStatus: OrderPayinStatus.underReview,
                payoutMethod: OrderPaymentMethod.sinpe,
              ),
            ),
          ),
        ),
      ),
    );
    expect((next.state as PayDone).receipt, isA<WatchWatching<Order>>());
    expect(next.effects.whereType<PayReceiptEffect>(), isNotEmpty);
  });

  test('the receipt watch ends when the payout completes', () {
    final next = transitionPayFlow(payReceiptState, _events['receipt']!);
    expect((next.state as PayDone).receipt, isA<WatchDone<Order>>());
    expect(
      (next.state as PayDone).latest.payoutStatus,
      OrderPayoutStatus.completed,
    );
  });

  group('spend options', () {
    test('Confirm waits until the fee estimates are in', () {
      final review = payReviewState as PayOrdering;
      final waiting = PayOrdering(
        review.open,
        review.request,
        review.order,
        const SpendFeesUnavailable('w-1', 1),
      );
      final next = transitionPayFlow(waiting, PayConfirmPressed(payNow));
      expect(identical(next.state, waiting), isTrue);
      expect(next.effects, isEmpty);
    });

    test('the options chosen on the review build the payin', () {
      final changed = applyPay(payReviewState, const [
        PaySpendChanged(SpendFeePicked(FeeSelection.slow)),
        PaySpendChanged(SpendRbfChanged(enabled: false)),
      ]);
      final next = transitionPayFlow(changed, PayConfirmPressed(payNow));
      final build =
          (next.state as PayPaying).payin as PayinBuilding<PayinSpend>;
      expect(build.spend.options.fee, const PayinFeeRate(500));
      expect(build.spend.options.replaceByFee, isFalse);
    });

    test('once paying, options can no longer change', () {
      final next = transitionPayFlow(
        payPayingState,
        const PaySpendChanged(SpendPayjoinChanged(enabled: false)),
      );
      expect(identical(next.state, payPayingState), isTrue);
    });
  });
}
