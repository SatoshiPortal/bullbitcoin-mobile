import 'package:bull_exchange/src/autobuy/domain/autobuy_state.dart';
import 'package:bull_exchange/src/autobuy/domain/autobuy_event.dart';
import 'package:bull_exchange/src/autobuy/domain/autobuy_effect.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_test/flutter_test.dart';

import '../autobuy_fixtures.dart';

import 'package:primitives/primitives.dart';

AutoBuyFlowState _apply(AutoBuyFlowState state, List<AutoBuyFlowEvent> events) {
  var next = state;
  for (final event in events) {
    next = next.next(event).state;
  }
  return next;
}

final _ctx = autoBuyContext();
final _loading = autoBuyFlowStart(autoBuySession).state;
final _intro = _apply(_loading, [AutoBuyContextLoaded(1, Ok(_ctx))]);
final _kyc = _apply(_loading, [
  AutoBuyContextLoaded(1, Ok(autoBuyContext(groups: const []))),
  const AutoBuyGetStartedPressed(),
]);
final _wallets = _apply(_intro, const [AutoBuyGetStartedPressed()]);
final _review = _apply(_wallets, const [
  AutoBuyWalletsContinued(autoBuyWallets),
]);
final _activating = _apply(_review, const [AutoBuyActivatePressed()]);
final _done = _apply(_activating, const [
  AutoBuyConfirmChanged(ConfirmAnswered(1, GateAdmitted(Ok(true)))),
]);
const _ended = AutoBuySessionEnded();
const _closed = AutoBuyClosed();

final _states = <String, AutoBuyFlowState>{
  'loading': _loading,
  'intro': _intro,
  'kyc': _kyc,
  'wallets': _wallets,
  'review': _review,
  'activating': _activating,
  'done': _done,
  'ended': _ended,
  'closed': _closed,
};

final _events = <String, AutoBuyFlowEvent>{
  'loaded': AutoBuyContextLoaded(1, Ok(_ctx)),
  'retry': const AutoBuyRetryPressed(),
  'back': const AutoBuyBackPressed(),
  'donePressed': const AutoBuyDonePressed(),
  'getStarted': const AutoBuyGetStartedPressed(),
  'kycReturned': const AutoBuyKycReturned(),
  'kycReloaded': AutoBuyKycReloaded(Ok(_ctx)),
  'walletsContinued': const AutoBuyWalletsContinued(autoBuyWallets),
  'activate': const AutoBuyActivatePressed(),
  'confirm': const AutoBuyConfirmChanged(
    ConfirmAnswered(1, GateAdmitted(Ok(true))),
  ),
  'session': const AutoBuySessionChanged(autoBuyOtherSession),
};

const _moves = <(String, String), Type>{
  ('loading', 'loaded'): AutoBuyIntro,
  ('loading', 'back'): AutoBuyClosed,
  ('loading', 'donePressed'): AutoBuyClosed,
  ('loading', 'session'): AutoBuySessionEnded,
  ('intro', 'back'): AutoBuyClosed,
  ('intro', 'getStarted'): AutoBuyWallets,
  ('intro', 'session'): AutoBuySessionEnded,
  ('kyc', 'back'): AutoBuyIntro,
  ('kyc', 'kycReturned'): AutoBuyKyc,
  ('kyc', 'session'): AutoBuySessionEnded,
  ('wallets', 'back'): AutoBuyIntro,
  ('wallets', 'walletsContinued'): AutoBuyReview,
  ('wallets', 'session'): AutoBuySessionEnded,
  ('review', 'back'): AutoBuyWallets,
  ('review', 'activate'): AutoBuyActivating,
  ('review', 'session'): AutoBuySessionEnded,
  ('activating', 'confirm'): AutoBuyDone,
  ('activating', 'session'): AutoBuySessionEnded,
  ('done', 'back'): AutoBuyClosed,
  ('done', 'donePressed'): AutoBuyClosed,
  ('done', 'session'): AutoBuySessionEnded,
  ('ended', 'back'): AutoBuyClosed,
  ('ended', 'donePressed'): AutoBuyClosed,
};

void main() {
  test('the sample states are the ones they name', () {
    expect(_intro, isA<AutoBuyIntro>());
    expect(_kyc, isA<AutoBuyKyc>());
    expect(_wallets, isA<AutoBuyWallets>());
    expect(_review, isA<AutoBuyReview>());
    expect(_activating, isA<AutoBuyActivating>());
    expect(_done, isA<AutoBuyDone>());
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
    final reached = <Type>{autoBuyFlowStart(autoBuySession).state.runtimeType};
    for (final state in _states.values) {
      reached.add(state.runtimeType);
      for (final event in _events.values) {
        reached.add(state.next(event).state.runtimeType);
      }
    }
    expect(reached, {
      AutoBuyLoading,
      AutoBuyIntro,
      AutoBuyKyc,
      AutoBuyWallets,
      AutoBuyReview,
      AutoBuyActivating,
      AutoBuyDone,
      AutoBuySessionEnded,
      AutoBuyClosed,
    });
  });

  test('a load failure is its own state with a Retry (AB-1)', () {
    final failed = _loading
        .next(
          const AutoBuyContextLoaded(
            1,
            Err(ExchangeUnreachableFailure('x', isNetwork: true)),
          ),
        )
        .state;
    expect(
      (failed as AutoBuyLoading).load,
      isA<ContextFailed<AutoBuyContext>>(),
    );
    expect(failed.next(const AutoBuyRetryPressed()).effects, [
      const AutoBuyLoadContext(2),
    ]);
  });

  test('a restricted account gets no way on', () {
    final restricted = _apply(_loading, [
      AutoBuyContextLoaded(
        1,
        Ok(
          autoBuyContext(
            groups: const ['KYC_IDENTITY_VERIFIED', 'RESTRICTED_FULL'],
          ),
        ),
      ),
    ]);
    expect((restricted as AutoBuyIntro).gate, isA<RestrictionRestricted>());
    expect(
      identical(
        restricted.next(const AutoBuyGetStartedPressed()).state,
        restricted,
      ),
      isTrue,
    );
  });

  test('KYC: returning reads the account again and passes when allowed', () {
    final returned = _kyc.next(const AutoBuyKycReturned());
    expect(returned.effects, [const AutoBuyReloadForKyc()]);
    expect(
      returned.state.next(AutoBuyKycReloaded(Ok(_ctx))).state,
      isA<AutoBuyWallets>(),
    );
    expect(
      returned.state
          .next(AutoBuyKycReloaded(Ok(autoBuyContext(groups: const []))))
          .state,
      isA<AutoBuyKyc>(),
    );
  });

  test('no saved wallet: Continue is a stay', () {
    expect(
      identical(
        _wallets.next(const AutoBuyWalletsContinued(DefaultWallets())).state,
        _wallets,
      ),
      isTrue,
    );
  });

  test(
    'an active account sees it is active, with Done and no Activate (AB-2)',
    () {
      final active = _apply(_loading, [
        AutoBuyContextLoaded(1, Ok(autoBuyContext(active: true))),
        const AutoBuyGetStartedPressed(),
        const AutoBuyWalletsContinued(autoBuyWallets),
      ]);
      expect((active as AutoBuyReview).alreadyActive, isTrue);
      expect(
        identical(active.next(const AutoBuyActivatePressed()).state, active),
        isTrue,
      );
      expect(
        active.next(const AutoBuyDonePressed()).state,
        isA<AutoBuyClosed>(),
      );
    },
  );

  test('Activate sends once; an unknown outcome re-reads, then verifies', () {
    final next = _review.next(const AutoBuyActivatePressed());
    expect(next.effects, [
      const AutoBuyConfirmEffect(ConfirmSend(AutoBuyTarget(enabled: true), 1)),
    ]);
    final unknown = next.state.next(
      const AutoBuyConfirmChanged(
        ConfirmAnswered(
          1,
          GateAdmitted(Err(ExchangeWriteOutcomeUnknownFailure('lost'))),
        ),
      ),
    );
    expect(unknown.effects, [
      const AutoBuyConfirmEffect(
        ConfirmVerify(AutoBuyTarget(enabled: true), 1),
      ),
    ]);
    expect(
      identical(
        unknown.state.next(const AutoBuyBackPressed()).state,
        unknown.state,
      ),
      isTrue,
    );
  });

  test(
    'an open AutoBuy preference save starts the activation in Verifying',
    () {
      final entry = UnknownWrite(
        id: 'e-1',
        kind: UnknownWriteKind.preferencesSave,
        environment: ExchangeEnvironment.mainnet,
        request: const {'autoBuyEnabled': 'true'},
        recordedAt: DateTime.utc(2026, 11, 24),
      );
      final other = UnknownWrite(
        id: 'e-2',
        kind: UnknownWriteKind.preferencesSave,
        environment: ExchangeEnvironment.mainnet,
        request: const {'language': 'FR'},
        recordedAt: DateTime.utc(2026, 11, 24),
      );
      expect(autoBuyEntries([entry, other]), [entry]);
      final review = _apply(_loading, [
        AutoBuyContextLoaded(1, Ok(autoBuyContext(entries: [entry]))),
        const AutoBuyGetStartedPressed(),
        const AutoBuyWalletsContinued(autoBuyWallets),
      ]);
      final next = review.next(const AutoBuyActivatePressed());
      expect(
        (next.state as AutoBuyActivating).confirm,
        isA<ConfirmVerifying<AutoBuyTarget, bool>>(),
      );
    },
  );

  test('the verify-after-write check reads the account', () {
    const on = AutoBuyTarget(enabled: true);
    expect(
      autoBuyCheck(on, Ok(autoBuySummary(active: true))),
      isA<ConfirmSeenApplied<bool>>(),
    );
    expect(
      autoBuyCheck(on, Ok(autoBuySummary())),
      isA<ConfirmSeenNotApplied<bool>>(),
    );
    expect(
      autoBuyCheck(
        on,
        const Err(
          ExchangeSessionRejectedFailure(ExchangeSessionRejection.server),
        ),
      ),
      isA<ConfirmCheckSessionRejected<bool>>(),
    );
  });
}
