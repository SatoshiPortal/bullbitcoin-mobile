import 'package:bull_exchange/src/withdraw/domain/withdraw_flow.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../recipients/recipient_fixture.dart';
import '../withdraw_fixtures.dart' as fx;

import 'package:primitives/primitives.dart';

const _session = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 1,
  sessionId: 'a',
);
const _other = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 2,
  sessionId: 'b',
);

final _summary = UserSummary(
  userNumber: 7,
  groups: const [],
  profile: const UserProfile(firstName: 'Ada', lastName: 'Lovelace'),
  email: 'ada@example.com',
  balances: const [UserBalance(amount: 100, currencyCode: 'CAD')],
  currency: 'CAD',
  dca: const UserDca(isActive: false),
  autoBuy: const UserAutoBuy(
    isActive: false,
    addresses: UserAutoBuyAddresses(),
  ),
);

WithdrawContext _context([List<UnknownWrite> entries = const []]) =>
    WithdrawContext(_summary, entries);

final _ctx = _context();

WithdrawOrder _order({OrderStatus status = OrderStatus.awaitingConfirmation}) =>
    Order.withdraw(
      orderId: 'w-1',
      orderType: OrderType.withdraw,
      message: OrderMessage(code: '', message: ''),
      orderNumber: 1,
      payinAmount: 10,
      payinCurrency: 'CAD',
      payoutAmount: 10,
      payoutCurrency: 'CAD',
      payinMethod: OrderPaymentMethod.cadBalance,
      payoutMethod: OrderPaymentMethod.eTransfer,
      orderStatus: status,
      payinStatus: OrderPayinStatus.notStarted,
      payoutStatus: OrderPayoutStatus.notStarted,
      createdAt: DateTime.utc(2026, 11, 24),
      isTestnet: false,
    ) as WithdrawOrder;

final _bank = recipientFixture(
  'r-bank',
  RecipientType.bankTransferCad,
  isOwner: true,
).recipient;
final _interac = recipientFixture(
  'r-interac',
  RecipientType.interacEmailCad,
  isOwner: true,
  securityQuestion: 'Pet name?',
  securityAnswer: 'Rex',
).recipient;
final _thirdParty = recipientFixture(
  'r-third',
  RecipientType.bankTransferCad,
  isOwner: false,
).recipient;

WithdrawFlowNext _apply(
  WithdrawFlowState state,
  List<WithdrawFlowEvent> events,
) {
  var next = WithdrawFlowNext.stay(state);
  for (final event in events) {
    next = next.state.next(event);
  }
  return next;
}

GateAdmitted<Result<T, ExchangeWriteFailure>> _done<T>(T value) =>
    GateAdmitted(Ok(value));

final _loading = withdrawFlowStart(_session).state;
final _amount = _apply(_loading, [
  WithdrawContextLoaded(1, Ok(_ctx)),
  const WithdrawAmountChanged(
    AmountRateArrived(ExchangeCatalog.cad, Ok(50000.0)),
  ),
]).state;
final _recipient = _apply(_amount, const [
  WithdrawAmountChanged(AmountTyped('10')),
  WithdrawAmountChanged(AmountContinuePressed()),
]).state;
final _requirements = _apply(_recipient, [
  WithdrawRecipientPicked(_interac),
]).state;
final _ordering = _apply(_recipient, [WithdrawRecipientPicked(_bank)]).state;
final _review = _apply(_ordering, [
  WithdrawOrderChanged(OrderCreateAnswered(1, _done(_order()))),
]).state;
final _confirming = _apply(_review, const [WithdrawConfirmPressed()]).state;
final _doneState = _apply(_confirming, [
  WithdrawConfirmChanged(
    ConfirmAnswered(1, _done(_order(status: OrderStatus.inProgress))),
  ),
]).state;
const _sessionEnded = WithdrawSessionEnded();
const _closedState = WithdrawClosed();

final _states = <String, WithdrawFlowState>{
  'loading': _loading,
  'amount': _amount,
  'recipient': _recipient,
  'requirements': _requirements,
  'ordering': _ordering,
  'review': _review,
  'confirming': _confirming,
  'done': _doneState,
  'sessionEnded': _sessionEnded,
  'closed': _closedState,
};

final _events = <String, WithdrawFlowEvent>{
  'contextLoaded': WithdrawContextLoaded(1, Ok(_ctx)),
  'retry': const WithdrawRetryPressed(),
  'amount': const WithdrawAmountChanged(AmountTyped('5')),
  'picked': WithdrawRecipientPicked(_bank),
  'requirements': const WithdrawRequirementsChanged(
    RequirementInteracEvent(InteracQuestionTyped('Colour?')),
  ),
  'order': WithdrawOrderChanged(OrderCreateAnswered(1, _done(_order()))),
  'confirmPressed': const WithdrawConfirmPressed(),
  'confirm': WithdrawConfirmChanged(
    ConfirmAnswered(1, _done(_order(status: OrderStatus.inProgress))),
  ),
  'back': const WithdrawBackPressed(),
  'donePressed': const WithdrawDonePressed(),
  'visibility': const WithdrawVisibilityChanged(visible: false),
  'session': const WithdrawSessionChanged(_other),
};

/// Every (state, event) pair that is not a stay, and the state it leads to.
const _moves = <(String, String), Type>{
  ('loading', 'contextLoaded'): WithdrawAmount,
  ('loading', 'back'): WithdrawClosed,
  ('loading', 'donePressed'): WithdrawClosed,
  ('loading', 'session'): WithdrawSessionEnded,
  ('amount', 'amount'): WithdrawAmount,
  ('amount', 'back'): WithdrawClosed,
  ('amount', 'session'): WithdrawSessionEnded,
  ('recipient', 'picked'): WithdrawOrdering,
  ('recipient', 'back'): WithdrawAmount,
  ('recipient', 'session'): WithdrawSessionEnded,
  ('requirements', 'requirements'): WithdrawRequirements,
  ('requirements', 'back'): WithdrawRecipient,
  ('requirements', 'session'): WithdrawSessionEnded,
  ('ordering', 'order'): WithdrawReview,
  ('ordering', 'session'): WithdrawSessionEnded,
  ('review', 'confirmPressed'): WithdrawConfirming,
  ('review', 'back'): WithdrawRecipient,
  ('review', 'session'): WithdrawSessionEnded,
  ('confirming', 'confirm'): WithdrawDone,
  ('confirming', 'session'): WithdrawSessionEnded,
  ('done', 'back'): WithdrawClosed,
  ('done', 'donePressed'): WithdrawClosed,
  ('done', 'session'): WithdrawSessionEnded,
  ('sessionEnded', 'back'): WithdrawClosed,
  ('sessionEnded', 'donePressed'): WithdrawClosed,
};

void main() {
  test('the sample states are the ones they name', () {
    expect(_loading, isA<WithdrawLoading>());
    expect(_amount, isA<WithdrawAmount>());
    expect(
      (_amount as WithdrawAmount).amount,
      isA<AmountEditing>().having((s) => s.quote, 'quote', isA<RateReady>()),
    );
    expect(_recipient, isA<WithdrawRecipient>());
    expect(_requirements, isA<WithdrawRequirements>());
    expect(_ordering, isA<WithdrawOrdering>());
    expect(_review, isA<WithdrawReview>());
    expect(_confirming, isA<WithdrawConfirming>());
    expect(_doneState, isA<WithdrawDone>());
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
    final reached = <Type>{withdrawFlowStart(_session).state.runtimeType};
    final frontier = [..._states.values];
    for (final state in frontier) {
      reached.add(state.runtimeType);
      for (final event in _events.values) {
        reached.add(state.next(event).state.runtimeType);
      }
    }
    expect(reached, {
      WithdrawLoading,
      WithdrawAmount,
      WithdrawRecipient,
      WithdrawRequirements,
      WithdrawOrdering,
      WithdrawReview,
      WithdrawConfirming,
      WithdrawDone,
      WithdrawSessionEnded,
      WithdrawClosed,
    });
  });

  group('start and load', () {
    test('no session has ended; a session loads the account', () {
      expect(withdrawFlowStart(null).state, isA<WithdrawSessionEnded>());
      expect(withdrawFlowStart(_session).effects, [
        const WithdrawLoadContext(1),
      ]);
    });

    test('a failed load has a Retry that loads again', () {
      final failed = _loading.next(
        const WithdrawContextLoaded(
          1,
          Err(ExchangeUnreachableFailure('down', isNetwork: true)),
        ),
      );
      expect(
        (failed.state as WithdrawLoading).load,
        isA<ContextFailed<WithdrawContext>>(),
      );
      final retried = failed.state.next(const WithdrawRetryPressed());
      expect(retried.effects, [const WithdrawLoadContext(2)]);
    });

    test('the amount step fetches the rate of the preferred market', () {
      final next = _loading.next(WithdrawContextLoaded(1, Ok(_ctx)));
      expect(next.effects, [const WithdrawFetchRate(ExchangeCatalog.cad)]);
    });

    test('an expired session on the load ends the flow', () {
      expect(
        _loading
            .next(
              const WithdrawContextLoaded(
                1,
                Err(
                  ExchangeSessionRejectedFailure(
                    ExchangeSessionRejection.server,
                  ),
                ),
              ),
            )
            .state,
        isA<WithdrawSessionEnded>(),
      );
    });
  });

  group('recipient', () {
    test('a recipient the filter refuses stays on the pick, named', () {
      final next = _recipient.next(WithdrawRecipientPicked(_thirdParty));
      expect(
        next.state,
        isA<WithdrawRecipient>().having(
          (s) => s.refused,
          'refused',
          _thirdParty,
        ),
      );
    });

    test('an Interac recipient asks the security answer, prefilled', () {
      final running = (_requirements as WithdrawRequirements).requirements;
      expect(
        running.current,
        isA<InteracStep>().having(
          (s) => s.state,
          'state',
          isA<InteracEditing>()
              .having((s) => s.question, 'question', 'Pet name?')
              .having((s) => s.answer, 'answer', 'Rex'),
        ),
      );
      final next = _apply(_requirements, const [
        WithdrawRequirementsChanged(
          RequirementInteracEvent(InteracContinuePressed()),
        ),
      ]);
      expect(next.state, isA<WithdrawOrdering>());
      final effect = next.effects.single as WithdrawOrderEffect;
      final send = effect.effect as OrderSendCreate<WithdrawRequest>;
      expect(send.request.payout.interacAnswer?.answer, 'Rex');
    });

    test('a Confidential SEPA recipient starts the virtual IBAN', () {
      final eur = WithdrawContext(
        _summary.copyWith(
          currency: 'EUR',
          balances: const [UserBalance(amount: 100, currencyCode: 'EUR')],
        ),
        const [],
      );
      final recipient = _apply(withdrawFlowStart(_session).state, [
        WithdrawContextLoaded(1, Ok(eur)),
        const WithdrawAmountChanged(
          AmountRateArrived(ExchangeCatalog.eur, Ok(50000.0)),
        ),
        const WithdrawAmountChanged(AmountTyped('10')),
        const WithdrawAmountChanged(AmountContinuePressed()),
      ]).state;
      expect(recipient, isA<WithdrawRecipient>());
      final sepa = recipientFixture(
        'r-sepa',
        RecipientType.confidentialSepaEur,
        isOwner: true,
      ).recipient;
      final next = recipient.next(WithdrawRecipientPicked(sepa));
      expect(
        (next.state as WithdrawRequirements).requirements.current,
        isA<VirtualIbanStep>(),
      );
      expect(
        (next.effects.single as WithdrawRequirementsEffect).effect,
        isA<RequirementVirtualIbanEffect>().having(
          (e) => e.effect,
          'effect',
          isA<VibanLoad>(),
        ),
      );
      // The CAD flow's filter does not admit a EUR recipient.
      expect(
        _recipient.next(WithdrawRecipientPicked(sepa)).state,
        isA<WithdrawRecipient>().having((s) => s.refused, 'refused', sepa),
      );
    });
  });

  group('order create', () {
    test('an unknown create re-reads, never creates again', () {
      final unknown = _ordering.next(
        const WithdrawOrderChanged(
          OrderCreateAnswered(
            1,
            GateAdmitted(Err(ExchangeWriteOutcomeUnknownFailure('timeout'))),
          ),
        ),
      );
      expect(
        (unknown.state as WithdrawOrdering).order,
        isA<OrderVerifying<WithdrawRequest, WithdrawOrder>>(),
      );
      expect(
        (unknown.effects.single as WithdrawOrderEffect).effect,
        isA<OrderFindCreated<WithdrawRequest>>(),
      );
      // The re-read found no such order: that cannot prove the create did not
      // apply, so the step stays unverified and Retry re-reads, never creates
      // again.
      final missing = unknown.state.next(
        const WithdrawOrderChanged(
          OrderFindAnswered(1, Err(ExchangeMissingFailure())),
        ),
      );
      expect(
        (missing.state as WithdrawOrdering).order,
        isA<OrderUnverified<WithdrawRequest, WithdrawOrder>>().having(
          (o) => o.problem,
          'problem',
          isA<ReadProblemMissing>(),
        ),
      );
      final retried = missing.state.next(const WithdrawRetryPressed());
      expect(
        (retried.effects.single as WithdrawOrderEffect).effect,
        isA<OrderFindCreated<WithdrawRequest>>(),
      );
      expect(
        missing.state.next(const WithdrawBackPressed()).state,
        isA<WithdrawRecipient>(),
      );
    });

    // An amount refusal goes back to the amount instead (see 'an order
    // limit refusal goes back to the amount with the limit').
    test('a refused create shows the refusal; Retry sends again', () {
      final refused = _ordering.next(
        const WithdrawOrderChanged(
          OrderCreateAnswered(
            1,
            GateAdmitted(
              Err(
                ExchangeWriteRefusedFailure(ExchangeRefusal(rpcCode: -32000)),
              ),
            ),
          ),
        ),
      );
      expect(
        (refused.state as WithdrawOrdering).order,
        isA<OrderCreateFailed<WithdrawRequest, WithdrawOrder>>(),
      );
      final retried = refused.state.next(const WithdrawRetryPressed());
      expect(
        (retried.effects.single as WithdrawOrderEffect).effect,
        isA<OrderSendCreate<WithdrawRequest>>().having(
          (e) => e.attempt,
          'attempt',
          2,
        ),
      );
    });

    test('the journaled create names the withdrawal, amount and recipient', () {
      final send =
          ((_ordering as WithdrawOrdering).order
                  as OrderCreating<WithdrawRequest, WithdrawOrder>)
              .request;
      expect(send.journal.toRequest(), {
        'orderType': 'withdraw',
        'amount': '10.0',
        'amountKind': 'fiat',
        'currency': 'CAD',
        'recipientId': 'r-bank',
      });
    });
  });

  group('server confirm (WD-1, WD-2, WD-3)', () {
    test('Confirm sends once; a second press while confirming is a stay', () {
      final next = _review.next(const WithdrawConfirmPressed());
      expect(
        (next.effects.single as WithdrawConfirmEffect).effect,
        isA<ConfirmSend<WithdrawConfirmTarget>>(),
      );
      final again = next.state.next(const WithdrawConfirmPressed());
      expect(identical(again.state, next.state), isTrue);
      expect(again.effects, isEmpty);
    });

    test('an unknown confirm re-reads the order; not applied offers Retry; '
        'Back then leaves the flow', () {
      final unknown = _confirming.next(
        const WithdrawConfirmChanged(
          ConfirmAnswered(
            1,
            GateAdmitted(Err(ExchangeWriteOutcomeUnknownFailure('lost'))),
          ),
        ),
      );
      expect(
        (unknown.effects.single as WithdrawConfirmEffect).effect,
        isA<ConfirmVerify<WithdrawConfirmTarget>>(),
      );
      expect(
        unknown.state.next(const WithdrawBackPressed()).state,
        same(unknown.state),
      );
      final notApplied = unknown.state.next(
        WithdrawConfirmChanged(
          ConfirmVerified(1, withdrawConfirmCheck(Ok(_order()))),
        ),
      );
      expect(
        (notApplied.state as WithdrawConfirming).confirm,
        isA<ConfirmFailed<WithdrawConfirmTarget, WithdrawOrder>>(),
      );
      expect(
        notApplied.state.next(const WithdrawBackPressed()).state,
        isA<WithdrawClosed>(),
      );
    });

    test('a re-read that finds it confirmed is done', () {
      final verifying = _confirming
          .next(
            const WithdrawConfirmChanged(
              ConfirmAnswered(
                1,
                GateAdmitted(Err(ExchangeWriteOutcomeUnknownFailure('lost'))),
              ),
            ),
          )
          .state;
      expect(
        verifying
            .next(
              WithdrawConfirmChanged(
                ConfirmVerified(
                  1,
                  withdrawConfirmCheck(
                    Ok(_order(status: OrderStatus.completed)),
                  ),
                ),
              ),
            )
            .state,
        isA<WithdrawDone>(),
      );
    });

    test('an open journal entry for the order starts in Verifying', () {
      final entry = UnknownWrite(
        id: 'j-1',
        kind: UnknownWriteKind.withdrawConfirm,
        environment: ExchangeEnvironment.mainnet,
        orderId: 'w-1',
        request: const {},
        recordedAt: DateTime.utc(2026, 11, 24),
      );
      final review = _review as WithdrawReview;
      final withEntry = WithdrawReview(
        WithdrawOpen(_session, _context([entry])),
        review.amount,
        review.recipient,
        review.order,
      );
      final next = withEntry.next(const WithdrawConfirmPressed());
      expect(
        (next.state as WithdrawConfirming).confirm,
        isA<ConfirmVerifying<WithdrawConfirmTarget, WithdrawOrder>>(),
      );
      expect(
        (next.effects.single as WithdrawConfirmEffect).effect,
        isA<ConfirmVerify<WithdrawConfirmTarget>>(),
      );
    });
  });

  test('withdrawConfirmCheck names every order status', () {
    for (final status in OrderStatus.values) {
      final check = withdrawConfirmCheck(Ok(_order(status: status)));
      switch (status) {
        case OrderStatus.inProgress || OrderStatus.completed:
          expect(check, isA<ConfirmSeenApplied<WithdrawOrder>>());
        case OrderStatus.unknown:
          expect(check, isA<ConfirmCheckFailed<WithdrawOrder>>());
        case OrderStatus.awaitingConfirmation ||
            OrderStatus.canceled ||
            OrderStatus.expired ||
            OrderStatus.orderExpired ||
            OrderStatus.rejected ||
            OrderStatus.failed:
          expect(check, isA<ConfirmSeenNotApplied<WithdrawOrder>>());
      }
    }
    expect(
      withdrawConfirmCheck(
        const Err(
          ExchangeSessionRejectedFailure(ExchangeSessionRejection.server),
        ),
      ),
      isA<ConfirmCheckSessionRejected<WithdrawOrder>>(),
    );
    expect(
      withdrawConfirmCheck(
        const Err(ExchangeUnreachableFailure('x', isNetwork: true)),
      ),
      isA<ConfirmCheckFailed<WithdrawOrder>>(),
    );
  });

  test('an order limit refusal goes back to the amount with the limit', () {
    final ordering = fx.applyWithdraw(fx.withdrawRecipientState, [
      WithdrawRecipientPicked(fx.withdrawBankRecipient),
    ]);
    expect(ordering, isA<WithdrawOrdering>());
    final back = fx.applyWithdraw(ordering, [
      WithdrawOrderChanged(
        OrderCreateAnswered(
          1,
          GateAdmitted(
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
      ),
    ]);
    expect(back, isA<WithdrawAmount>());
    final amount = (back as WithdrawAmount).amount as AmountEditing;
    expect(amount.draft.text, '10');
    expect(amount.problem, const AmountBelowMinimum(20));
    final again = fx.applyWithdraw(back, const [
      WithdrawAmountChanged(AmountContinuePressed()),
    ]);
    expect(
      ((again as WithdrawAmount).amount as AmountEditing).problem,
      const AmountBelowMinimum(20),
    );
    expect(
      fx.applyWithdraw(again, const [
        WithdrawAmountChanged(AmountTyped('25')),
        WithdrawAmountChanged(AmountContinuePressed()),
      ]),
      isA<WithdrawRecipient>(),
    );
  });
}
