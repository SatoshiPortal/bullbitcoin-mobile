import 'package:bull_exchange/src/payin/spend_options_state.dart';
import 'package:bull_exchange/src/payin/spend_options_event.dart';
import 'package:bull_exchange/src/payin/spend_options_effect.dart';
import 'package:fees/fees.dart';
import 'package:bull_exchange/src/payin/payin_runner.dart';
import 'package:bull_exchange/src/sell/domain/sell_state.dart';
import 'package:bull_exchange/src/sell/domain/sell_event.dart';
import 'package:bull_exchange/src/sell/domain/sell_effect.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_test/flutter_test.dart';

import '../sell_fixtures.dart';

import 'package:primitives/primitives.dart';

final _states = <String, SellFlowState>{
  'loading': sellLoadingState,
  'amount': sellAmountState,
  'source': sellSourceState,
  'payout': sellPayoutState,
  'recipient': sellRecipientState,
  'requirements': sellRequirementsState,
  'ordering': sellOrderingState,
  'review': sellReviewState,
  'paying': sellPayingState,
  'done': sellDoneState,
  'sessionEnded': const SellSessionEnded(),
  'closed': const SellClosed(),
};

final _events = <String, SellFlowEvent>{
  'contextLoaded': SellContextLoaded(1, Ok(sellContext)),
  'retry': const SellRetryPressed(),
  'amount': const SellAmountChanged(AmountTyped('5')),
  'kycReturned': const SellKycReturned(),
  'detourLoaded': SellDetourLoaded(Ok(sellContext)),
  'source': const SellSourcePicked(sellAppWallet),
  'payout': const SellPayoutPicked(SellPayoutChoice.balance),
  'picked': SellRecipientPicked(sellBankRecipient),
  'requirements': const SellRequirementsChanged(
    RequirementInteracEvent(InteracQuestionTyped('Colour?')),
  ),
  'order': SellOrderChanged(
    OrderCreateAnswered(1, Ok<Order, ExchangeWriteFailure>(sellOrder())),
  ),
  'confirm': SellConfirmPressed(sellNow),
  'spendFees': const SellSpendChanged(SpendFeesRead(1, Ok(sellFees))),
  'spendRbf': const SellSpendChanged(SpendRbfChanged(enabled: false)),
  'payin': SellPayinChanged(
    PayinBuildAnswered<PayinSpend>(
      1,
      const Err(ExchangePayinBuildFailure(PayinBuildProblem.insufficientFunds)),
      sellNow,
    ),
  ),
  'back': const SellBackPressed(),
  'donePressed': const SellDonePressed(),
  'visibility': const SellVisibilityChanged(visible: false),
  'session': const SellSessionChanged(sellOtherSession),
};

/// Every (state, event) pair that is not a stay, and the state it leads to.
const _moves = <(String, String), Type>{
  ('loading', 'contextLoaded'): SellAmount,
  ('loading', 'back'): SellClosed,
  ('loading', 'donePressed'): SellClosed,
  ('loading', 'session'): SellSessionEnded,
  ('amount', 'amount'): SellAmount,
  ('amount', 'back'): SellClosed,
  ('amount', 'session'): SellSessionEnded,
  ('source', 'source'): SellPayoutPick,
  ('source', 'back'): SellAmount,
  ('source', 'session'): SellSessionEnded,
  ('payout', 'payout'): SellOrdering,
  ('payout', 'back'): SellSource,
  ('payout', 'session'): SellSessionEnded,
  ('recipient', 'picked'): SellOrdering,
  ('recipient', 'back'): SellPayoutPick,
  ('recipient', 'session'): SellSessionEnded,
  ('requirements', 'requirements'): SellRequirements,
  ('requirements', 'back'): SellRecipient,
  ('requirements', 'session'): SellSessionEnded,
  ('ordering', 'order'): SellOrdering,
  ('ordering', 'spendFees'): SellOrdering,
  ('ordering', 'session'): SellSessionEnded,
  ('review', 'confirm'): SellPaying,
  ('review', 'spendRbf'): SellOrdering,
  ('review', 'back'): SellPayoutPick,
  ('review', 'session'): SellSessionEnded,
  ('paying', 'payin'): SellPaying,
  ('paying', 'back'): SellOrdering,
  ('paying', 'session'): SellSessionEnded,
  ('done', 'back'): SellClosed,
  ('done', 'donePressed'): SellClosed,
  ('done', 'session'): SellSessionEnded,
  ('sessionEnded', 'back'): SellClosed,
  ('sessionEnded', 'donePressed'): SellClosed,
};

SellPaying _paying(SellPayinState payin) {
  final paying = sellPayingState as SellPaying;
  return SellPaying(
    paying.open,
    paying.request,
    paying.quoted,
    payin,
    paying.spend,
  );
}

void main() {
  test('the sample states are the ones they name', () {
    expect(sellAmountState, isA<SellAmount>());
    expect(
      (sellAmountState as SellAmount).amount,
      isA<AmountEditing>().having((s) => s.quote, 'quote', isA<RateReady>()),
    );
    expect(sellSourceState, isA<SellSource>());
    expect(sellPayoutState, isA<SellPayoutPick>());
    expect(sellRecipientState, isA<SellRecipient>());
    expect(sellRequirementsState, isA<SellRequirements>());
    expect(
      (sellOrderingState as SellOrdering).order,
      isA<OrderCreating<SellRequest, Order>>(),
    );
    expect(
      (sellReviewState as SellOrdering).order,
      isA<OrderQuoted<SellRequest, Order>>(),
    );
    expect(
      (sellPayingState as SellPaying).payin,
      isA<PayinBuilding<PayinSpend>>(),
    );
  });

  group('every (state, event) pair', () {
    for (final MapEntry(key: stateName, value: state) in _states.entries) {
      for (final MapEntry(key: eventName, value: event) in _events.entries) {
        final expected = _moves[(stateName, eventName)];
        test('$stateName + $eventName', () {
          final next = state.next(event);
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
    final reached = <Type>{sellFlowStart(sellSession).state.runtimeType};
    for (final state in _states.values) {
      reached.add(state.runtimeType);
      for (final event in _events.values) {
        reached.add(state.next(event).state.runtimeType);
      }
    }
    expect(reached, {
      SellLoading,
      SellAmount,
      SellSource,
      SellPayoutPick,
      SellRecipient,
      SellRequirements,
      SellOrdering,
      SellPaying,
      SellDone,
      SellSessionEnded,
      SellClosed,
    });
  });

  group('order and quote', () {
    test('a created order is quoted with its lock timer', () {
      final next = sellOrderingState.next(_events['order']!);
      expect(next.effects, [
        const SellOrderEffect(OrderStartLockTimer<SellRequest>('s-1')),
      ]);
    });

    test('an unknown create re-reads; it never sends again', () {
      final next = sellOrderingState.next(
        const SellOrderChanged(
          OrderCreateAnswered(
            1,
            Err(ExchangeWriteOutcomeUnknownFailure('lost')),
          ),
        ),
      );
      expect(
        (next.state as SellOrdering).order,
        isA<OrderVerifying<SellRequest, Order>>(),
      );
      expect(next.effects.single, isA<SellOrderEffect>());
      final again = next.state.next(const SellRetryPressed());
      expect(identical(again.state, next.state), isTrue);
    });

    test('Confirm stops the quote timers and builds the payin', () {
      final next = sellReviewState.next(SellConfirmPressed(sellNow));
      expect(
        next.effects.first,
        const SellOrderEffect(OrderStopTimers<SellRequest>('s-1')),
      );
      final build =
          (next.effects.last as SellPayinEffect).effect
              as PayinBuild<PayinSpend>;
      expect(build.order.orderId, 's-1');
      expect(build.target, const OnchainDeposit('bc1qdeposit'));
      expect(build.spend, const PayinWalletSpend('w-1', sellDefaultOptions));
      expect(build.attempt, 1);
      expect(next.effects, hasLength(2));
    });

    test('Confirm on a refreshing quote does nothing', () {
      final review = sellReviewState as SellOrdering;
      final refreshing = SellOrdering(
        review.open,
        review.request,
        OrderQuoted(
          QuotedOrder('s-1', sellOrder() as Order),
          const QuoteRefreshing(0),
        ),
        review.spend,
      );
      final next = refreshing.next(SellConfirmPressed(sellNow));
      expect(identical(next.state, refreshing), isTrue);
    });

    test('a payout to a recipient creates a payment order with its params', () {
      final ordering = sellOrderingFromRecipient as SellOrdering;
      expect(ordering.request.payout, isA<SellToRecipient>());
      expect(ordering.request.journal.type, OrderType.fiatPayment);
      expect(ordering.request.journal.recipientId, 'r-bank');
    });

    test('a recipient the filter refuses stays with the refusal', () {
      final next = sellRecipientState.next(
        SellRecipientPicked(sellThirdPartyRecipient),
      );
      expect((next.state as SellRecipient).refused, sellThirdPartyRecipient);
    });
  });

  group('spend options', () {
    test('a new order reads the fee estimates beside the create', () {
      final next = sellPayoutState.next(
        const SellPayoutPicked(SellPayoutChoice.balance),
      );
      expect(
        (next.state as SellOrdering).spend,
        const SpendFeesLoading('w-1', 1),
      );
      expect(next.effects, contains(const SellSpendEffect(SpendLoadFees(1))));
    });

    test('the quote points the previews at its deposit and amount', () {
      final review = sellReviewState as SellOrdering;
      expect(
        (review.spend as SpendOptionsReady).target,
        const SpendPreviewTarget('bc1qdeposit', 20000),
      );
    });

    test('Confirm waits while the fee estimates load or failed', () {
      final review = sellReviewState as SellOrdering;
      for (final spend in const [
        SpendFeesLoading('w-1', 1),
        SpendFeesUnavailable('w-1', 1),
      ]) {
        final waiting = SellOrdering(
          review.open,
          review.request,
          review.order,
          spend,
        );
        final next = waiting.next(SellConfirmPressed(sellNow));
        expect(identical(next.state, waiting), isTrue);
        expect(next.effects, isEmpty);
      }
    });

    test('the options chosen on the review build the payin', () {
      final changed = applySell(sellReviewState, const [
        SellSpendChanged(SpendFeePicked(FeeSelection.economic)),
        SellSpendChanged(SpendRbfChanged(enabled: false)),
        SellSpendChanged(SpendPayjoinChanged(enabled: false)),
      ]);
      final next = changed.next(SellConfirmPressed(sellNow));
      final build =
          (next.state as SellPaying).payin as PayinBuilding<PayinSpend>;
      expect(
        build.spend.options,
        const PayinSpendOptions(
          fee: PayinFeeRate(1250),
          replaceByFee: false,
          coins: {},
          payjoin: false,
        ),
      );
    });

    test('once the payin started, options can no longer change', () {
      final next = sellPayingState.next(
        const SellSpendChanged(SpendFeePicked(FeeSelection.slow)),
      );
      expect(identical(next.state, sellPayingState), isTrue);
    });

    test('Back before anything was sent keeps the chosen options', () {
      final changed = applySell(sellReviewState, [
        const SellSpendChanged(SpendFeePicked(FeeSelection.slow)),
        SellConfirmPressed(sellNow),
      ]);
      expect(changed, isA<SellPaying>());
      final back = changed.next(const SellBackPressed()).state;
      expect(
        ((back as SellOrdering).spend as SpendOptionsReady).selection,
        FeeSelection.slow,
      );
    });
  });

  group('payin', () {
    test('an order with an open payin entry starts in Verifying', () {
      final review = sellReviewState as SellOrdering;
      final entry = UnknownWrite(
        id: 'j-1',
        kind: UnknownWriteKind.payin,
        environment: ExchangeEnvironment.mainnet,
        orderId: 's-1',
        request: const {'txid': 'tx-1'},
        recordedAt: sellNow,
      );
      final open = SellOpen(
        review.open.session,
        SellContext(review.open.context.summary, [entry]),
      );
      final next = SellOrdering(
        open,
        review.request,
        review.order,
        review.spend,
      ).next(SellConfirmPressed(sellNow));
      expect(
        (next.state as SellPaying).payin,
        isA<PayinVerifying<PayinSpend>>(),
      );
    });

    test('a lapsed quote before the send refreshes; Confirm waits', () {
      final next = sellReviewState.next(
        SellConfirmPressed(sellNow.add(const Duration(hours: 2))),
      );
      expect(
        (next.state as SellOrdering).order,
        isA<OrderQuoted<SellRequest, Order>>().having(
          (o) => o.status,
          'status',
          const QuoteRefreshing(0),
        ),
      );
      expect(
        next.effects.last,
        const SellOrderEffect(OrderRefresh<SellRequest>('s-1')),
      );
    });

    test('the payin seen by the exchange (under review included) is done', () {
      final watching = _paying(
        PayinWatching<PayinSpend>(
          sellOrder(),
          const OnchainDeposit('bc1qdeposit'),
          'tx-1',
          WatchWatching<Order>(sellOrder(), 0, 0, 1),
        ),
      );
      final next = watching.next(
        SellPayinChanged(
          PayinWatchEvent(
            WatchPolled(
              's-1',
              1,
              Ok<Order, ExchangeReadFailure>(
                sellOrder(payinStatus: OrderPayinStatus.underReview),
              ),
            ),
          ),
        ),
      );
      expect(next.state, isA<SellDone>());
    });

    test('Back from a payin the exchange refused leaves, never resends', () {
      final refused = _paying(
        PayinRefusedByExchange<PayinSpend>(sellOrder(), 'tx-1'),
      );
      expect(refused.next(const SellBackPressed()).state, isA<SellClosed>());
      expect(
        identical(refused.next(const SellRetryPressed()).state, refused),
        isTrue,
      );
    });

    test('a session change stops the payin watch', () {
      final next = sellPayingState.next(_events['session']!);
      expect(next.state, isA<SellSessionEnded>());
      expect(next.effects, [
        const SellPayinEffect(PayinWatchEffect(WatchStop('s-1'))),
      ]);
    });
  });

  test('an order limit refusal goes back to the amount with the limit', () {
    final back = applySell(sellOrderingState, [
      SellOrderChanged(
        OrderCreateAnswered(
          1,
          Err(
            ExchangeWriteRefusedFailure(
              ExchangeRefusal(
                orderLimit: const ExchangeOrderLimit(
                  ExchangeOrderAmountBound.minimum,
                  20,
                  'CAD',
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
    expect(back, isA<SellAmount>());
    final amount = (back as SellAmount).amount as AmountEditing;
    expect(amount.draft.text, '10');
    expect(amount.problem, const AmountBelowMinimum(20));
    final again = applySell(back, const [
      SellAmountChanged(AmountContinuePressed()),
    ]);
    expect(
      ((again as SellAmount).amount as AmountEditing).problem,
      const AmountBelowMinimum(20),
    );
    expect(
      applySell(again, const [
        SellAmountChanged(AmountTyped('25')),
        SellAmountChanged(AmountContinuePressed()),
      ]),
      isA<SellSource>(),
    );
  });
}
