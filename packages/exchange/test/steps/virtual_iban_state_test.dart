import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:test/test.dart';
import 'package:primitives/primitives.dart';

typedef _Next = StepNext<VirtualIbanState, VirtualIbanEffect>;

const _policy = VirtualIbanPolicy(
  maxPolls: 3,
  maxDuration: Duration(minutes: 2),
);
const _refusal = ExchangeRefusal(rpcCode: -32000);
const _unreachable = ReadProblemUnreachable(isNetwork: true);
final _active = VirtualIban.fromBankDetails(
  iban: 'DE89',
  bicCode: 'FRBKDE',
  bankAddress: 'Berlin',
) as ActiveVirtualIban;
const _pending = PendingVirtualIban();

const _loading = VibanLoading(1);
const _loadFailed = VibanLoadFailed(1, _unreachable);
const _intro = VibanIntro('Ana');
const _creating = VibanCreating('Ana', 1);
const _createFailed = VibanCreateFailed(
  'Ana',
  1,
  WriteProblemRefused(_refusal),
);
const _verifying = VibanVerifying('Ana', 1);
const _unverified = VibanUnverified('Ana', 1, _unreachable);
const _activating = VibanActivating('Ana', 1, 1, 0);
const _activatingLast = VibanActivating('Ana', 1, 3, 2);
const _paused = VibanPaused('Ana', 1, 2, 0);
const _timedOut = VibanTimedOut('Ana', 1, 4);
final _activeState = VibanActive(_active);
const _declined = VibanDeclined();
const _ended = VibanSessionEnded();

final _states = <VirtualIbanState>[
  _loading,
  _loadFailed,
  _intro,
  _creating,
  _createFailed,
  _verifying,
  _unverified,
  _activating,
  _activatingLast,
  _paused,
  _timedOut,
  _activeState,
  _declined,
  _ended,
];

final _events = <VirtualIbanEvent>[
  const VibanLoaded(
    1,
    Ok(VirtualIbanContext(virtualIban: null, ownerName: 'Ana')),
  ), // 0
  const VibanLoaded(
    1,
    Ok(VirtualIbanContext(virtualIban: _pending, ownerName: 'Ana')),
  ), // 1
  VibanLoaded(
    1,
    Ok(VirtualIbanContext(virtualIban: _active, ownerName: 'Ana')),
  ), // 2
  const VibanLoaded(
    1,
    Err(ExchangeUnreachableFailure('down', isNetwork: true)),
  ), // 3
  const VibanLoaded(
    1,
    Err(ExchangeSessionRejectedFailure(ExchangeSessionRejection.server)),
  ),
  const VibanLoaded(2, Err(ExchangeMalformedFailure('bad'))), // 5
  const VibanCreatePressed(), // 6
  VibanCreated(1, Ok(_active)), // 7
  const VibanCreated(1, Ok(_pending)), // 8
  const VibanCreated(1, Err(ExchangeWriteRefusedFailure(_refusal))), // 9
  const VibanCreated(
    1,
    Err(ExchangeWriteOutcomeUnknownFailure('timeout')),
  ), // 10
  const VibanCreated(
    1,
    Err(ExchangeSessionRejectedFailure(ExchangeSessionRejection.server)),
  ), // 11
  const VibanCreated(2, Ok(_pending)), // 12
  const VibanVerified(1, Ok(null)), // 13
  const VibanVerified(1, Ok(_pending)), // 14
  const VibanVerified(
    1,
    Err(ExchangeUnreachableFailure('down', isNetwork: true)),
  ), // 15
  const VibanPolled(1, Ok(_pending)), // 16
  VibanPolled(1, Ok(_active)), // 17
  const VibanPolled(
    3,
    Err(ExchangeUnreachableFailure('down', isNetwork: true)),
  ), // 18
  const VibanPolled(
    1,
    Err(ExchangeSessionRejectedFailure(ExchangeSessionRejection.server)),
  ),
  const VibanActivatedPushed(), // 20
  const VibanVisibilityChanged(visible: false), // 21
  const VibanVisibilityChanged(visible: true), // 22
  const VibanDeadlinePassed(1), // 23
  const VibanDeadlinePassed(9), // 24
  const VibanRetryPressed(), // 25
  const VibanDeclinePressed(), // 26
];

const _watch = _Next(VibanActivating('Ana', 1, 1, 0), [
  VibanSchedulePoll(1),
  VibanStartDeadline(1, Duration(minutes: 2)),
]);

final _table = <VirtualIbanState, Map<int, _Next>>{
  _loading: {
    0: const _Next(_intro),
    1: _watch,
    2: _Next(_activeState),
    3: const _Next(_loadFailed),
    4: const _Next(_ended),
  },
  _loadFailed: {
    25: const _Next(VibanLoading(2), [VibanLoad(2)]),
    26: const _Next(_declined),
  },
  _intro: {
    6: const _Next(_creating, [VibanCreate(1)]),
    26: const _Next(_declined),
  },
  _creating: {
    7: _Next(_activeState),
    8: _watch,
    9: const _Next(_createFailed),
    10: const _Next(_verifying, [VibanVerify(1)]),
    11: const _Next(_ended),
  },
  _createFailed: {
    25: const _Next(VibanCreating('Ana', 2), [VibanCreate(2)]),
    26: const _Next(_declined),
  },
  _verifying: {
    13: const _Next(VibanCreateFailed('Ana', 1, WriteProblemNotApplied())),
    14: _watch,
    15: const _Next(_unverified),
  },
  _unverified: {
    25: const _Next(_verifying, [VibanVerify(1)]),
    26: const _Next(_declined),
  },
  _activating: {
    16: const _Next(VibanActivating('Ana', 1, 2, 1), [VibanSchedulePoll(2)]),
    17: _Next(_activeState, const [VibanStopWatching()]),
    19: const _Next(_ended, [VibanStopWatching()]),
    20: const _Next(VibanActivating('Ana', 1, 2, 0), [
      VibanSchedulePoll(2, immediate: true),
    ]),
    21: const _Next(_paused, [VibanCancelPoll()]),
    23: const _Next(VibanTimedOut('Ana', 1, 2), [VibanStopWatching()]),
    26: const _Next(_declined, [VibanStopWatching()]),
  },
  _activatingLast: {
    18: const _Next(VibanTimedOut('Ana', 1, 4), [VibanStopWatching()]),
    20: const _Next(VibanActivating('Ana', 1, 4, 2), [
      VibanSchedulePoll(4, immediate: true),
    ]),
    21: const _Next(VibanPaused('Ana', 1, 4, 2), [VibanCancelPoll()]),
    23: const _Next(VibanTimedOut('Ana', 1, 4), [VibanStopWatching()]),
    26: const _Next(_declined, [VibanStopWatching()]),
  },
  _paused: {
    22: const _Next(VibanActivating('Ana', 1, 3, 0), [
      VibanSchedulePoll(3, immediate: true),
    ]),
    23: const _Next(VibanTimedOut('Ana', 1, 3), [VibanStopWatching()]),
    26: const _Next(_declined, [VibanStopWatching()]),
  },
  _timedOut: {
    25: const _Next(VibanActivating('Ana', 2, 4, 0), [
      VibanSchedulePoll(4, immediate: true),
      VibanStartDeadline(2, Duration(minutes: 2)),
    ]),
    26: const _Next(_declined),
  },
  _activeState: {},
  _declined: {},
  _ended: {},
};

VirtualIbanNext _step(VirtualIbanState state, VirtualIbanEvent event) =>
    state.next(_policy, event);

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

  test('starts loading', () {
    expect(virtualIbanStart(), const _Next(_loading, [VibanLoad(1)]));
  });

  test('an unknown create outcome never offers the create again', () {
    var next = _step(
      _creating,
      const VibanCreated(1, Err(ExchangeWriteOutcomeUnknownFailure('timeout'))),
    );
    expect(next.state, _verifying);
    expect(_step(next.state, const VibanCreatePressed()).state, _verifying);
    next = _step(
      next.state,
      const VibanVerified(
        1,
        Err(ExchangeUnreachableFailure('down', isNetwork: true)),
      ),
    );
    expect(next.effects, isEmpty);
    expect(_step(next.state, const VibanRetryPressed()).effects, const [
      VibanVerify(1),
    ]);
  });

  test('a poll in flight when the screen was hidden is stale on return', () {
    var state = _step(
      _activating,
      const VibanVisibilityChanged(visible: false),
    ).state;
    state = _step(state, const VibanVisibilityChanged(visible: true)).state;
    expect(state, const VibanActivating('Ana', 1, 3, 0));
    expect(
      identical(_step(state, const VibanPolled(1, Ok(_pending))).state, state),
      isTrue,
    );
  });

  test('polling stops after the policy bound', () {
    VirtualIbanState state = _activating;
    for (var i = 0; i < _policy.maxPolls; i++) {
      final ticket = (state as VibanActivating).ticket;
      state = _step(state, VibanPolled(ticket, const Ok(_pending))).state;
    }
    expect(state, isA<VibanTimedOut>());
  });

  test('every state is reachable', () {
    final reached = <Type>{};
    var frontier = <VirtualIbanState>[virtualIbanStart().state];
    reached.add(frontier.single.runtimeType);
    while (frontier.isNotEmpty) {
      final next = <VirtualIbanState>[];
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
