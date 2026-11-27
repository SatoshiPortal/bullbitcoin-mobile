import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:test/test.dart';
import 'package:primitives/primitives.dart';

typedef _Next = StepNext<VirtualPayeeState, VirtualPayeeEffect>;

const _policy = VirtualPayeePolicy(
  fastPolls: 1,
  fastEvery: Duration(seconds: 1),
  every: Duration(seconds: 5),
  maxPolls: 3,
  maxDuration: Duration(minutes: 1),
);
const _refusal = ExchangeRefusal(rpcCode: -32000);
const _unreachable = ReadProblemUnreachable(isNetwork: true);

const _loading = PayeeLoading(1);
const _loadFailed = PayeeLoadFailed(1, _unreachable);
const _activating = PayeeActivating(1);
const _activateFailed = PayeeActivateFailed(1, WriteProblemRefused(_refusal));
const _pending = PayeePending(1, 1, 1, 0);
const _pendingLast = PayeePending(1, 1, 3, 2);
const _paused = PayeePaused(1, 1, 2, 0);
const _timedOut = PayeeTimedOut(1, 1, 4);
const _unknown = PayeeUnknownStatus(1);
const _active = PayeeActive();
const _declined = PayeeDeclined();
const _ended = PayeeSessionEnded();

const _states = <VirtualPayeeState>[
  _loading,
  _loadFailed,
  _activating,
  _activateFailed,
  _pending,
  _pendingLast,
  _paused,
  _timedOut,
  _unknown,
  _active,
  _declined,
  _ended,
];

const _events = <VirtualPayeeEvent>[
  PayeeLoaded(1, Ok(SepaVirtualPayeeStatus.active)), // 0
  PayeeLoaded(1, Ok(SepaVirtualPayeeStatus.absent)), // 1
  PayeeLoaded(1, Ok(SepaVirtualPayeeStatus.pending)), // 2
  PayeeLoaded(1, Ok(SepaVirtualPayeeStatus.unknown)), // 3
  PayeeLoaded(1, Err(ExchangeUnreachableFailure('down', isNetwork: true))), // 4
  PayeeLoaded(
    1,
    Err(ExchangeSessionRejectedFailure(ExchangeSessionRejection.server)),
  ), // 5
  PayeeLoaded(2, Ok(SepaVirtualPayeeStatus.active)), // 6
  PayeeActivated(1, Ok(SepaVirtualPayeeStatus.active)), // 7
  PayeeActivated(1, Ok(SepaVirtualPayeeStatus.pending)), // 8
  PayeeActivated(1, Err(ExchangeWriteOutcomeUnknownFailure('timeout'))), // 9
  PayeeActivated(1, Err(ExchangeWriteRefusedFailure(_refusal))), // 10
  PayeeActivated(
    1,
    Err(ExchangeSessionRejectedFailure(ExchangeSessionRejection.server)),
  ), // 11
  PayeePolled(1, Ok(SepaVirtualPayeeStatus.pending)), // 12
  PayeePolled(1, Ok(SepaVirtualPayeeStatus.active)), // 13
  PayeePolled(1, Ok(SepaVirtualPayeeStatus.absent)), // 14
  PayeePolled(1, Ok(SepaVirtualPayeeStatus.unknown)), // 15
  PayeePolled(
    3,
    Err(ExchangeUnreachableFailure('down', isNetwork: true)),
  ), // 16
  PayeeVisibilityChanged(visible: false), // 17
  PayeeVisibilityChanged(visible: true), // 18
  PayeeDeadlinePassed(1), // 19
  PayeeDeadlinePassed(7), // 20
  PayeeRetryPressed(), // 21
  PayeeDeclinePressed(), // 22
];

const _wait = _Next(PayeePending(1, 1, 1, 0), [
  PayeeSchedulePoll(1, Duration(seconds: 1)),
  PayeeStartDeadline(1, Duration(minutes: 1)),
]);

final _table = <VirtualPayeeState, Map<int, _Next>>{
  _loading: {
    0: const _Next(_active),
    1: const _Next(_activating, [PayeeActivate(1)]),
    2: const _Next(PayeePending(0, 1, 1, 0), [
      PayeeSchedulePoll(1, Duration(seconds: 1)),
      PayeeStartDeadline(1, Duration(minutes: 1)),
    ]),
    3: const _Next(_unknown),
    4: const _Next(_loadFailed),
    5: const _Next(_ended),
  },
  _loadFailed: {
    21: const _Next(PayeeLoading(2), [PayeeLoad(2)]),
    22: const _Next(_declined),
  },
  _activating: {
    7: const _Next(_active),
    8: _wait,
    9: _wait,
    10: const _Next(_activateFailed),
    11: const _Next(_ended),
  },
  _activateFailed: {
    21: const _Next(PayeeActivating(2), [PayeeActivate(2)]),
    22: const _Next(_declined),
  },
  _pending: {
    12: const _Next(PayeePending(1, 1, 2, 1), [
      PayeeSchedulePoll(2, Duration(seconds: 5)),
    ]),
    13: const _Next(_active, [PayeeStopWatching()]),
    14: const _Next(PayeeActivateFailed(1, WriteProblemNotApplied()), [
      PayeeStopWatching(),
    ]),
    15: const _Next(_unknown, [PayeeStopWatching()]),
    17: const _Next(_paused, [PayeeCancelPoll()]),
    19: const _Next(PayeeTimedOut(1, 1, 2), [PayeeStopWatching()]),
    22: const _Next(_declined, [PayeeStopWatching()]),
  },
  _pendingLast: {
    16: const _Next(PayeeTimedOut(1, 1, 4), [PayeeStopWatching()]),
    17: const _Next(PayeePaused(1, 1, 4, 2), [PayeeCancelPoll()]),
    19: const _Next(PayeeTimedOut(1, 1, 4), [PayeeStopWatching()]),
    22: const _Next(_declined, [PayeeStopWatching()]),
  },
  _paused: {
    18: const _Next(PayeePending(1, 1, 3, 0), [
      PayeeSchedulePoll(3, Duration.zero),
    ]),
    19: const _Next(PayeeTimedOut(1, 1, 3), [PayeeStopWatching()]),
    22: const _Next(_declined, [PayeeStopWatching()]),
  },
  _timedOut: {
    21: const _Next(PayeePending(1, 2, 4, 0), [
      PayeeSchedulePoll(4, Duration.zero),
      PayeeStartDeadline(2, Duration(minutes: 1)),
    ]),
    22: const _Next(_declined),
  },
  _unknown: {
    21: const _Next(PayeeLoading(2), [PayeeLoad(2)]),
    22: const _Next(_declined),
  },
  _active: {},
  _declined: {},
  _ended: {},
};

VirtualPayeeNext _step(VirtualPayeeState state, VirtualPayeeEvent event) =>
    transitionVirtualPayee(_policy, state, event);

void main() {
  test('the table has a row for every state', () {
    expect(_table.keys, _states);
  });

  for (final state in _states) {
    for (final (index, event) in _events.indexed) {
      test('$state + ${event.runtimeType} #$index', () {
        final next = _step(state, event);
        final expected = _table[state]![index];
        if (expected == null) {
          expect(identical(next.state, state), isTrue, reason: '$next');
          expect(next.effects, isEmpty);
        } else {
          expect(next, expected);
        }
      });
    }
  }

  test('a payee the list shows active passes without a screen', () {
    expect(
      virtualPayeeStart(const VirtualPayeeRequired(alreadyActive: true)),
      const _Next(_active),
    );
    expect(
      virtualPayeeStart(const VirtualPayeeRequired(alreadyActive: false)),
      const _Next(_loading, [PayeeLoad(1)]),
    );
  });

  test('polls fast first, then slower', () {
    expect(_policy.delayAfter(0), const Duration(seconds: 1));
    expect(_policy.delayAfter(1), const Duration(seconds: 5));
  });

  test('polling stops after the policy bound', () {
    VirtualPayeeState state = _pending;
    for (var i = 0; i < _policy.maxPolls; i++) {
      final ticket = (state as PayeePending).ticket;
      state = _step(
        state,
        PayeePolled(ticket, const Ok(SepaVirtualPayeeStatus.pending)),
      ).state;
    }
    expect(state, isA<PayeeTimedOut>());
  });

  test('every state is reachable', () {
    final reached = <Type>{};
    var frontier = <VirtualPayeeState>[
      virtualPayeeStart(const VirtualPayeeRequired(alreadyActive: false)).state,
    ];
    reached.add(frontier.single.runtimeType);
    while (frontier.isNotEmpty) {
      final next = <VirtualPayeeState>[];
      for (final state in frontier) {
        for (final event in _events) {
          final target = _step(state, event).state;
          if (reached.add(target.runtimeType)) next.add(target);
        }
      }
      frontier = next;
    }
    expect(reached, {for (final state in _states) state.runtimeType});
  });
}
