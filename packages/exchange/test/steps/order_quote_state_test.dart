import 'dart:async';

import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:test/test.dart';
import 'package:primitives/primitives.dart';

final class _Order {
  final String id;
  final int price;

  const _Order(this.id, this.price);

  @override
  bool operator ==(Object other) =>
      other is _Order && other.id == id && other.price == price;

  @override
  int get hashCode => Object.hash(id, price);

  @override
  String toString() => '_Order($id, $price)';
}

String _idOf(_Order order) => order.id;

typedef _S = OrderStepState<String, _Order>;
typedef _E = OrderStepEvent<String, _Order>;
typedef _Next = StepNext<_S, OrderStepEffect<String>>;

const _policy = OrderPolicy<_Order>(
  idOf: _idOf,
  locks: true,
  maxRefreshRetries: 2,
);
const _noLock = OrderPolicy<_Order>(idOf: _idOf, locks: false);

const _req = 'buy 100 CAD';
const _o1 = _Order('o1', 50000);
const _o1b = _Order('o1', 51000);
const _q = QuotedOrder('o1', _o1);
const _refusal = ExchangeRefusal(rpcCode: -32000);
const _busy = WriteGateBusy(FinancialWriteKind.payin);

const _creating = OrderCreating<String, _Order>(_req, 1);
const _gateRefused = OrderWriteRefused<String, _Order>(_req, 1, _busy);
const _failed = OrderCreateFailed<String, _Order>(
  _req,
  1,
  WriteProblemRefused(_refusal),
);
const _verifying = OrderVerifying<String, _Order>(_req, 1);
const _unverified = OrderUnverified<String, _Order>(
  _req,
  1,
  ReadProblemUnreachable(isNetwork: true),
);
const _live = OrderQuoted<String, _Order>(_q, QuoteLive());
const _refreshing = OrderQuoted<String, _Order>(_q, QuoteRefreshing(0));
const _retrying = OrderQuoted<String, _Order>(_q, QuoteRetrying(1));
const _unavailable = OrderQuoted<String, _Order>(_q, QuoteUnavailable());
const _placed = OrderPlaced<String, _Order>(_q);
const _committed = OrderCommitted<String, _Order>(_q);
const _ended = OrderSessionEnded<String, _Order>();
const _left = OrderLeft<String, _Order>();
const _limit = ExchangeOrderLimit(ExchangeOrderAmountBound.minimum, 10, 'CAD');
const _amountRefused = OrderAmountRefused<String, _Order>(_req, _limit);

const _states = <_S>[
  _creating,
  _gateRefused,
  _failed,
  _verifying,
  _unverified,
  _live,
  _refreshing,
  _retrying,
  _unavailable,
  _placed,
  _committed,
  _amountRefused,
  _ended,
  _left,
];

const _events = <_E>[
  OrderCreateAnswered(1, GateAdmitted(Ok(_o1))), // 0
  OrderCreateAnswered(
    1,
    GateAdmitted(Err(ExchangeWriteRefusedFailure(_refusal))),
  ), // 1
  OrderCreateAnswered(
    1,
    GateAdmitted(
      Err(ExchangeWriteNotSentFailure(ExchangeNotSentReason.unreachable)),
    ),
  ), // 2
  OrderCreateAnswered(
    1,
    GateAdmitted(Err(ExchangeWriteOutcomeUnknownFailure('timeout'))),
  ), // 3
  OrderCreateAnswered(
    1,
    GateAdmitted(
      Err(ExchangeSessionRejectedFailure(ExchangeSessionRejection.server)),
    ),
  ), // 4
  OrderCreateAnswered(1, GateRefused(_busy)), // 5
  OrderCreateAnswered(2, GateAdmitted(Ok(_o1))), // 6
  OrderFindAnswered(1, Ok(_o1)), // 7
  OrderFindAnswered(1, Err(ExchangeMissingFailure())), // 8
  OrderFindAnswered(
    1,
    Err(ExchangeUnreachableFailure('timeout', isNetwork: true)),
  ), // 9
  OrderFindAnswered(
    1,
    Err(ExchangeSessionRejectedFailure(ExchangeSessionRejection.server)),
  ),
  OrderFindAnswered(2, Ok(_o1)), // 11
  OrderLockDue('o1'), // 12
  OrderLockDue('other'), // 13
  OrderRefreshed('o1', Ok(_o1b)), // 14
  OrderRefreshed(
    'o1',
    Err(ExchangeUnreachableFailure('timeout', isNetwork: true)),
  ), // 15
  OrderRefreshed(
    'o1',
    Err(ExchangeSessionRejectedFailure(ExchangeSessionRejection.server)),
  ), // 16
  OrderRefreshed('other', Ok(_o1b)), // 17
  OrderRetryDue('o1'), // 18
  OrderRetryPressed(), // 19
  OrderCommitPressed(), // 20
  OrderBackPressed(), // 21
  OrderCreateAnswered(
    1,
    GateAdmitted(
      Err(ExchangeWriteRefusedFailure(ExchangeRefusal(orderLimit: _limit))),
    ),
  ), // 22
];

const _toLive = _Next(_live, [OrderStartLockTimer('o1')]);
const _toLeftHeld = _Next(_left, [OrderStopTimers('o1'), OrderRelease('o1')]);

/// The transitions; every (state, event) pair not listed is a stay.
final _table = <_S, Map<int, _Next>>{
  _creating: {
    0: _toLive,
    1: const _Next(_failed),
    2: const _Next(
      OrderCreateFailed(
        _req,
        1,
        WriteProblemNotSent(ExchangeNotSentReason.unreachable),
      ),
    ),
    3: const _Next(_verifying, [OrderFindCreated(_req, 1)]),
    4: const _Next(_ended),
    5: const _Next(_gateRefused),
    22: const _Next(_amountRefused),
  },
  _gateRefused: {
    19: const _Next(OrderCreating(_req, 2), [OrderSendCreate(_req, 2)]),
    21: const _Next(_left),
  },
  _failed: {
    19: const _Next(OrderCreating(_req, 2), [OrderSendCreate(_req, 2)]),
    21: const _Next(_left),
  },
  _verifying: {
    7: _toLive,
    8: const _Next(OrderUnverified(_req, 1, ReadProblemMissing())),
    9: const _Next(_unverified),
    10: const _Next(_ended),
  },
  _unverified: {
    19: const _Next(_verifying, [OrderFindCreated(_req, 1)]),
    21: const _Next(_left),
  },
  _live: {
    12: const _Next(_refreshing, [OrderRefresh('o1')]),
    20: const _Next(_committed, [OrderStopTimers('o1')]),
    21: _toLeftHeld,
  },
  _refreshing: {
    14: const _Next(OrderQuoted(QuotedOrder('o1', _o1b), QuoteLive()), [
      OrderStartLockTimer('o1'),
    ]),
    15: const _Next(_retrying, [OrderScheduleRefreshRetry('o1', 1)]),
    16: const _Next(_ended, [OrderStopTimers('o1')]),
    21: _toLeftHeld,
  },
  _retrying: {
    18: const _Next(OrderQuoted(_q, QuoteRefreshing(1)), [OrderRefresh('o1')]),
    21: _toLeftHeld,
  },
  _unavailable: {
    19: const _Next(_refreshing, [OrderRefresh('o1')]),
    21: _toLeftHeld,
  },
  _placed: {},
  _committed: {},
  _amountRefused: {},
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
        final next = state.next(_policy, event);
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

  test('the step starts by sending the create', () {
    expect(
      orderCreateStart<String, _Order>(_req),
      const _Next(_creating, [OrderSendCreate(_req, 1)]),
    );
  });

  test('without a lock a created order is placed', () {
    expect(_creating.next(_noLock, _events[0]), const _Next(_placed));
    expect(_verifying.next(_noLock, _events[7]), const _Next(_placed));
  });

  test('refresh failures in a row end in unavailable after the bound', () {
    const failure = OrderRefreshed<String, _Order>(
      'o1',
      Err(ExchangeUnreachableFailure('timeout', isNetwork: true)),
    );
    final second = (const OrderQuoted<String, _Order>(
      _q,
      QuoteRefreshing(1),
    )).next(_policy, failure);
    expect(
      second,
      const _Next(OrderQuoted(_q, QuoteRetrying(2)), [
        OrderScheduleRefreshRetry('o1', 2),
      ]),
    );
    expect(
      (const OrderQuoted<String, _Order>(
        _q,
        QuoteRefreshing(2),
      )).next(_policy, failure),
      const _Next(_unavailable),
    );
  });

  test('a re-read that finds no order never sends the create again', () {
    final read = _verifying.next(_policy, _events[8]);
    final retry = read.state.next(_policy, _events[19]);
    expect(
      retry.effects.whereType<OrderSendCreate<String>>(),
      isEmpty,
      reason:
          'a missing re-read after an unknown outcome cannot prove '
          'the order was not created',
    );
    expect(read.state, isA<OrderUnverified<String, _Order>>());
    expect(retry.effects, [const OrderFindCreated<String>(_req, 1)]);
  });

  test('every state is reachable from the start', () {
    final reached = <Type>{};
    var frontier = <_S>[orderCreateStart<String, _Order>(_req).state];
    reached.add(frontier.single.runtimeType);
    final events = [
      ..._events,
      const OrderCreateAnswered<String, _Order>(2, GateRefused(_busy)),
    ];
    final seen = <_S>{frontier.single};
    while (frontier.isNotEmpty) {
      final next = <_S>[];
      for (final state in frontier) {
        for (final event in events) {
          final target = state.next(_policy, event).state;
          reached.add(target.runtimeType);
          if (seen.add(target)) next.add(target);
        }
        for (final event in events) {
          final target = state.next(_noLock, event).state;
          reached.add(target.runtimeType);
          if (seen.add(target)) next.add(target);
        }
      }
      frontier = next;
    }
    expect(reached, {for (final state in _states) state.runtimeType});
  });

  group('runOrderCreate', () {
    const session = ExchangeSession(
      environment: ExchangeEnvironment.mainnet,
      epoch: 1,
      sessionId: 'a',
    );

    test('sends the create through the gate as an order create', () async {
      final gate = ExchangeWriteGate();
      FinancialWriteKind? seen;
      final answered = await runOrderCreate<String, _Order>(
        gate: gate,
        session: session,
        effect: const OrderSendCreate(_req, 3),
        create: (request) async {
          seen = gate.inFlight(ExchangeEnvironment.mainnet);
          expect(request, _req);
          return const Ok(_o1);
        },
        journalUnknown: (_) async => fail('nothing to journal'),
      );
      expect(seen, FinancialWriteKind.orderCreate);
      expect(answered.attempt, 3);
      expect(
        (const OrderCreating<String, _Order>(_req, 3)).next(_policy, answered),
        const _Next(_live, [OrderStartLockTimer('o1')]),
      );
    });

    test(
      'a write in flight refuses the create with an explicit state',
      () async {
        final gate = ExchangeWriteGate();
        final other = Completer<void>();
        final running = gate.run(
          session,
          FinancialWriteKind.withdrawal,
          () => other.future,
        );
        var sent = false;
        final answered = await runOrderCreate<String, _Order>(
          gate: gate,
          session: session,
          effect: const OrderSendCreate(_req, 1),
          create: (_) async {
            sent = true;
            return const Ok(_o1);
          },
          journalUnknown: (_) async => fail('nothing to journal'),
        );
        expect(sent, isFalse);
        expect(
          _creating.next(_policy, answered),
          const _Next(
            OrderWriteRefused(
              _req,
              1,
              WriteGateBusy(FinancialWriteKind.withdrawal),
            ),
          ),
        );
        other.complete();
        await running;
      },
    );

    test('an unknown outcome is journaled before the answer', () async {
      final journaled = <String>[];
      final answered = await runOrderCreate<String, _Order>(
        gate: ExchangeWriteGate(),
        session: session,
        effect: const OrderSendCreate(_req, 1),
        create: (_) async =>
            const Err(ExchangeWriteOutcomeUnknownFailure('timeout')),
        journalUnknown: (request) async => journaled.add(request),
      );
      expect(journaled, [_req]);
      expect(
        _creating.next(_policy, answered),
        const _Next(OrderVerifying(_req, 1), [OrderFindCreated(_req, 1)]),
      );
    });

    for (final write in <Result<_Order, ExchangeWriteFailure>>[
      const Ok(_o1),
      const Err(ExchangeWriteRefusedFailure(_refusal)),
      const Err(ExchangeWriteNotSentFailure(ExchangeNotSentReason.unreachable)),
      const Err(
        ExchangeSessionRejectedFailure(ExchangeSessionRejection.server),
      ),
    ]) {
      test('$write is not journaled', () async {
        var journaled = false;
        final _ = await runOrderCreate<String, _Order>(
          gate: ExchangeWriteGate(),
          session: session,
          effect: const OrderSendCreate(_req, 1),
          create: (_) async => write,
          journalUnknown: (_) async => journaled = true,
        );
        expect(journaled, isFalse);
      });
    }
  });
}
