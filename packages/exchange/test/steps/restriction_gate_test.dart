import 'package:exchange/steps.dart';
import 'package:test/test.dart';

typedef _Next = StepNext<RestrictionGateState, RestrictionGateEffect>;

final _allowed = restrictionGateStart(restricted: false).state;
const _restricted = RestrictionRestricted();
const _left = RestrictionLeft();

final _states = <RestrictionGateState>[_allowed, _restricted, _left];

const _events = <RestrictionGateEvent>[
  RestrictionReloaded(restricted: false),
  RestrictionReloaded(restricted: true),
  RestrictionLeavePressed(),
];

/// The transitions; every pair not listed is a stay.
final _table = <RestrictionGateState, Map<int, _Next>>{
  _allowed: {},
  _restricted: {0: _Next(_allowed), 2: const _Next(_left)},
  _left: {},
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

  test('the start follows the loaded context', () {
    expect(_allowed, isA<RestrictionAllowed>());
    expect(restrictionGateStart(restricted: true), const _Next(_restricted));
  });

  test('every state is reachable', () {
    final reached = <Type>{_restricted.runtimeType};
    var frontier = <RestrictionGateState>[
      restrictionGateStart(restricted: true).state,
    ];
    while (frontier.isNotEmpty) {
      final next = <RestrictionGateState>[];
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
