import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:test/test.dart';

final class _Order {
  final String id;
  final String status;

  const _Order(this.id, this.status);

  @override
  bool operator ==(Object other) =>
      other is _Order && other.id == id && other.status == status;

  @override
  int get hashCode => Object.hash(id, status);

  @override
  String toString() => '_Order($id, $status)';
}

String _idOf(_Order order) => order.id;

OutcomeVerdict _verdictOf(_Order order) => switch (order.status) {
  'done' || 'done-no-receipt' => OutcomeVerdict.done,
  'failed' => OutcomeVerdict.failed,
  _ => OutcomeVerdict.pending,
};

bool _hasReceipt(_Order order) => order.status == 'done';

const _policy = OutcomePolicy<_Order>(
  idOf: _idOf,
  verdictOf: _verdictOf,
  hasReceipt: _hasReceipt,
  maxPolls: 3,
  maxDuration: Duration(minutes: 10),
  maxUnreadable: 2,
);

typedef _S = OutcomeWatchState<_Order>;
typedef _E = OutcomeWatchEvent<_Order>;
typedef _Next = StepNext<_S, OutcomeWatchEffect>;

const _o = _Order('o1', 'pending');
const _o2 = _Order('o1', 'payout sent');
const _done = _Order('o1', 'done');
const _failedO = _Order('o1', 'failed');
const _unreachable = ReadUnreachable<_Order>('timeout', isNetwork: true);

const _watching = WatchWatching<_Order>(_o, 0, 0, 1);
const _nearBounds = WatchWatching<_Order>(_o, 2, 1, 3);
const _paused = WatchPaused<_Order>(_o, 0, 0, 2);
const _doneS = WatchDone<_Order>(_done);
const _receipt = WatchReceipt<_Order>(_done);
const _failedS = WatchFailed<_Order>(_failedO);
const _unreadable = WatchUnreadable<_Order>(_o, 4);
const _timedOut = WatchTimedOut<_Order>(_o, 4);
const _ended = WatchSessionEnded<_Order>();
const _left = WatchLeft<_Order>();

const _states = <_S>[
  _watching,
  _nearBounds,
  _paused,
  _doneS,
  _receipt,
  _failedS,
  _unreadable,
  _timedOut,
  _ended,
  _left,
];

const _events = <_E>[
  WatchPolled('o1', 1, ReadGot(_o2)), // 0
  WatchPolled('o1', 1, ReadGot(_done)), // 1
  WatchPolled('o1', 1, ReadGot(_failedO)), // 2
  WatchPolled('o1', 1, _unreachable), // 3
  WatchPolled('o1', 1, ReadSessionRejected(ExchangeSessionRejection.server)),
  WatchPolled('o1', 3, ReadGot(_o2)), // 5
  WatchPolled('o1', 3, _unreachable), // 6
  WatchPolled('other', 1, ReadGot(_done)), // 7
  WatchVisibilityChanged(visible: false), // 8
  WatchVisibilityChanged(visible: true), // 9
  WatchDeadlinePassed('o1'), // 10
  WatchDeadlinePassed('other'), // 11
  WatchReceiptOpened(), // 12
  WatchReceiptClosed(), // 13
  WatchRetryPressed(), // 14
  WatchLeavePressed(), // 15
];

const _stop = [WatchStop('o1')];
const _leftStopping = _Next(_left, _stop);
const _rewatch = _Next(WatchWatching(_o, 0, 0, 4), [
  WatchStartDeadline('o1', Duration(minutes: 10)),
  WatchSchedulePoll('o1', 4, immediate: true),
]);

/// The transitions; every (state, event) pair not listed is a stay.
final _table = <_S, Map<int, _Next>>{
  _watching: {
    0: const _Next(WatchWatching(_o2, 1, 0, 2), [WatchSchedulePoll('o1', 2)]),
    1: const _Next(_doneS, _stop),
    2: const _Next(_failedS, _stop),
    3: const _Next(WatchWatching(_o, 1, 1, 2), [WatchSchedulePoll('o1', 2)]),
    4: const _Next(_ended, _stop),
    8: const _Next(WatchPaused(_o, 0, 0, 2), [WatchCancelPoll('o1')]),
    10: const _Next(WatchTimedOut(_o, 2), _stop),
    15: _leftStopping,
  },
  _nearBounds: {
    5: const _Next(WatchTimedOut(_o2, 4), _stop),
    6: const _Next(WatchUnreadable(_o, 4), _stop),
    8: const _Next(WatchPaused(_o, 2, 1, 4), [WatchCancelPoll('o1')]),
    10: const _Next(WatchTimedOut(_o, 4), _stop),
    15: _leftStopping,
  },
  _paused: {
    9: const _Next(WatchWatching(_o, 0, 0, 2), [
      WatchSchedulePoll('o1', 2, immediate: true),
    ]),
    10: const _Next(WatchTimedOut(_o, 3), _stop),
    15: _leftStopping,
  },
  _doneS: {12: const _Next(_receipt), 15: const _Next(_left)},
  _receipt: {13: const _Next(_doneS), 15: const _Next(_left)},
  _failedS: {15: const _Next(_left)},
  _unreadable: {14: _rewatch, 15: const _Next(_left)},
  _timedOut: {
    14: const _Next(WatchWatching(_o, 0, 0, 4), [
      WatchStartDeadline('o1', Duration(minutes: 10)),
      WatchSchedulePoll('o1', 4, immediate: true),
    ]),
    15: const _Next(_left),
  },
  _ended: {},
  _left: {},
};

void main() {
  test('the table has a row for every state', () {
    expect(_table.keys, _states);
  });

  for (final state in _states) {
    for (final (index, event) in _events.indexed) {
      test('$state + ${event.runtimeType} #$index', () {
        final next = transitionOutcomeWatch(_policy, state, event);
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

  group('start', () {
    test('a pending order starts the deadline and the first poll', () {
      expect(
        outcomeWatchStart(_policy, _o),
        const _Next(_watching, [
          WatchStartDeadline('o1', Duration(minutes: 10)),
          WatchSchedulePoll('o1', 1),
        ]),
      );
    });

    test('an order with its outcome is done or failed at once', () {
      expect(outcomeWatchStart(_policy, _done), const _Next(_doneS));
      expect(outcomeWatchStart(_policy, _failedO), const _Next(_failedS));
    });
  });

  test('a done order without a receipt keeps the receipt closed', () {
    const plain = WatchDone<_Order>(_Order('o1', 'done-no-receipt'));
    final next = transitionOutcomeWatch(
      _policy,
      plain,
      const WatchReceiptOpened(),
    );
    expect(identical(next.state, plain), isTrue);
  });

  test('a poll in flight when the watch paused lands nowhere', () {
    final paused = transitionOutcomeWatch(
      _policy,
      _watching,
      const WatchVisibilityChanged(visible: false),
    ).state;
    final resumed = transitionOutcomeWatch(
      _policy,
      paused,
      const WatchVisibilityChanged(visible: true),
    ).state;
    final late = transitionOutcomeWatch(
      _policy,
      resumed,
      const WatchPolled('o1', 1, ReadGot(_done)),
    );
    expect(identical(late.state, resumed), isTrue);
  });

  test('the poll count bounds the watch', () {
    var state = outcomeWatchStart(_policy, _o).state;
    for (var i = 0; i < 3; i++) {
      final ticket = (state as WatchWatching<_Order>).ticket;
      state = transitionOutcomeWatch(
        _policy,
        state,
        WatchPolled('o1', ticket, const ReadGot(_o)),
      ).state;
    }
    expect(state, const WatchTimedOut(_o, 4));
  });

  test('every state is reachable from the start', () {
    final reached = <Type>{};
    final seen = <_S>{};
    var frontier = <_S>[
      outcomeWatchStart(_policy, _o).state,
      outcomeWatchStart(_policy, _failedO).state,
    ];
    seen.addAll(frontier);
    for (final state in frontier) {
      reached.add(state.runtimeType);
    }
    final events = <_E>[
      for (var ticket = 1; ticket <= 6; ticket++) ...[
        WatchPolled('o1', ticket, const ReadGot(_o2)),
        WatchPolled('o1', ticket, const ReadGot(_done)),
        WatchPolled('o1', ticket, _unreachable),
        WatchPolled(
          'o1',
          ticket,
          const ReadSessionRejected(ExchangeSessionRejection.server),
        ),
      ],
      ..._events.skip(8),
    ];
    while (frontier.isNotEmpty) {
      final next = <_S>[];
      for (final state in frontier) {
        for (final event in events) {
          final target = transitionOutcomeWatch(_policy, state, event).state;
          reached.add(target.runtimeType);
          if (seen.add(target)) next.add(target);
        }
      }
      frontier = next;
    }
    expect(reached, {for (final state in _states) state.runtimeType});
  });
}
