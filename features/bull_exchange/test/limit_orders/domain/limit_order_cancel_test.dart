import 'package:bull_exchange/src/limit_orders/domain/limit_order_cancel.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';

import '../limit_order_fixtures.dart';

import 'package:primitives/primitives.dart';

final _active = limitOrder();
final _cancelled = limitOrder(status: LimitOrderStatus.cancelled);
final _executed = limitOrder(status: LimitOrderStatus.executed);

LimitCancelState _apply(LimitCancelState state, List<LimitCancelEvent> events) {
  var next = state;
  for (final event in events) {
    next = transitionLimitCancel(next, event).state;
  }
  return next;
}

final _idle = CancelIdle(_active);
final _sending = _apply(_idle, const [CancelPressed()]);
final _checking = _apply(_sending, const [
  CancelAnswered(1, CancelAnsweredUnsure()),
]);
final _unverified = _apply(_checking, const [
  CancelChecked(1, Err(ExchangeUnreachableFailure('down', isNetwork: true))),
]);
final _done = _apply(_sending, [
  CancelAnswered(1, CancelAnsweredOrder(_cancelled)),
]);
final _ended = _apply(_sending, const [
  CancelAnswered(1, CancelAnsweredSessionRejected()),
]);

final _states = <String, LimitCancelState>{
  'idle': _idle,
  'sending': _sending,
  'checking': _checking,
  'unverified': _unverified,
  'done': _done,
  'ended': _ended,
};

final _events = <String, LimitCancelEvent>{
  'pressed': const CancelPressed(),
  'answered': CancelAnswered(1, CancelAnsweredOrder(_cancelled)),
  'checked': CancelChecked(1, Ok(_cancelled)),
  'retry': const CancelRetryPressed(),
};

const _moves = <(String, String), Type>{
  ('idle', 'pressed'): CancelSending,
  ('sending', 'answered'): CancelDone,
  ('checking', 'checked'): CancelDone,
  ('unverified', 'retry'): CancelChecking,
};

void main() {
  test('the sample states are the ones they name', () {
    expect(_sending, isA<CancelSending>());
    expect(_checking, isA<CancelChecking>());
    expect(_unverified, isA<CancelUnverified>());
    expect(_done, isA<CancelDone>());
    expect(_ended, isA<CancelSessionEnded>());
  });

  group('every (state, event) pair', () {
    for (final MapEntry(key: stateName, value: state) in _states.entries) {
      for (final MapEntry(key: eventName, value: event) in _events.entries) {
        final expected = _moves[(stateName, eventName)];
        test('$stateName + $eventName', () {
          final next = transitionLimitCancel(state, event);
          if (expected == null) {
            expect(identical(next.state, state), isTrue, reason: '$next');
            expect(next.effects, isEmpty);
          } else {
            expect(next.state.runtimeType, expected);
          }
        });
      }
    }
  });

  test('every state is reachable', () {
    final reached = <Type>{};
    for (final state in _states.values) {
      reached.add(state.runtimeType);
      for (final event in _events.values) {
        reached.add(transitionLimitCancel(state, event).state.runtimeType);
      }
    }
    expect(reached, {
      CancelIdle,
      CancelSending,
      CancelChecking,
      CancelUnverified,
      CancelDone,
      CancelSessionEnded,
    });
  });

  test('Cancel sends once, with a new attempt each time', () {
    final next = transitionLimitCancel(_idle, const CancelPressed());
    expect(next.effects, [CancelSend(_active.id, 1)]);
    expect(
      identical(
        transitionLimitCancel(next.state, const CancelPressed()).state,
        next.state,
      ),
      isTrue,
    );
  });

  test('a non-active order offers no cancel', () {
    final idle = CancelIdle(_executed);
    expect(
      identical(transitionLimitCancel(idle, const CancelPressed()).state, idle),
      isTrue,
    );
  });

  test('an unsure answer re-reads; the re-read decides (LIM-3)', () {
    final next = transitionLimitCancel(
      _sending,
      const CancelAnswered(1, CancelAnsweredUnsure()),
    );
    expect(next.effects, [CancelRead(_active.id, 1)]);
    final executed = transitionLimitCancel(
      next.state,
      CancelChecked(1, Ok(_executed)),
    ).state;
    expect(
      executed,
      isA<CancelIdle>()
          .having((s) => s.order.status, 'status', LimitOrderStatus.executed)
          .having((s) => s.problem, 'problem', isA<CancelNotApplied>()),
    );
  });

  test('a gate refusal keeps the order and says why', () {
    final next = transitionLimitCancel(
      _sending,
      const CancelAnswered(
        1,
        CancelAnsweredGateRefused(WriteGateBusy(FinancialWriteKind.payin)),
      ),
    ).state;
    expect(
      next,
      isA<CancelIdle>().having(
        (s) => s.problem,
        'problem',
        isA<CancelGateProblem>(),
      ),
    );
    expect(transitionLimitCancel(next, const CancelPressed()).effects, [
      CancelSend(_active.id, 2),
    ]);
  });

  test('an answer for another attempt is a stay', () {
    expect(
      identical(
        transitionLimitCancel(
          _sending,
          CancelAnswered(2, CancelAnsweredOrder(_cancelled)),
        ).state,
        _sending,
      ),
      isTrue,
    );
  });

  test('only a sending or checking cancel holds Back', () {
    expect(_states.map((k, v) => MapEntry(k, limitCancelRunning(v))), {
      'idle': false,
      'sending': true,
      'checking': true,
      'unverified': false,
      'done': false,
      'ended': false,
    });
  });
}
