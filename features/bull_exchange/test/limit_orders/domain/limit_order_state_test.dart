import 'package:bull_exchange/src/limit_orders/domain/limit_order_state.dart';
import 'package:bull_exchange/src/limit_orders/domain/limit_order_event.dart';
import 'package:bull_exchange/src/limit_orders/domain/limit_order_effect.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_test/flutter_test.dart';

import '../limit_order_fixtures.dart';

import 'package:primitives/primitives.dart';

final _summary = userSummary(
  balances: const [
    UserBalance(amount: 500, currencyCode: 'CAD'),
    UserBalance(amount: 100, currencyCode: 'EUR'),
  ],
);

LimitOrderContext _context({
  UserSummary? summary,
  List<UnknownWrite> entries = const [],
}) => LimitOrderContext(summary ?? _summary, limitDefaultWallets(), const [
  LimitAppWallet('w-liquid', BtcNetwork.liquid, label: 'Instant'),
], entries);

final _ctx = _context();
final _rate = limitOrderRate();
const _btcOption = DestinationOptionDefaultWallet(
  BtcNetwork.bitcoin,
  limitBitcoinAddress,
);
const _liquidOption = DestinationOptionAppWallet('w-liquid', BtcNetwork.liquid);

LimitFlowNext _apply(LimitFlowState state, List<LimitFlowEvent> events) {
  var next = LimitFlowNext.stay(state);
  for (final event in events) {
    next = next.state.next(event);
  }
  return next;
}

final _loading = limitFlowStart(limitSession).state;
final _noBalance = _apply(_loading, [
  LimitContextLoaded(
    1,
    Ok(
      _context(
        summary: userSummary(
          balances: const [UserBalance(amount: 0, currencyCode: 'CAD')],
        ),
      ),
    ),
  ),
]).state;
final _intro = _apply(_loading, [LimitContextLoaded(1, Ok(_ctx))]).state;
final _target = _apply(_intro, [
  const LimitContinuePressed(),
  LimitTargetRateArrived(ExchangeCatalog.cad, 1, Ok(_rate)),
]).state;
final _destination = _apply(_target, const [LimitContinuePressed()]).state;
final _amount = _apply(_destination, const [
  LimitDestinationChanged(PickChose(_btcOption)),
  LimitContinuePressed(),
]).state;
final _review = _apply(_amount, const [
  LimitAmountChanged(AmountTyped('200')),
  LimitContinuePressed(),
]).state;
final _live = _apply(_review, [LimitReviewRateArrived(1, Ok(_rate))]).state;
final _creating = _apply(_live, const [LimitConfirmPressed()]).state;
final _doneState = _apply(_creating, [
  LimitConfirmChanged(ConfirmAnswered(1, GateAdmitted(Ok(limitOrder())))),
]).state;
const _sessionEnded = LimitSessionEnded();
const _closedState = LimitClosed();

final _states = <String, LimitFlowState>{
  'loading': _loading,
  'noBalance': _noBalance,
  'intro': _intro,
  'target': _target,
  'destination': _destination,
  'amount': _amount,
  'review': _review,
  'creating': _creating,
  'done': _doneState,
  'sessionEnded': _sessionEnded,
  'closed': _closedState,
};

final _events = <String, LimitFlowEvent>{
  'contextLoaded': LimitContextLoaded(1, Ok(_ctx)),
  'retry': const LimitRetryPressed(),
  'continue': const LimitContinuePressed(),
  'back': const LimitBackPressed(),
  'donePressed': const LimitDonePressed(),
  'viewOrder': const LimitViewOrderPressed(),
  'session': const LimitSessionChanged(limitOtherSession),
  'currency': const LimitCurrencyChosen(ExchangeCatalog.eur),
  'price': const LimitPriceTyped(80000),
  'discount': const LimitDiscountChanged(5),
  'targetRate': LimitTargetRateArrived(ExchangeCatalog.cad, 1, Ok(_rate)),
  'destination': const LimitDestinationChanged(PickChose(_btcOption)),
  'amount': const LimitAmountChanged(AmountTyped('5')),
  'kycReturned': const LimitKycReturned(),
  'detourLoaded': LimitDetourLoaded(Ok(_ctx)),
  'reviewRate': LimitReviewRateArrived(1, Ok(_rate)),
  'confirmPressed': const LimitConfirmPressed(),
  'confirm': LimitConfirmChanged(
    ConfirmAnswered(1, GateAdmitted(Ok(limitOrder()))),
  ),
};

/// Every (state, event) pair that is not a stay, and the state it leads to.
const _moves = <(String, String), Type>{
  ('loading', 'contextLoaded'): LimitIntro,
  ('loading', 'back'): LimitClosed,
  ('loading', 'donePressed'): LimitClosed,
  ('loading', 'session'): LimitSessionEnded,
  ('noBalance', 'back'): LimitClosed,
  ('noBalance', 'donePressed'): LimitClosed,
  ('noBalance', 'session'): LimitSessionEnded,
  ('intro', 'continue'): LimitTarget,
  ('intro', 'back'): LimitClosed,
  ('intro', 'session'): LimitSessionEnded,
  ('target', 'continue'): LimitDestination,
  ('target', 'back'): LimitIntro,
  ('target', 'session'): LimitSessionEnded,
  ('target', 'currency'): LimitTarget,
  ('target', 'price'): LimitTarget,
  ('target', 'discount'): LimitTarget,
  ('destination', 'back'): LimitTarget,
  ('destination', 'session'): LimitSessionEnded,
  ('destination', 'destination'): LimitDestination,
  ('amount', 'continue'): LimitAmount,
  ('amount', 'back'): LimitDestination,
  ('amount', 'session'): LimitSessionEnded,
  ('amount', 'amount'): LimitAmount,
  ('review', 'back'): LimitAmount,
  ('review', 'session'): LimitSessionEnded,
  ('review', 'reviewRate'): LimitReview,
  ('creating', 'session'): LimitSessionEnded,
  ('creating', 'confirm'): LimitDone,
  ('done', 'back'): LimitClosed,
  ('done', 'donePressed'): LimitClosed,
  ('done', 'viewOrder'): LimitClosed,
  ('done', 'session'): LimitSessionEnded,
  ('sessionEnded', 'back'): LimitClosed,
  ('sessionEnded', 'donePressed'): LimitClosed,
};

void main() {
  test('the sample states are the ones they name', () {
    expect(_loading, isA<LimitLoading>());
    expect(_noBalance, isA<LimitNoFundedBalance>());
    expect(_intro, isA<LimitIntro>());
    expect(
      _target,
      isA<LimitTarget>().having((s) => s.step, 'step', isA<TargetReady>()),
    );
    expect(_destination, isA<LimitDestination>());
    expect(
      _amount,
      isA<LimitAmount>().having(
        (s) => s.amount,
        'amount',
        isA<AmountEditing>().having((a) => a.quote, 'quote', isA<RateReady>()),
      ),
    );
    expect(
      _review,
      isA<LimitReview>().having((s) => s.check, 'check', isA<ReviewChecking>()),
    );
    expect(
      _live,
      isA<LimitReview>().having((s) => s.check, 'check', isA<ReviewLive>()),
    );
    expect(_creating, isA<LimitCreating>());
    expect(_doneState, isA<LimitDone>());
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
    final reached = <Type>{limitFlowStart(limitSession).state.runtimeType};
    for (final state in _states.values) {
      reached.add(state.runtimeType);
      for (final event in _events.values) {
        reached.add(state.next(event).state.runtimeType);
      }
    }
    expect(reached, {
      LimitLoading,
      LimitNoFundedBalance,
      LimitIntro,
      LimitTarget,
      LimitDestination,
      LimitAmount,
      LimitReview,
      LimitCreating,
      LimitDone,
      LimitSessionEnded,
      LimitClosed,
    });
  });

  group('start and load', () {
    test('no session has ended; a session loads the account', () {
      expect(limitFlowStart(null).state, isA<LimitSessionEnded>());
      expect(limitFlowStart(limitSession).effects, [const LimitLoadContext(1)]);
    });

    test('a failed load has a Retry that loads again', () {
      final failed = _loading.next(
        const LimitContextLoaded(
          1,
          Err(ExchangeUnreachableFailure('down', isNetwork: true)),
        ),
      );
      expect(
        (failed.state as LimitLoading).load,
        isA<ContextFailed<LimitOrderContext>>(),
      );
      expect(failed.state.next(const LimitRetryPressed()).effects, [
        const LimitLoadContext(2),
      ]);
    });

    test('the intro uses the account currency when it is funded', () {
      expect((_intro as LimitIntro).market, ExchangeCatalog.cad);
    });

    test('an expired session on the load ends the flow', () {
      expect(
        _loading
            .next(
              const LimitContextLoaded(
                1,
                Err(
                  ExchangeSessionRejectedFailure(
                    ExchangeSessionRejection.server,
                  ),
                ),
              ),
            )
            .state,
        isA<LimitSessionEnded>(),
      );
    });
  });

  group('target', () {
    test('Continue on the intro reads the rate of its market', () {
      expect(_intro.next(const LimitContinuePressed()).effects, [
        const LimitFetchTargetRate(ExchangeCatalog.cad, 1),
      ]);
    });

    test('the first rate starts 1 % under the index price', () {
      final step = (_target as LimitTarget).step as TargetReady;
      expect(step.target.discount, 1);
      expect(step.target.limitPrice, closeTo(99000, 1e-6));
    });

    test('a failed switch keeps the old target and says why (LIM-1)', () {
      final switching = _target.next(
        const LimitCurrencyChosen(ExchangeCatalog.eur),
      );
      expect(switching.effects, [
        const LimitFetchTargetRate(ExchangeCatalog.eur, 2),
      ]);
      final failed = switching.state
          .next(
            const LimitTargetRateArrived(
              ExchangeCatalog.eur,
              2,
              Err(ExchangeUnreachableFailure('down', isNetwork: true)),
            ),
          )
          .state;
      final step = (failed as LimitTarget).step as TargetReady;
      expect(step.target.market, ExchangeCatalog.cad);
      expect(step.target.rate.currencyCode, 'CAD');
      expect(step.switchProblem, isA<ReadProblemUnreachable>());
    });

    test('a rate answer for another attempt or market is a stay', () {
      final switching = _target
          .next(const LimitCurrencyChosen(ExchangeCatalog.eur))
          .state;
      for (final stale in [
        LimitTargetRateArrived(ExchangeCatalog.eur, 1, Ok(_rate)),
        LimitTargetRateArrived(ExchangeCatalog.cad, 2, Ok(_rate)),
      ]) {
        expect(identical(switching.next(stale).state, switching), isTrue);
      }
    });

    test('a first read that fails has a Retry; Continue waits', () {
      final failed = _apply(_intro, const [
        LimitContinuePressed(),
        LimitTargetRateArrived(
          ExchangeCatalog.cad,
          1,
          Err(ExchangeMalformedFailure('bad')),
        ),
      ]);
      expect((failed.state as LimitTarget).step, isA<TargetFailed>());
      expect(
        identical(
          failed.state.next(const LimitContinuePressed()).state,
          failed.state,
        ),
        isTrue,
      );
      expect(failed.state.next(const LimitRetryPressed()).effects, [
        const LimitFetchTargetRate(ExchangeCatalog.cad, 2),
      ]);
    });

    test('price and discount move together and stay within 1–99 %', () {
      final priced = _apply(_target, const [LimitPriceTyped(80000)]).state;
      final target = ((priced as LimitTarget).step as TargetReady).target;
      expect(target.limitPrice, 80000);
      expect(target.discount, closeTo(20, 1e-9));
      final clamped = _apply(_target, const [LimitPriceTyped(150000)]).state;
      expect(
        ((clamped as LimitTarget).step as TargetReady).target.limitPrice,
        closeTo(99000, 1e-6),
      );
      final discounted = _apply(_target, const [
        LimitDiscountChanged(150),
      ]).state;
      expect(
        ((discounted as LimitTarget).step as TargetReady).target.discount,
        99,
      );
    });

    test('a currency without a funded balance is not offered', () {
      expect(
        identical(
          _target.next(const LimitCurrencyChosen(ExchangeCatalog.mxn)).state,
          _target,
        ),
        isTrue,
      );
    });
  });

  group('destination', () {
    test('the options are the default wallets, then the app wallets', () {
      final pick = (_destination as LimitDestination).pick;
      expect(pick.options, [_btcOption, _liquidOption]);
    });

    test('an app wallet reads its receive address', () {
      final next = _destination.next(
        const LimitDestinationChanged(PickChose(_liquidOption)),
      );
      expect(next.effects, [
        const LimitDestinationEffect(PickResolve(_liquidOption)),
      ]);
    });

    test('a typed Lightning address is validated', () {
      final next = _destination.next(
        const LimitDestinationChanged(PickTyped('me@example.com')),
      );
      expect(next.effects, [
        const LimitDestinationEffect(PickValidate('me@example.com')),
      ]);
    });

    test('a chosen destination can be changed by another pick', () {
      final chosen = _apply(_destination, const [
        LimitDestinationChanged(PickChose(_btcOption)),
      ]).state;
      final next = chosen.next(
        const LimitDestinationChanged(PickChose(_liquidOption)),
      );
      expect(
        (next.state as LimitDestination).pick,
        isA<PickResolving<DestinationOption, Destination>>(),
      );
    });

    test('Continue waits for a destination', () {
      expect(
        identical(
          _destination.next(const LimitContinuePressed()).state,
          _destination,
        ),
        isTrue,
      );
    });
  });

  group('amount', () {
    LimitFlowState amountTo(Destination destination) {
      final destinationState = _destination as LimitDestination;
      return _apply(
        LimitDestination(
          destinationState.open,
          destinationState.target,
          PickChosen<DestinationOption, Destination>(
            destinationState.pick.options,
            destination,
          ),
        ),
        const [LimitContinuePressed()],
      ).state;
    }

    test('the estimate is at the target price', () {
      final review = _review as LimitReview;
      expect(review.request.amount.sats, (200 / 99000 * 100000000).round());
    });

    test('Lightning refuses an amount over its maximum', () {
      final next = _apply(
        amountTo(const DestinationAddress(BtcNetwork.lightning, 'me@x.com')),
        const [
          LimitAmountChanged(AmountTyped('30000')),
          LimitContinuePressed(),
        ],
      ).state;
      expect(
        (next as LimitAmount).amount,
        isA<AmountEditing>().having(
          (a) => a.problem,
          'problem',
          isA<AmountAboveMaximum>(),
        ),
      );
    });

    test('on-chain refuses an amount under its minimum', () {
      final next = _apply(_amount, const [
        LimitAmountChanged(AmountTyped('50')),
        LimitContinuePressed(),
      ]).state;
      expect(
        (next as LimitAmount).amount,
        isA<AmountEditing>().having(
          (a) => a.problem,
          'problem',
          isA<AmountBelowMinimum>(),
        ),
      );
    });

    test('over the balance passes, marked as over the balance', () {
      final next = _apply(_amount, const [
        LimitAmountChanged(AmountTyped('900')),
        LimitContinuePressed(),
      ]).state;
      expect((next as LimitReview).request.amount.overBalance, isTrue);
    });

    test('an account without KYC takes the KYC detour, then reads again', () {
      final noKyc = _context(summary: _summary.copyWith(groups: const []));
      final open = (_amount as LimitAmount).open;
      final amount = _amount as LimitAmount;
      final detour = _apply(
        LimitAmount(
          LimitOpen(open.session, noKyc),
          amount.target,
          amount.destination,
          AmountEditing(
            draft: const AmountDraft(market: ExchangeCatalog.cad),
            quote: RateReady(
              MarketRate(ExchangeCatalog.cad, amount.target.limitPrice),
            ),
            context: noKyc.amountContext,
          ),
        ),
        const [LimitAmountChanged(AmountTyped('200')), LimitContinuePressed()],
      ).state;
      expect((detour as LimitAmount).amount, isA<AmountKycDetour>());
      final returned = detour.next(const LimitKycReturned());
      expect(returned.effects, [const LimitReloadForDetour()]);
      final reloaded = detour.next(LimitDetourLoaded(Ok(_ctx))).state;
      expect((reloaded as LimitAmount).amount, isA<AmountEditing>());
    });
  });

  group('review', () {
    test('entering it reads the rate again (LIM-4)', () {
      final next = _apply(_amount, const [
        LimitAmountChanged(AmountTyped('200')),
        LimitContinuePressed(),
      ]);
      expect(next.effects, [
        const LimitFetchReviewRate(ExchangeCatalog.cad, 1),
      ]);
    });

    test('a target at or above the new index price offers no Confirm', () {
      final above = _review
          .next(
            LimitReviewRateArrived(1, Ok(limitOrderRate(indexPrice: 90000))),
          )
          .state;
      expect((above as LimitReview).check, isA<ReviewTargetAbove>());
      expect(
        identical(above.next(const LimitConfirmPressed()).state, above),
        isTrue,
      );
    });

    test('a failed read has a Retry with a new attempt', () {
      final failed = _review
          .next(
            const LimitReviewRateArrived(
              1,
              Err(ExchangeUnreachableFailure('x', isNetwork: true)),
            ),
          )
          .state;
      expect(failed.next(const LimitRetryPressed()).effects, [
        const LimitFetchReviewRate(ExchangeCatalog.cad, 2),
      ]);
    });

    test('Confirm sends the create once', () {
      final next = _live.next(const LimitConfirmPressed());
      expect(next.effects, hasLength(1));
      final effect = next.effects.single as LimitConfirmEffect;
      final send = effect.effect as ConfirmSend<LimitOrderRequest>;
      expect(send.target.draft.address, limitBitcoinAddress);
      expect(send.target.draft.fiatAmount, 200);
      expect(
        identical(
          next.state.next(const LimitConfirmPressed()).state,
          next.state,
        ),
        isTrue,
      );
    });

    test('an open journal entry of a create starts in Verifying', () {
      final live = _live as LimitReview;
      final entry = UnknownWrite(
        id: 'e-1',
        kind: UnknownWriteKind.limitOrderCreate,
        environment: ExchangeEnvironment.mainnet,
        sessionEpoch: 1,
        request: live.request.draft.journalRequest,
        recordedAt: DateTime.utc(2026, 11, 24),
      );
      final next = LimitReview(
        LimitOpen(live.open.session, _context(entries: [entry])),
        live.request,
        live.attempt,
        live.check,
      ).next(const LimitConfirmPressed());
      expect(
        (next.state as LimitCreating).confirm,
        isA<ConfirmVerifying<LimitOrderRequest, LimitOrder>>(),
      );
    });
  });

  group('create', () {
    test('an unknown outcome re-reads and never sends again', () {
      final unknown = _creating.next(
        const LimitConfirmChanged(
          ConfirmAnswered(
            1,
            GateAdmitted(Err(ExchangeWriteOutcomeUnknownFailure('lost'))),
          ),
        ),
      );
      expect(
        (unknown.state as LimitCreating).confirm,
        isA<ConfirmVerifying<LimitOrderRequest, LimitOrder>>(),
      );
      expect(unknown.effects.single, isA<LimitConfirmEffect>());
      for (final event in const [
        LimitConfirmPressed(),
        LimitRetryPressed(),
        LimitBackPressed(),
      ]) {
        expect(
          identical(unknown.state.next(event).state, unknown.state),
          isTrue,
        );
      }
    });

    test('the re-read finds the created order by what was sent', () {
      final request = (_live as LimitReview).request;
      final order = LimitOrder(
        id: 'lo-9',
        number: 'LO-9',
        fiatAmount: 200,
        currencyCode: 'CAD',
        limitPrice: request.target.limitPrice,
        estimatedBtcAmount: 0.002,
        status: LimitOrderStatus.active,
        createdAt: DateTime.utc(2026, 11, 24),
        expiresAt: DateTime.utc(2026, 12, 24),
        address: limitBitcoinAddress,
      );
      expect(
        limitOrderCreateCheck(request, Ok([limitOrder(), order])),
        isA<ConfirmSeenApplied<LimitOrder>>().having(
          (c) => c.confirmed,
          'order',
          order,
        ),
      );
      expect(
        limitOrderCreateCheck(request, Ok([limitOrder()])),
        isA<ConfirmSeenNotApplied<LimitOrder>>(),
      );
    });

    test('Back from a refused create ends the flow', () {
      final refused = _creating
          .next(
            const LimitConfirmChanged(
              ConfirmAnswered(
                1,
                GateAdmitted(
                  Err(
                    ExchangeWriteRefusedFailure(
                      ExchangeRefusal(apiCode: 'ERR_ORDTRG_LOMAX429'),
                    ),
                  ),
                ),
              ),
            ),
          )
          .state;
      expect(
        (refused as LimitCreating).confirm,
        isA<ConfirmFailed<LimitOrderRequest, LimitOrder>>(),
      );
      expect(refused.next(const LimitBackPressed()).state, isA<LimitClosed>());
    });

    test('the done page leaves with the order, and can open it', () {
      expect(
        _doneState.next(const LimitViewOrderPressed()).state,
        isA<LimitClosed>()
            .having((s) => s.openDetails, 'openDetails', isTrue)
            .having((s) => s.created?.id, 'created', 'lo-1'),
      );
    });
  });
}
