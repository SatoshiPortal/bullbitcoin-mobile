import 'package:bull_exchange/src/buy/domain/buy_flow.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../buy_fixtures.dart';

final _states = <String, BuyFlowState>{
  'loading': buyLoadingState,
  'entry': buyEntryState,
  'ordering': buyOrderingState,
  'review': buyReviewState,
  'confirming': buyConfirmingState,
  'done': buyDoneState,
  'sessionEnded': const BuySessionEnded(),
  'closed': const BuyClosed(),
};

final _events = <String, BuyFlowEvent>{
  'contextLoaded': BuyContextLoaded(1, ReadGot(buyContext)),
  'retry': const BuyRetryPressed(),
  'amount': const BuyAmountChanged(AmountTyped('5')),
  'picked': BuyDestinationPicked(buyBitcoinWallet.option),
  'typed': const BuyAddressTyped('bc1qexternal'),
  'destination': BuyDestinationChanged(
    PickResolved(buyLiquidWallet.option, const Ok(buyLiquidDestination)),
  ),
  'payjoin': const BuyPayjoinToggled(false),
  'continue': const BuyContinuePressed(),
  'kycReturned': const BuyKycReturned(),
  'fundingReturned': const BuyFundingReturned(),
  'detourLoaded': BuyDetourLoaded(ReadGot(buyContext)),
  'order': BuyOrderChanged(OrderCreateAnswered(1, buyDone(buyOrder()))),
  'confirmPressed': BuyConfirmPressed(buyBeforeDeadline),
  'confirm': BuyConfirmChanged(
    ConfirmAnswered(1, buyDone(buyOrder(status: OrderStatus.inProgress))),
  ),
  'watch': BuyWatchChanged(
    WatchPolled(
      'b-1',
      1,
      ReadGot(
        buyOrder(
          status: OrderStatus.completed,
          payout: OrderPayoutStatus.completed,
        ),
      ),
    ),
  ),
  'back': const BuyBackPressed(),
  'donePressed': const BuyDonePressed(),
  'visibility': const BuyVisibilityChanged(visible: false),
  'session': const BuySessionChanged(buyOtherSession),
};

/// Every (state, event) pair that is not a stay, and the state it leads to.
const _moves = <(String, String), Type>{
  ('loading', 'contextLoaded'): BuyEntry,
  ('loading', 'back'): BuyClosed,
  ('loading', 'donePressed'): BuyClosed,
  ('loading', 'session'): BuySessionEnded,
  ('entry', 'amount'): BuyEntry,
  ('entry', 'picked'): BuyEntry,
  ('entry', 'payjoin'): BuyEntry,
  ('entry', 'continue'): BuyEntry,
  ('entry', 'back'): BuyClosed,
  ('entry', 'session'): BuySessionEnded,
  ('ordering', 'order'): BuyReview,
  ('ordering', 'session'): BuySessionEnded,
  ('review', 'confirmPressed'): BuyConfirming,
  ('review', 'back'): BuyEntry,
  ('review', 'session'): BuySessionEnded,
  ('confirming', 'confirm'): BuyDone,
  ('confirming', 'session'): BuySessionEnded,
  ('done', 'watch'): BuyDone,
  ('done', 'visibility'): BuyDone,
  ('done', 'back'): BuyClosed,
  ('done', 'donePressed'): BuyClosed,
  ('done', 'session'): BuySessionEnded,
  ('sessionEnded', 'back'): BuyClosed,
  ('sessionEnded', 'donePressed'): BuyClosed,
};

BuyEntry _entryOf(BuyFlowState state) => state as BuyEntry;

void main() {
  test('the sample states are the ones they name', () {
    expect(buyLoadingState, isA<BuyLoading>());
    final entry = _entryOf(buyEntryState);
    expect(
      entry.amount,
      isA<AmountEditing>().having((s) => s.quote, 'quote', isA<RateReady>()),
    );
    expect(
      entry.destination,
      isA<PickChosen<DestinationOption, Destination>>().having(
        (s) => s.value,
        'value',
        buyLiquidDestination,
      ),
    );
    expect(buyOrderingState, isA<BuyOrdering>());
    expect(buyReviewState, isA<BuyReview>());
    expect(buyConfirmingState, isA<BuyConfirming>());
    expect((buyDoneState as BuyDone).watch, isA<WatchWatching<BuyOrder>>());
  });

  group('every (state, event) pair', () {
    for (final MapEntry(key: stateName, value: state) in _states.entries) {
      for (final MapEntry(key: eventName, value: event) in _events.entries) {
        final expected = _moves[(stateName, eventName)];
        test('$stateName + $eventName', () {
          final next = transitionBuyFlow(state, event);
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
    final reached = <Type>{buyFlowStart(buySession).state.runtimeType};
    for (final state in _states.values) {
      reached.add(state.runtimeType);
      for (final event in _events.values) {
        reached.add(transitionBuyFlow(state, event).state.runtimeType);
      }
    }
    expect(reached, {
      BuyLoading,
      BuyEntry,
      BuyOrdering,
      BuyReview,
      BuyConfirming,
      BuyDone,
      BuySessionEnded,
      BuyClosed,
    });
  });

  group('start and load', () {
    test('no session has ended; a session loads the account', () {
      expect(buyFlowStart(null).state, isA<BuySessionEnded>());
      expect(buyFlowStart(buySession).effects, [const BuyLoadContext(1)]);
    });

    test('a failed load has a Retry that loads again', () {
      final failed = transitionBuyFlow(
        buyLoadingState,
        const BuyContextLoaded(1, ReadUnreachable('down', isNetwork: true)),
      );
      expect(
        (failed.state as BuyLoading).load,
        isA<ContextFailed<BuyContext>>(),
      );
      expect(transitionBuyFlow(failed.state, const BuyRetryPressed()).effects, [
        const BuyLoadContext(2),
      ]);
    });

    test('the entry loads the rate and the initial wallet address', () {
      final next = transitionBuyFlow(
        buyLoadingState,
        BuyContextLoaded(1, ReadGot(buyContext)),
      );
      expect(next.effects, [
        const BuyFetchRate(ExchangeCatalog.cad),
        BuyDestinationEffect(PickResolve(buyLiquidWallet.option)),
      ]);
    });

    test('several Liquid setup wallets start on an external address', () {
      final next = transitionBuyFlow(
        buyLoadingState,
        BuyContextLoaded(
          1,
          ReadGot(
            buyContextWith(
              wallets: const [
                buyLiquidWallet,
                BuyPayoutWallet(
                  walletId: 'w-lq2',
                  rail: BtcNetwork.liquid,
                  isDefault: true,
                ),
              ],
            ),
          ),
        ),
      );
      expect(
        _entryOf(next.state).destination,
        isA<PickChoosing<DestinationOption, Destination>>(),
      );
    });

    test('no funded balance has no market, and funding reloads', () {
      final empty = buyContextWith(summary: buySummaryWith(balances: const []));
      final entry = transitionBuyFlow(
        buyLoadingState,
        BuyContextLoaded(1, ReadGot(empty)),
      ).state;
      expect(_entryOf(entry).amount, isA<AmountNoMarket>());
      final reload = transitionBuyFlow(entry, const BuyFundingReturned());
      expect(reload.effects, [const BuyReloadForDetour()]);
      final funded = transitionBuyFlow(
        reload.state,
        BuyDetourLoaded(ReadGot(buyContext)),
      );
      expect(_entryOf(funded.state).amount, isA<AmountEditing>());
      expect(funded.effects, [const BuyFetchRate(ExchangeCatalog.cad)]);
    });
  });

  group('entry', () {
    test('Continue waits for a chosen destination', () {
      final external = applyBuy(buyEntryState, const [
        BuyDestinationPicked(null),
        BuyAmountChanged(AmountTyped('10')),
      ]).state;
      expect(
        _entryOf(external).destination,
        isA<PickChoosing<DestinationOption, Destination>>(),
      );
      expect(
        identical(
          transitionBuyFlow(external, const BuyContinuePressed()).state,
          external,
        ),
        isTrue,
      );
    });

    test('a typed external address is validated, then Continue orders', () {
      final typed = applyBuy(buyEntryState, const [
        BuyDestinationPicked(null),
        BuyAddressTyped('bc1qexternal'),
      ]);
      expect(typed.effects, [
        const BuyDestinationEffect(PickValidate('bc1qexternal')),
      ]);
      final valid = applyBuy(typed.state, const [
        BuyDestinationChanged(
          PickValidated(
            'bc1qexternal',
            Ok(DestinationAddress(BtcNetwork.bitcoin, 'bc1qexternal')),
          ),
        ),
        BuyAmountChanged(AmountTyped('10')),
        BuyContinuePressed(),
      ]);
      final ordering = valid.state as BuyOrdering;
      expect(ordering.request.network, BtcNetwork.bitcoin);
      expect(ordering.request.walletId, isNull);
      expect(ordering.request.payjoinWalletId, isNull);
    });

    test('a late validation of an older text is a stay', () {
      final typed = applyBuy(buyEntryState, const [
        BuyDestinationPicked(null),
        BuyAddressTyped('bc1qa'),
        BuyAddressTyped('bc1qab'),
      ]).state;
      final late = transitionBuyFlow(
        typed,
        const BuyDestinationChanged(
          PickValidated(
            'bc1qa',
            Ok(DestinationAddress(BtcNetwork.bitcoin, 'a')),
          ),
        ),
      );
      expect(identical(late.state, typed), isTrue);
    });

    test('an app wallet whose address read fails stays selected, named', () {
      final failed = applyBuy(buyEntryState, [
        BuyDestinationPicked(buyBitcoinWallet.option),
        BuyDestinationChanged(
          PickResolved(
            buyBitcoinWallet.option,
            const Err(BuyReceiveAddressUnavailable()),
          ),
        ),
      ]).state;
      expect(_entryOf(failed).selectedWallet, buyBitcoinWallet);
      expect(
        _entryOf(failed).destination,
        isA<PickChoosing<DestinationOption, Destination>>().having(
          (s) => s.problem,
          'problem',
          isA<PickResolveFailed<DestinationOption>>(),
        ),
      );
    });

    test('payjoin goes with an on-chain wallet when the switch is on', () {
      final ordering =
          applyBuy(buyEntryState, [
                BuyDestinationPicked(buyBitcoinWallet.option),
                BuyDestinationChanged(
                  PickResolved(
                    buyBitcoinWallet.option,
                    const Ok(buyBitcoinDestination),
                  ),
                ),
                const BuyAmountChanged(AmountTyped('10')),
                const BuyContinuePressed(),
              ]).state
              as BuyOrdering;
      expect(ordering.request.payjoinWalletId, 'w-btc');
      expect(ordering.request.walletId, 'w-btc');

      final off =
          applyBuy(buyEntryState, [
                BuyDestinationPicked(buyBitcoinWallet.option),
                BuyDestinationChanged(
                  PickResolved(
                    buyBitcoinWallet.option,
                    const Ok(buyBitcoinDestination),
                  ),
                ),
                const BuyPayjoinToggled(false),
                const BuyAmountChanged(AmountTyped('10')),
                const BuyContinuePressed(),
              ]).state
              as BuyOrdering;
      expect(off.request.payjoinWalletId, isNull);
    });

    test('Liquid never pays out through payjoin', () {
      expect((buyOrderingState as BuyOrdering).request.payjoinWalletId, isNull);
      expect(_entryOf(buyEntryState).offersPayjoin, isFalse);
    });

    test('an amount over the balance is the funding detour and returns', () {
      final detour = applyBuy(buyEntryState, const [
        BuyAmountChanged(AmountTyped('500')),
        BuyContinuePressed(),
      ]).state;
      expect(_entryOf(detour).amount, isA<AmountFundingDetour>());
      final reload = transitionBuyFlow(detour, const BuyFundingReturned());
      expect(reload.effects, [const BuyReloadForDetour()]);
      final rich = buyContextWith(
        summary: buySummaryWith(
          balances: const [UserBalance(amount: 1000, currencyCode: 'CAD')],
        ),
      );
      final back = transitionBuyFlow(
        reload.state,
        BuyDetourLoaded(ReadGot(rich)),
      ).state;
      expect(
        _entryOf(back).amount,
        isA<AmountEditing>()
            .having((s) => s.draft.text, 'text', '500')
            .having((s) => s.problem, 'problem', isNull),
      );
      expect(_entryOf(back).destination, _entryOf(detour).destination);
    });

    test('a KYC level too low is the KYC detour; Back re-checks the draft', () {
      final low = buyContextWith(summary: buySummaryWith(groups: const []));
      final entry = applyBuy(buyLoadingState, [
        BuyContextLoaded(1, ReadGot(low)),
        const BuyAmountChanged(
          AmountRateArrived(ExchangeCatalog.cad, ReadGot(50000.0)),
        ),
        BuyDestinationChanged(
          PickResolved(buyLiquidWallet.option, const Ok(buyLiquidDestination)),
        ),
        const BuyAmountChanged(AmountTyped('10')),
        const BuyContinuePressed(),
      ]).state;
      expect(_entryOf(entry).amount, isA<AmountKycDetour>());
      expect(transitionBuyFlow(entry, const BuyKycReturned()).effects, [
        const BuyReloadForDetour(),
      ]);
      final back = transitionBuyFlow(entry, const BuyBackPressed()).state;
      expect(
        _entryOf(back).amount,
        isA<AmountEditing>().having(
          (s) => s.problem,
          'problem',
          isA<AmountKycNeeded>(),
        ),
      );
    });
  });

  group('order and review', () {
    test('the create carries the amount in the unit it was entered in', () {
      final ordering = buyOrderingState as BuyOrdering;
      expect(ordering.request.orderAmount, isA<FiatAmount>());
      expect(ordering.request.journal.type, OrderType.buy);
      expect(
        transitionBuyFlow(buyEntryState, const BuyContinuePressed()).state,
        isA<BuyEntry>(),
      );
    });

    test('an unknown create re-reads, never creates again', () {
      final verifying = transitionBuyFlow(
        buyOrderingState,
        const BuyOrderChanged(
          OrderCreateAnswered(1, GateAdmitted(WriteOutcomeUnknown('lost'))),
        ),
      );
      expect(
        (verifying.state as BuyOrdering).order,
        isA<OrderVerifying<BuyRequest, BuyOrder>>(),
      );
      expect(verifying.effects.single, isA<BuyOrderEffect>());
      expect(
        transitionBuyFlow(verifying.state, const BuyRetryPressed()).state,
        same(verifying.state),
      );
    });

    test('a refused create goes back to the entry with the draft', () {
      final failed = transitionBuyFlow(
        buyOrderingState,
        const BuyOrderChanged(
          OrderCreateAnswered(1, GateAdmitted(WriteRefused(ExchangeRefusal()))),
        ),
      ).state;
      final back = transitionBuyFlow(failed, const BuyBackPressed()).state;
      expect(
        _entryOf(back).amount,
        isA<AmountEditing>().having((s) => s.draft.text, 'text', '10'),
      );
      expect(
        _entryOf(back).destination,
        isA<PickChosen<DestinationOption, Destination>>(),
      );
    });

    test('Back from the quote stops its timers and releases its payjoin', () {
      final back = transitionBuyFlow(buyReviewState, const BuyBackPressed());
      expect(back.state, isA<BuyEntry>());
      expect(back.effects, [
        const BuyOrderEffect(OrderStopTimers('b-1')),
        const BuyOrderEffect(OrderRelease('b-1')),
      ]);
    });

    test('Confirm on a lapsed price refreshes it and says so', () {
      final next = transitionBuyFlow(
        buyReviewState,
        BuyConfirmPressed(buyDeadline),
      );
      expect(
        next.state,
        isA<BuyReview>()
            .having((s) => s.notice, 'notice', const BuyQuoteLapsed())
            .having((s) => s.quote.status, 'status', const QuoteRefreshing(0)),
      );
      expect(next.effects, [const BuyOrderEffect(OrderRefresh('b-1'))]);
    });

    test('Confirm stops the quote timers and sends the confirm', () {
      final next = transitionBuyFlow(
        buyReviewState,
        BuyConfirmPressed(buyBeforeDeadline),
      );
      expect(next.effects, [
        const BuyOrderEffect(OrderStopTimers('b-1')),
        BuyConfirmEffect(ConfirmSend(BuyConfirmTarget(buyOrder()), 1)),
      ]);
    });

    test('an open buyConfirm entry starts the confirm in Verifying', () {
      final entry = UnknownWrite(
        id: 'u',
        kind: UnknownWriteKind.buyConfirm,
        environment: ExchangeEnvironment.mainnet,
        sessionEpoch: 1,
        orderId: 'b-1',
        request: const {},
        recordedAt: DateTime.utc(2026, 11, 24),
      );
      final review = applyBuy(buyFlowStart(buySession).state, [
        BuyContextLoaded(1, ReadGot(buyContextWith(openEntries: [entry]))),
        const BuyAmountChanged(
          AmountRateArrived(ExchangeCatalog.cad, ReadGot(50000.0)),
        ),
        BuyDestinationChanged(
          PickResolved(buyLiquidWallet.option, const Ok(buyLiquidDestination)),
        ),
        const BuyAmountChanged(AmountTyped('10')),
        const BuyContinuePressed(),
        BuyOrderChanged(OrderCreateAnswered(1, buyDone(buyOrder()))),
      ]).state;
      final next = transitionBuyFlow(
        review,
        BuyConfirmPressed(buyBeforeDeadline),
      );
      expect(
        (next.state as BuyConfirming).confirm,
        isA<ConfirmVerifying<BuyConfirmTarget, BuyOrder>>(),
      );
    });
  });

  group('confirm', () {
    test('a second Confirm or Back while confirming is a stay (BUY-1/4/5)', () {
      for (final event in [
        BuyConfirmPressed(buyBeforeDeadline),
        const BuyBackPressed(),
        const BuyRetryPressed(),
      ]) {
        expect(
          identical(
            transitionBuyFlow(buyConfirmingState, event).state,
            buyConfirmingState,
          ),
          isTrue,
        );
      }
    });

    test('a confirm whose payin is not completed is done all the same', () {
      expect(buyDoneState, isA<BuyDone>());
      expect(
        (buyDoneState as BuyDone).order.payinStatus,
        OrderPayinStatus.notStarted,
      );
    });

    test('an unknown confirm verifies; unverified offers only Check again', () {
      final verifying = transitionBuyFlow(
        buyConfirmingState,
        const BuyConfirmChanged(
          ConfirmAnswered(1, GateAdmitted(WriteOutcomeUnknown('lost'))),
        ),
      );
      expect(verifying.effects, [
        BuyConfirmEffect(ConfirmVerify(BuyConfirmTarget(buyOrder()), 1)),
      ]);
      final unverified = transitionBuyFlow(
        verifying.state,
        const BuyConfirmChanged(
          ConfirmVerified(1, ConfirmCheckFailed(ReadProblemMalformed())),
        ),
      ).state;
      expect(
        (unverified as BuyConfirming).confirm,
        isA<ConfirmUnverified<BuyConfirmTarget, BuyOrder>>(),
      );
      expect(transitionBuyFlow(unverified, const BuyRetryPressed()).effects, [
        BuyConfirmEffect(ConfirmVerify(BuyConfirmTarget(buyOrder()), 1)),
      ]);
      expect(
        transitionBuyFlow(unverified, const BuyBackPressed()).state,
        const BuyClosed(),
      );
    });

    test('a refused confirm is the review again, refreshed, with why', () {
      final next = transitionBuyFlow(
        buyConfirmingState,
        const BuyConfirmChanged(
          ConfirmAnswered(1, GateAdmitted(WriteRefused(ExchangeRefusal()))),
        ),
      );
      expect(
        next.state,
        isA<BuyReview>().having(
          (s) => s.notice,
          'notice',
          isA<BuyConfirmNotApplied>(),
        ),
      );
      expect(next.effects, [const BuyOrderEffect(OrderRefresh('b-1'))]);
    });

    test('a busy write gate is the review again, nothing sent', () {
      final next = transitionBuyFlow(
        buyConfirmingState,
        const BuyConfirmChanged(
          ConfirmAnswered(
            1,
            GateRefused(WriteGateBusy(FinancialWriteKind.payin)),
          ),
        ),
      );
      expect((next.state as BuyReview).notice, isA<BuyConfirmGateRefused>());
    });

    test('a re-read that shows the confirm not applied offers it again', () {
      final verifying = transitionBuyFlow(
        buyConfirmingState,
        const BuyConfirmChanged(
          ConfirmAnswered(1, GateAdmitted(WriteOutcomeUnknown('lost'))),
        ),
      ).state;
      final next = transitionBuyFlow(
        verifying,
        BuyConfirmChanged(
          ConfirmVerified(1, buyConfirmCheck(ReadGot(buyOrder()))),
        ),
      );
      expect(next.state, isA<BuyReview>());
    });
  });

  group('done', () {
    test('the payout watch starts with the confirm', () {
      final next = transitionBuyFlow(
        buyConfirmingState,
        BuyConfirmChanged(
          ConfirmAnswered(1, buyDone(buyOrder(status: OrderStatus.inProgress))),
        ),
      );
      expect(next.effects, [
        const BuyWatchEffect(WatchStartDeadline('b-1', Duration(minutes: 10))),
        const BuyWatchEffect(WatchSchedulePoll('b-1', 1, immediate: false)),
      ]);
    });

    test('a completed payout settles once: label and wallet sync', () {
      final completed = buyOrder(
        status: OrderStatus.completed,
        payout: OrderPayoutStatus.completed,
      );
      final next = transitionBuyFlow(
        buyDoneState,
        BuyWatchChanged(WatchPolled('b-1', 1, ReadGot(completed))),
      );
      expect(next.effects, [
        const BuyWatchEffect(WatchStop('b-1')),
        BuyPayoutSettled(completed, 'w-lq'),
      ]);
    });

    test('a confirm answered with the payout done settles at once', () {
      final completed = buyOrder(
        status: OrderStatus.completed,
        payout: OrderPayoutStatus.completed,
      );
      final next = transitionBuyFlow(
        buyConfirmingState,
        BuyConfirmChanged(ConfirmAnswered(1, buyDone(completed))),
      );
      expect(next.effects, [BuyPayoutSettled(completed, 'w-lq')]);
    });

    test('hidden pauses the watch; Close stops it', () {
      final paused = transitionBuyFlow(
        buyDoneState,
        const BuyVisibilityChanged(visible: false),
      );
      expect((paused.state as BuyDone).watch, isA<WatchPaused<BuyOrder>>());
      final closed = transitionBuyFlow(buyDoneState, const BuyDonePressed());
      expect(closed.state, const BuyClosed(bought: true));
      expect(closed.effects, [const BuyWatchEffect(WatchStop('b-1'))]);
    });

    test('a cancelled order fails the watch (BUY-7)', () {
      expect(
        buyPayoutVerdict(buyOrder(status: OrderStatus.canceled)),
        OutcomeVerdict.failed,
      );
      expect(buyPayoutVerdict(buyOrder()), OutcomeVerdict.pending);
    });
  });

  group('session', () {
    test('a session change on the quote stops it and releases it', () {
      final next = transitionBuyFlow(
        buyReviewState,
        const BuySessionChanged(buyOtherSession),
      );
      expect(next.state, const BuySessionEnded());
      expect(next.effects, [
        const BuyOrderEffect(OrderStopTimers('b-1')),
        const BuyOrderEffect(OrderRelease('b-1')),
      ]);
    });

    test('the same session again is a stay', () {
      expect(
        identical(
          transitionBuyFlow(
            buyEntryState,
            const BuySessionChanged(buySession),
          ).state,
          buyEntryState,
        ),
        isTrue,
      );
    });
  });

  test('an order limit refusal goes back to the entry with the limit', () {
    final back = applyBuy(buyOrderingState, [
      BuyOrderChanged(
        OrderCreateAnswered(
          1,
          GateAdmitted(
            WriteRefused(
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
    ]).state;
    expect(back, isA<BuyEntry>());
    final amount = (back as BuyEntry).amount as AmountEditing;
    expect(amount.draft.text, '10');
    expect(amount.problem, const AmountBelowMinimum(20));
    final again = applyBuy(back, const [BuyContinuePressed()]).state;
    expect(
      ((again as BuyEntry).amount as AmountEditing).problem,
      const AmountBelowMinimum(20),
    );
  });
}
