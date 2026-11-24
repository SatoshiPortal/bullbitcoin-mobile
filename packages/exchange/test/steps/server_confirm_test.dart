import 'dart:async';

import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:test/test.dart';

typedef _S = ServerConfirmState<String, String>;
typedef _E = ServerConfirmEvent<String, String>;
typedef _Next = StepNext<_S, ServerConfirmEffect<String>>;

String? _orderId(String target) => target;

const _policy = ServerConfirmPolicy<String>(
  writeKind: FinancialWriteKind.orderConfirm,
  journalKind: UnknownWriteKind.buyConfirm,
  resourceIdOf: _orderId,
);

const _t = 'o1';
const _c = 'confirmed o1';
const _refusal = ExchangeRefusal(apiCode: 'ORDER_EXPIRED');
const _busy = WriteGateBusy(FinancialWriteKind.payin);

UnknownWrite _entry(String id, UnknownWriteKind kind, String? orderId) =>
    UnknownWrite(
      id: id,
      kind: kind,
      environment: ExchangeEnvironment.mainnet,
      request: {'orderId': ?orderId},
      recordedAt: DateTime.utc(2026, 11, 24),
      orderId: orderId,
    );

final _ownEntry = _entry('e1', UnknownWriteKind.buyConfirm, _t);
final _otherEntry = _entry('e2', UnknownWriteKind.buyConfirm, 'o9');

const _confirming = ConfirmConfirming<String, String>(_t, 1);
const _gateRefused = ConfirmWriteRefused<String, String>(_t, 1, _busy);
const _confirmed = ConfirmConfirmed<String, String>(_c);
const _failed = ConfirmFailed<String, String>(
  _t,
  1,
  WriteProblemRefused(_refusal),
);
const _verifying = ConfirmVerifying<String, String>(_t, 1);
const _unverified = ConfirmUnverified<String, String>(
  _t,
  1,
  ReadProblemUnreachable(isNetwork: false),
);
const _ended = ConfirmSessionEnded<String, String>();
const _left = ConfirmLeft<String, String>();

const _states = <_S>[
  _confirming,
  _gateRefused,
  _confirmed,
  _failed,
  _verifying,
  _unverified,
  _ended,
  _left,
];

final _events = <_E>[
  const ConfirmAnswered(1, GateAdmitted(WriteDone(_c))), // 0
  const ConfirmAnswered(1, GateAdmitted(WriteRefused(_refusal))), // 1
  const ConfirmAnswered(
    1,
    GateAdmitted(WriteNotSent(ExchangeNotSentReason.signedOut)),
  ), // 2
  const ConfirmAnswered(1, GateAdmitted(WriteOutcomeUnknown('timeout'))), // 3
  const ConfirmAnswered(1, GateAdmitted(WriteSessionRejected())), // 4
  const ConfirmAnswered(1, GateRefused(_busy)), // 5
  ConfirmAnswered(1, GateRefused(WriteGateUnsettled(_ownEntry))), // 6
  ConfirmAnswered(1, GateRefused(WriteGateUnsettled(_otherEntry))), // 7
  const ConfirmAnswered(2, GateAdmitted(WriteDone(_c))), // 8
  const ConfirmVerified(1, ConfirmSeenApplied(_c)), // 9
  const ConfirmVerified(1, ConfirmSeenNotApplied()), // 10
  const ConfirmVerified(
    1,
    ConfirmCheckFailed(ReadProblemUnreachable(isNetwork: false)),
  ), // 11
  const ConfirmVerified(1, ConfirmCheckSessionRejected()), // 12
  const ConfirmVerified(2, ConfirmSeenApplied(_c)), // 13
  const ConfirmCommitPressed(), // 14
  const ConfirmRetryPressed(), // 15
  const ConfirmBackPressed(), // 16
];

const _toVerifying = _Next(_verifying, [ConfirmVerify(_t, 1)]);
const _toSecondSend = _Next(ConfirmConfirming(_t, 2), [ConfirmSend(_t, 2)]);

/// The transitions; every (state, event) pair not listed is a stay.
final _table = <_S, Map<int, _Next>>{
  _confirming: {
    0: const _Next(_confirmed),
    1: const _Next(_failed),
    2: const _Next(
      ConfirmFailed(
        _t,
        1,
        WriteProblemNotSent(ExchangeNotSentReason.signedOut),
      ),
    ),
    3: _toVerifying,
    4: const _Next(_ended),
    5: const _Next(_gateRefused),
    6: _toVerifying,
    7: _Next(ConfirmWriteRefused(_t, 1, WriteGateUnsettled(_otherEntry))),
  },
  _gateRefused: {15: _toSecondSend, 16: const _Next(_left)},
  _confirmed: {},
  _failed: {14: _toSecondSend, 16: const _Next(_left)},
  _verifying: {
    9: const _Next(_confirmed),
    10: const _Next(ConfirmFailed(_t, 1, WriteProblemNotApplied())),
    11: const _Next(_unverified),
    12: const _Next(_ended),
  },
  _unverified: {15: _toVerifying, 16: const _Next(_left)},
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
        final next = transitionServerConfirm(_policy, state, event);
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
    test('without an open journal entry the write is sent', () {
      expect(
        serverConfirmStart<String, String>(_t),
        const _Next(_confirming, [ConfirmSend(_t, 1)]),
      );
    });

    test('an open entry for this resource starts in Verifying', () {
      final open = openEntryFor(_policy, _t, [_otherEntry, _ownEntry]);
      expect(open?.id, 'e1');
      expect(
        serverConfirmStart<String, String>(_t, openEntry: open),
        _toVerifying,
      );
    });

    test('entries of another kind or order do not match', () {
      expect(
        openEntryFor(_policy, _t, [
          _otherEntry,
          _entry('e3', UnknownWriteKind.withdrawConfirm, _t),
        ]),
        isNull,
      );
    });

    test('a write journaled without an order id matches by kind', () {
      const dca = ServerConfirmPolicy<String>(
        writeKind: FinancialWriteKind.dcaCreate,
        journalKind: UnknownWriteKind.dcaCreate,
        resourceIdOf: _noId,
      );
      final entry = _entry('e4', UnknownWriteKind.dcaCreate, null);
      expect(openEntryFor(dca, 'dca', [entry]), entry);
    });
  });

  test('the confirmed value is a server-confirmed commit', () {
    expect(_confirmed.committed, const ServerConfirmed(_c));
  });

  test('every state is reachable from both starts', () {
    final reached = <Type>{};
    final seen = <_S>{};
    var frontier = <_S>[
      serverConfirmStart<String, String>(_t).state,
      serverConfirmStart<String, String>(_t, openEntry: _ownEntry).state,
    ];
    seen.addAll(frontier);
    for (final state in frontier) {
      reached.add(state.runtimeType);
    }
    final events = [
      ..._events,
      const ConfirmAnswered<String, String>(2, GateRefused(_busy)),
    ];
    while (frontier.isNotEmpty) {
      final next = <_S>[];
      for (final state in frontier) {
        for (final event in events) {
          final target = transitionServerConfirm(_policy, state, event).state;
          reached.add(target.runtimeType);
          if (seen.add(target)) next.add(target);
        }
      }
      frontier = next;
    }
    expect(reached, {for (final state in _states) state.runtimeType});
  });

  group('runServerConfirm', () {
    const session = ExchangeSession(
      environment: ExchangeEnvironment.testnet,
      epoch: 4,
      sessionId: 'z',
    );

    test('sends through the gate with the policy kind', () async {
      final gate = ExchangeWriteGate();
      FinancialWriteKind? seen;
      final answered = await runServerConfirm<String, String>(
        gate: gate,
        session: session,
        policy: _policy,
        effect: const ConfirmSend(_t, 2),
        confirm: (target) async {
          seen = gate.inFlight(ExchangeEnvironment.testnet);
          return WriteDone('confirmed $target');
        },
      );
      expect(seen, FinancialWriteKind.orderConfirm);
      expect(
        transitionServerConfirm(
          _policy,
          const ConfirmConfirming<String, String>(_t, 2),
          answered,
        ),
        const _Next(_confirmed),
      );
    });

    test('an unsettled entry of this order in the journal verifies', () async {
      final journal = InMemoryUnknownWriteJournal();
      await journal.record(
        const UnknownWriteDraft(
          kind: UnknownWriteKind.buyConfirm,
          environment: ExchangeEnvironment.testnet,
          request: {'orderId': _t},
          orderId: _t,
        ),
      );
      var sent = false;
      final answered = await runServerConfirm<String, String>(
        gate: ExchangeWriteGate(journal: journal),
        session: session,
        policy: _policy,
        effect: const ConfirmSend(_t, 1),
        confirm: (_) async {
          sent = true;
          return const WriteDone(_c);
        },
      );
      expect(sent, isFalse);
      expect(
        transitionServerConfirm(_policy, _confirming, answered),
        _toVerifying,
      );
    });

    test('a write in flight is an explicit refusal', () async {
      final gate = ExchangeWriteGate();
      final other = Completer<void>();
      final running = gate.run(
        session,
        FinancialWriteKind.accelerate,
        () => other.future,
      );
      final answered = await runServerConfirm<String, String>(
        gate: gate,
        session: session,
        policy: _policy,
        effect: const ConfirmSend(_t, 1),
        confirm: (_) async => const WriteDone(_c),
      );
      expect(
        transitionServerConfirm(_policy, _confirming, answered),
        const _Next(
          ConfirmWriteRefused(
            _t,
            1,
            WriteGateBusy(FinancialWriteKind.accelerate),
          ),
        ),
      );
      other.complete();
      await running;
    });
  });
}

String? _noId(String _) => null;
