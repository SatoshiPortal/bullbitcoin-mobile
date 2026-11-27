import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:test/test.dart';
import 'package:primitives/primitives.dart';

typedef _Next = StepNext<ConsentGateState, ConsentGateEffect>;

const _refusal = ExchangeRefusal(rpcCode: -32000);

final _given = consentGateStart(alreadyGiven: true).state;
const _required = ConsentRequired();
const _asking = ConsentAsking();
const _submitting = ConsentSubmitting(1);
const _verifying = ConsentVerifying(1);
const _failed = ConsentFailed(1, WriteProblemRefused(_refusal));
const _unverified = ConsentUnverified(
  1,
  ReadProblemUnreachable(isNetwork: true),
);
const _declined = ConsentDeclined();
const _ended = ConsentSessionEnded();

final _states = <ConsentGateState>[
  _required,
  _asking,
  _submitting,
  _verifying,
  _failed,
  _unverified,
  _given,
  _declined,
  _ended,
];

const _events = <ConsentGateEvent>[
  ConsentStartPressed(), // 0
  ConsentAcceptPressed(), // 1
  ConsentDeclinePressed(), // 2
  ConsentSubmitted(1, Ok(null)), // 3
  ConsentSubmitted(1, Err(ExchangeWriteRefusedFailure(_refusal))), // 4
  ConsentSubmitted(1, Err(ExchangeWriteOutcomeUnknownFailure('timeout'))), // 5
  ConsentSubmitted(
    1,
    Err(ExchangeSessionRejectedFailure(ExchangeSessionRejection.server)),
  ), // 6
  ConsentSubmitted(2, Ok(null)), // 7
  ConsentVerified(1, Ok(true)), // 8
  ConsentVerified(1, Ok(false)), // 9
  ConsentVerified(
    1,
    Err(ExchangeUnreachableFailure('timeout', isNetwork: true)),
  ), // 10
  ConsentVerified(
    1,
    Err(ExchangeSessionRejectedFailure(ExchangeSessionRejection.server)),
  ),
  ConsentRetryPressed(), // 12
];

/// The transitions; every pair not listed is a stay.
final _table = <ConsentGateState, Map<int, _Next>>{
  _required: {0: const _Next(_asking), 2: const _Next(_declined)},
  _asking: {
    1: const _Next(_submitting, [ConsentSubmit(1)]),
    2: const _Next(_declined),
  },
  _submitting: {
    3: _Next(_given),
    4: const _Next(_failed),
    5: const _Next(_verifying, [ConsentVerify(1)]),
    6: const _Next(_ended),
  },
  _verifying: {
    8: _Next(_given),
    9: const _Next(ConsentFailed(1, WriteProblemNotApplied())),
    10: const _Next(_unverified),
    11: const _Next(_ended),
  },
  _failed: {
    2: const _Next(_declined),
    12: const _Next(ConsentSubmitting(2), [ConsentSubmit(2)]),
  },
  _unverified: {
    2: const _Next(_declined),
    12: const _Next(_verifying, [ConsentVerify(1)]),
  },
  _given: {},
  _declined: {},
  _ended: {},
};

void main() {
  test('the table has a row for every state', () {
    expect(_table.keys, _states);
  });

  for (final state in _states) {
    for (final (index, event) in _events.indexed) {
      test('$state + ${event.runtimeType} #$index', () {
        final next = state.next(event);
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

  test('consent already on the account is given at once, never asked', () {
    expect(_given, isA<ConsentGateGiven>());
    expect(
      consentGateStart(alreadyGiven: false),
      const _Next(ConsentRequired()),
    );
  });

  test('every state is reachable', () {
    final reached = <Type>{};
    var frontier = <ConsentGateState>[
      consentGateStart(alreadyGiven: false).state,
    ];
    reached.add(frontier.single.runtimeType);
    while (frontier.isNotEmpty) {
      final next = <ConsentGateState>[];
      for (final state in frontier) {
        for (final event in _events) {
          final target = state.next(event).state;
          if (reached.add(target.runtimeType)) next.add(target);
        }
      }
      frontier = next;
    }
    expect(reached, {for (final state in _states) state.runtimeType});
  });
}
