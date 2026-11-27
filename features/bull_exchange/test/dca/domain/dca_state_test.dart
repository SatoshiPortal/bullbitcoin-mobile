import 'package:bull_exchange/src/dca/domain/dca_state.dart';
import 'package:bull_exchange/src/dca/domain/dca_event.dart';
import 'package:bull_exchange/src/dca/domain/dca_effect.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_test/flutter_test.dart';

import '../dca_fixtures.dart';

import 'package:primitives/primitives.dart';

final _states = <String, DcaFlowState>{
  'loading': dcaLoadingState,
  'setup': dcaSetupState,
  'payout': dcaPayoutState,
  'review': dcaReviewState,
  'confirming': dcaConfirmingState,
  'done': dcaDoneState,
  'sessionEnded': const DcaSessionEnded(),
  'closed': const DcaClosed(),
};

final _events = <String, DcaFlowEvent>{
  'contextLoaded': DcaContextLoaded(1, Ok(dcaContext)),
  'retry': const DcaRetryPressed(),
  'amount': const DcaAmountChanged(AmountTyped('5')),
  'frequency': const DcaFrequencyPicked(DcaBuyFrequency.daily),
  'continue': const DcaContinuePressed(),
  'fundingReturned': const DcaFundingReturned(),
  'kycReturned': const DcaKycReturned(),
  'detourLoaded': DcaDetourLoaded(Ok(dcaContext)),
  'payout': const DcaPayoutChosen(dcaPayout),
  'walletsReturned': const DcaDefaultWalletsReturned(),
  'walletsLoaded': const DcaDefaultWalletsLoaded(0, Ok(DefaultWallets())),
  'confirmPressed': const DcaConfirmPressed(),
  'confirm': DcaConfirmChanged(ConfirmAnswered(1, GateAdmitted(Ok(dcaPlan)))),
  'back': const DcaBackPressed(),
  'donePressed': const DcaDonePressed(),
  'session': const DcaSessionChanged(buyOtherSession),
};

const _moves = <(String, String), Type>{
  ('loading', 'contextLoaded'): DcaSetup,
  ('loading', 'back'): DcaClosed,
  ('loading', 'donePressed'): DcaClosed,
  ('loading', 'session'): DcaSessionEnded,
  ('setup', 'amount'): DcaSetup,
  ('setup', 'frequency'): DcaSetup,
  ('setup', 'continue'): DcaSetup,
  ('setup', 'back'): DcaClosed,
  ('setup', 'session'): DcaSessionEnded,
  ('payout', 'payout'): DcaReview,
  ('payout', 'walletsReturned'): DcaPayoutPick,
  ('payout', 'walletsLoaded'): DcaPayoutPick,
  ('payout', 'back'): DcaSetup,
  ('payout', 'session'): DcaSessionEnded,
  ('review', 'confirmPressed'): DcaConfirming,
  ('review', 'back'): DcaPayoutPick,
  ('review', 'session'): DcaSessionEnded,
  ('confirming', 'confirm'): DcaDone,
  ('confirming', 'session'): DcaSessionEnded,
  ('done', 'back'): DcaClosed,
  ('done', 'donePressed'): DcaClosed,
  ('done', 'session'): DcaSessionEnded,
  ('sessionEnded', 'back'): DcaClosed,
  ('sessionEnded', 'donePressed'): DcaClosed,
};

void main() {
  test('the sample states are the ones they name', () {
    expect(dcaLoadingState, isA<DcaLoading>());
    expect(
      (dcaSetupState as DcaSetup).amount,
      isA<AmountEditing>().having((s) => s.quote, 'quote', isA<RateReady>()),
    );
    expect(dcaPayoutState, isA<DcaPayoutPick>());
    expect(dcaReviewState, isA<DcaReview>());
    expect(dcaConfirmingState, isA<DcaConfirming>());
    expect(dcaDoneState, isA<DcaDone>());
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
    final reached = <Type>{dcaFlowStart(buySession).state.runtimeType};
    for (final state in _states.values) {
      reached.add(state.runtimeType);
      for (final event in _events.values) {
        reached.add(state.next(event).state.runtimeType);
      }
    }
    expect(reached, {
      DcaLoading,
      DcaSetup,
      DcaPayoutPick,
      DcaReview,
      DcaConfirming,
      DcaDone,
      DcaSessionEnded,
      DcaClosed,
    });
  });

  test('no session has ended; a session loads the account', () {
    expect(dcaFlowStart(null).state, isA<DcaSessionEnded>());
    expect(dcaFlowStart(buySession).effects, [const DcaLoadContext(1)]);
  });

  test('a failed load has a Retry that loads again', () {
    final failed = dcaLoadingState
        .next(
          const DcaContextLoaded(
            1,
            Err(ExchangeUnreachableFailure('down', isNetwork: true)),
          ),
        )
        .state;
    expect((failed as DcaLoading).load, isA<ContextFailed<DcaContext>>());
    expect(failed.next(const DcaRetryPressed()).effects, [
      const DcaLoadContext(2),
    ]);
  });

  test('Continue without a frequency says so and keeps the amount', () {
    final next = applyDca(dcaSetupState, const [
      DcaAmountChanged(AmountTyped('10')),
      DcaContinuePressed(),
    ]).state;
    expect(
      next,
      isA<DcaSetup>()
          .having((s) => s.frequencyMissing, 'missing', isTrue)
          .having(
            (s) => s.amount,
            'amount',
            isA<AmountEditing>().having((a) => a.draft.text, 'text', '10'),
          ),
    );
  });

  test('an amount over the balance is the funding detour, back to the '
      'same draft', () {
    final detour = applyDca(dcaSetupState, const [
      DcaAmountChanged(AmountTyped('500')),
      DcaFrequencyPicked(DcaBuyFrequency.daily),
      DcaContinuePressed(),
    ]).state;
    expect((detour as DcaSetup).amount, isA<AmountFundingDetour>());
    final reload = detour.next(const DcaFundingReturned());
    expect(reload.effects, [const DcaReloadForDetour()]);
    final rich = dcaContextWith(
      summary: buySummaryWith(
        balances: const [UserBalance(amount: 1000, currencyCode: 'CAD')],
      ),
    );
    final back = reload.state.next(DcaDetourLoaded(Ok(rich))).state;
    expect(
      (back as DcaSetup).amount,
      isA<AmountEditing>().having((s) => s.draft.text, 'text', '500'),
    );
    expect(back.frequency, DcaBuyFrequency.daily);
  });

  test('a KYC level too low is the KYC detour; it returns to the draft', () {
    final low = dcaContextWith(summary: buySummaryWith(groups: const []));
    final detour = applyDca(dcaLoadingState, [
      DcaContextLoaded(1, Ok(low)),
      const DcaAmountChanged(
        AmountRateArrived(ExchangeCatalog.cad, Ok(50000.0)),
      ),
      const DcaAmountChanged(AmountTyped('10')),
      const DcaFrequencyPicked(DcaBuyFrequency.daily),
      const DcaContinuePressed(),
    ]).state;
    expect((detour as DcaSetup).amount, isA<AmountKycDetour>());
    final reload = detour.next(const DcaKycReturned());
    expect(reload.effects, [const DcaReloadForDetour()]);
    final back = reload.state.next(DcaDetourLoaded(Ok(dcaContext))).state;
    expect(
      (back as DcaSetup).amount,
      isA<AmountEditing>().having((s) => s.draft.text, 'text', '10'),
    );
    expect(back.frequency, DcaBuyFrequency.daily);
  });

  test('no funded balance has no market; funding reloads', () {
    final empty = dcaContextWith(summary: buySummaryWith(balances: const []));
    final setup = dcaLoadingState.next(DcaContextLoaded(1, Ok(empty))).state;
    expect((setup as DcaSetup).amount, isA<AmountNoMarket>());
    expect(setup.next(const DcaFundingReturned()).effects, [
      const DcaReloadForDetour(),
    ]);
  });

  test('the default wallets re-read after the editor; a stale answer is '
      'dropped', () {
    final asked = applyDca(dcaPayoutState, const [
      DcaDefaultWalletsReturned(),
      DcaDefaultWalletsReturned(),
    ]);
    expect(asked.effects, [const DcaLoadDefaultWallets(2)]);
    final stale = asked.state.next(
      const DcaDefaultWalletsLoaded(1, Ok(DefaultWallets())),
    );
    expect(identical(stale.state, asked.state), isTrue);
    final fresh =
        asked.state
                .next(const DcaDefaultWalletsLoaded(2, Ok(DefaultWallets())))
                .state
            as DcaPayoutPick;
    expect(fresh.open.context.defaultAddressOf(BtcNetwork.bitcoin), isNull);
  });

  test('Back from the payout keeps the draft and the frequency', () {
    final back = dcaPayoutState.next(const DcaBackPressed()).state as DcaSetup;
    expect(back.frequency, DcaBuyFrequency.weekly);
    expect(
      back.amount,
      isA<AmountEditing>().having((s) => s.draft.text, 'text', '10'),
    );
  });

  test('Confirm sends the create once; pressed again it is a stay', () {
    expect(dcaReviewState.next(const DcaConfirmPressed()).effects, [
      DcaConfirmEffect(ConfirmSend(dcaPlan, 1)),
    ]);
    for (final event in const [DcaConfirmPressed(), DcaRetryPressed()]) {
      expect(
        identical(dcaConfirmingState.next(event).state, dcaConfirmingState),
        isTrue,
      );
    }
  });

  test('an open dcaCreate entry starts in Verifying', () {
    final entry = UnknownWrite(
      id: 'u',
      kind: UnknownWriteKind.dcaCreate,
      environment: ExchangeEnvironment.mainnet,
      request: const {'address': 'bc1qdefault'},
      recordedAt: DateTime.utc(2026, 11, 24),
    );
    final review = DcaReview(
      DcaOpen(buySession, dcaContextWith(openEntries: [entry])),
      dcaPlan,
    );
    expect(
      (review.next(const DcaConfirmPressed()).state as DcaConfirming).confirm,
      isA<ConfirmVerifying<DcaPlan, DcaPlan>>(),
    );
  });

  test('an unknown create re-reads the account, never creates again', () {
    final verifying = applyDca(dcaConfirmingState, const [
      DcaConfirmChanged(
        ConfirmAnswered(
          1,
          GateAdmitted(Err(ExchangeWriteOutcomeUnknownFailure('lost'))),
        ),
      ),
    ]);
    expect(verifying.effects, [DcaConfirmEffect(ConfirmVerify(dcaPlan, 1))]);
    final unverified = verifying.state
        .next(
          const DcaConfirmChanged(
            ConfirmVerified(1, ConfirmCheckFailed(ReadProblemMalformed())),
          ),
        )
        .state;
    expect(
      identical(unverified.next(const DcaConfirmPressed()).state, unverified),
      isTrue,
    );
    expect(unverified.next(const DcaBackPressed()).state, const DcaClosed());
  });

  test('the re-read: active at the plan address is applied', () {
    final active = buySummaryWith().copyWith(
      dca: const UserDca(isActive: true, address: 'bc1qdefault'),
    );
    expect(
      dcaConfirmCheck(dcaPlan, Ok(active)),
      isA<ConfirmSeenApplied<DcaPlan>>(),
    );
    expect(
      dcaConfirmCheck(dcaPlan, Ok(buySummaryWith())),
      isA<ConfirmSeenNotApplied<DcaPlan>>(),
    );
  });

  test('done turns the DCA preference on', () {
    expect(
      dcaConfirmingState
          .next(
            DcaConfirmChanged(ConfirmAnswered(1, GateAdmitted(Ok(dcaPlan)))),
          )
          .effects,
      [const DcaActivated()],
    );
  });

  test('a refused create goes back to the review on Back', () {
    final failed = applyDca(dcaConfirmingState, const [
      DcaConfirmChanged(
        ConfirmAnswered(
          1,
          GateAdmitted(Err(ExchangeWriteRefusedFailure(ExchangeRefusal()))),
        ),
      ),
    ]).state;
    expect(failed.next(const DcaBackPressed()).state, isA<DcaReview>());
  });
}
