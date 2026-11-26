import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:test/test.dart';

typedef _Next = StepNext<ContextLoadState<String>, ContextLoadEffect>;

const _loading = ContextLoading<String>(1);
const _ready = ContextReady<String>('summary');
const _failed = ContextFailed<String>(
  1,
  ReadProblemUnreachable(isNetwork: true),
);
const _rejected = ContextSessionRejected<String>();

const _states = <ContextLoadState<String>>[
  _loading,
  _ready,
  _failed,
  _rejected,
];

const _events = <ContextLoadEvent<String>>[
  ContextLoaded(1, ReadGot('fresh')),
  ContextLoaded(1, ReadMissing()),
  ContextLoaded(1, ReadUnreachable('timeout', isNetwork: true)),
  ContextLoaded(1, ReadMalformed('bad json')),
  ContextLoaded(1, ReadSessionRejected(ExchangeSessionRejection.server)),
  ContextLoaded(2, ReadGot('other attempt')),
  ContextRetryPressed(),
];

/// null = an explicit stay.
final _table = <ContextLoadState<String>, List<_Next?>>{
  _loading: [
    const _Next(ContextReady('fresh')),
    const _Next(ContextFailed(1, ReadProblemMissing())),
    const _Next(ContextFailed(1, ReadProblemUnreachable(isNetwork: true))),
    const _Next(ContextFailed(1, ReadProblemMalformed())),
    const _Next(ContextSessionRejected()),
    null,
    null,
  ],
  _ready: List.filled(_events.length, null),
  _failed: [
    null,
    null,
    null,
    null,
    null,
    null,
    const _Next(ContextLoading(2), [ContextFetch(2)]),
  ],
  _rejected: List.filled(_events.length, null),
};

void main() {
  test('the table covers every state and event', () {
    expect(_table.keys, _states);
    for (final row in _table.values) {
      expect(row, hasLength(_events.length));
    }
  });

  for (final state in _states) {
    for (final (index, event) in _events.indexed) {
      test('$state + ${event.runtimeType} #$index', () {
        final next = transitionContextLoad(state, event);
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

  test('a load starts with attempt 1', () {
    expect(
      contextLoadStart<String>(),
      const _Next(ContextLoading(1), [ContextFetch(1)]),
    );
  });

  test('a late answer of the failed attempt after a retry is a stay', () {
    final retried = transitionContextLoad(
      _failed,
      const ContextRetryPressed(),
    ).state;
    final late = transitionContextLoad(
      retried,
      const ContextLoaded(1, ReadGot('late')),
    );
    expect(identical(late.state, retried), isTrue);
  });

  test('every state is reachable from the start', () {
    final reached = <Type>{};
    var frontier = <ContextLoadState<String>>[contextLoadStart<String>().state];
    reached.add(frontier.single.runtimeType);
    final events = [
      ..._events,
      const ContextLoaded<String>(2, ReadGot('second')),
    ];
    while (frontier.isNotEmpty) {
      final next = <ContextLoadState<String>>[];
      for (final state in frontier) {
        for (final event in events) {
          final target = transitionContextLoad(state, event).state;
          if (reached.add(target.runtimeType)) next.add(target);
        }
      }
      frontier = next;
    }
    expect(reached, {for (final state in _states) state.runtimeType});
  });
}
