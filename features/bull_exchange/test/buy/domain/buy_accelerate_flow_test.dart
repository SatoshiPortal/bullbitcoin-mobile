import 'package:bull_exchange/src/buy/domain/buy_accelerate_flow.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_test/flutter_test.dart';

import '../buy_fixtures.dart';

import 'package:primitives/primitives.dart';

final _order = buyOrder(status: OrderStatus.inProgress);
const _fee = AccelerateFee(satPerVbyte: 2.5, sats: 350, fiatPerBitcoin: 50000);
final _quote = AccelerateQuote(_order, _fee, const []);

AccelerateFlowNext _apply(
  AccelerateFlowState state,
  List<AccelerateFlowEvent> events,
) {
  var next = AccelerateFlowNext.stay(state);
  for (final event in events) {
    next = next.state.next(event);
  }
  return next;
}

final _loading = accelerateFlowStart(buySession, 'b-1').state;
final _ready = _apply(_loading, [AccelerateLoaded(1, Ok(_quote))]).state;
final _confirming = _apply(_ready, const [AccelerateConfirmPressed()]).state;
final _accelerated = buyOrder(status: OrderStatus.inProgress);
final _done = _apply(_confirming, [
  AccelerateConfirmChanged(ConfirmAnswered(1, buyDone(_accelerated))),
]).state;

final _states = <String, AccelerateFlowState>{
  'loading': _loading,
  'ready': _ready,
  'confirming': _confirming,
  'done': _done,
  'sessionEnded': const AccelerateSessionEnded(),
  'closed': const AccelerateClosed(),
};

final _events = <String, AccelerateFlowEvent>{
  'loaded': AccelerateLoaded(1, Ok(_quote)),
  'retry': const AccelerateRetryPressed(),
  'confirmPressed': const AccelerateConfirmPressed(),
  'confirm': AccelerateConfirmChanged(
    ConfirmAnswered(1, buyDone(_accelerated)),
  ),
  'back': const AccelerateBackPressed(),
  'donePressed': const AccelerateDonePressed(),
  'session': const AccelerateSessionChanged(buyOtherSession),
};

const _moves = <(String, String), Type>{
  ('loading', 'loaded'): AccelerateReady,
  ('loading', 'back'): AccelerateClosed,
  ('loading', 'donePressed'): AccelerateClosed,
  ('loading', 'session'): AccelerateSessionEnded,
  ('ready', 'confirmPressed'): AccelerateConfirming,
  ('ready', 'back'): AccelerateClosed,
  ('ready', 'donePressed'): AccelerateClosed,
  ('ready', 'session'): AccelerateSessionEnded,
  ('confirming', 'confirm'): AccelerateDone,
  ('confirming', 'session'): AccelerateSessionEnded,
  ('done', 'back'): AccelerateClosed,
  ('done', 'donePressed'): AccelerateClosed,
  ('done', 'session'): AccelerateSessionEnded,
  ('sessionEnded', 'back'): AccelerateClosed,
  ('sessionEnded', 'donePressed'): AccelerateClosed,
};

AccelerateConfirmState _confirmOf(AccelerateFlowState state) =>
    (state as AccelerateConfirming).confirm;

void main() {
  test('the sample states are the ones they name', () {
    expect(_loading, isA<AccelerateLoading>());
    expect(_ready, isA<AccelerateReady>());
    expect(_confirming, isA<AccelerateConfirming>());
    expect(_done, isA<AccelerateDone>());
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
    final reached = <Type>{
      accelerateFlowStart(buySession, 'b-1').state.runtimeType,
    };
    for (final state in _states.values) {
      reached.add(state.runtimeType);
      for (final event in _events.values) {
        reached.add(state.next(event).state.runtimeType);
      }
    }
    expect(reached, {
      AccelerateLoading,
      AccelerateReady,
      AccelerateConfirming,
      AccelerateDone,
      AccelerateSessionEnded,
      AccelerateClosed,
    });
  });

  test('no session has ended; a session loads the order', () {
    expect(
      accelerateFlowStart(null, 'b-1').state,
      isA<AccelerateSessionEnded>(),
    );
    expect(accelerateFlowStart(buySession, 'b-1').effects, [
      const AccelerateLoad('b-1', 1),
    ]);
  });

  test('a failed load keeps a Retry that loads again (BUY-6)', () {
    final failed = _apply(_loading, const [
      AccelerateLoaded(
        1,
        Err(ExchangeUnreachableFailure('down', isNetwork: true)),
      ),
    ]).state;
    expect(
      (failed as AccelerateLoading).load,
      isA<ContextFailed<AccelerateQuote>>(),
    );
    expect(failed.next(const AccelerateRetryPressed()).effects, [
      const AccelerateLoad('b-1', 2),
    ]);
  });

  test('Confirm express sends the accelerate once', () {
    final next = _ready.next(const AccelerateConfirmPressed());
    expect(next.effects, [
      const AccelerateConfirmEffect(ConfirmSend(AccelerateTarget('b-1'), 1)),
    ]);
    expect(
      identical(
        _confirming.next(const AccelerateConfirmPressed()).state,
        _confirming,
      ),
      isTrue,
    );
  });

  test('an open accelerate entry starts in Verifying', () {
    final entry = UnknownWrite(
      id: 'u',
      kind: UnknownWriteKind.accelerate,
      environment: ExchangeEnvironment.mainnet,
      orderId: 'b-1',
      request: const {},
      recordedAt: DateTime.utc(2026, 11, 24),
    );
    final ready = _apply(_loading, [
      AccelerateLoaded(1, Ok(AccelerateQuote(_order, _fee, [entry]))),
    ]).state;
    expect(
      _confirmOf(ready.next(const AccelerateConfirmPressed()).state),
      isA<ConfirmVerifying<AccelerateTarget, BuyOrder>>(),
    );
  });

  test('an unknown accelerate is never sent again', () {
    final verifying = _apply(_confirming, const [
      AccelerateConfirmChanged(
        ConfirmAnswered(
          1,
          GateAdmitted(Err(ExchangeWriteOutcomeUnknownFailure('lost'))),
        ),
      ),
    ]).state;
    final pending = _apply(verifying, [
      AccelerateConfirmChanged(
        ConfirmVerified(1, accelerateConfirmCheck(Ok(_order))),
      ),
    ]).state;
    expect(
      _confirmOf(pending),
      isA<ConfirmUnverified<AccelerateTarget, BuyOrder>>(),
    );
    expect(
      identical(pending.next(const AccelerateConfirmPressed()).state, pending),
      isTrue,
    );
    expect(
      pending.next(const AccelerateBackPressed()).state,
      const AccelerateClosed(),
    );
  });

  test('an unbatched order after an unknown outcome was accelerated', () {
    final unbatched = _order.copyWith(unbatchedBuyOnchainFees: 0.00001);
    expect(
      accelerateConfirmCheck(Ok(unbatched)),
      isA<ConfirmSeenApplied<BuyOrder>>(),
    );
  });

  test('Back from a refused accelerate returns to the fee page', () {
    final failed = _apply(_confirming, const [
      AccelerateConfirmChanged(
        ConfirmAnswered(
          1,
          GateAdmitted(Err(ExchangeWriteRefusedFailure(ExchangeRefusal()))),
        ),
      ),
    ]).state;
    expect(
      _confirmOf(failed),
      isA<ConfirmFailed<AccelerateTarget, BuyOrder>>(),
    );
    expect(
      failed.next(const AccelerateBackPressed()).state,
      isA<AccelerateReady>(),
    );
    expect(failed.next(const AccelerateConfirmPressed()).effects, [
      const AccelerateConfirmEffect(ConfirmSend(AccelerateTarget('b-1'), 2)),
    ]);
  });
}
