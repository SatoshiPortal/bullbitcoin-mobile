import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:test/test.dart';

typedef _Next = StepNext<KycGateState, KycGateEffect>;

const _cad = ExchangeCatalog.cad;

const _required = KycGateRequired(_cad, amount: 1500);
const _inKyc = KycGateInKyc(_cad, amount: 1500);
final _passed = kycGateStart(_cad, {
  KycGroup.identityVerified,
}, amount: 1500).state;
const _left = KycGateLeft();

final _states = <KycGateState>[_required, _inKyc, _passed, _left];

const _events = <KycGateEvent>[
  KycGateOpenPressed(),
  KycGateReturned({KycGroup.identityVerified}),
  KycGateReturned({KycGroup.limited}),
  KycGateLeavePressed(),
];

/// The transitions; every pair not listed is a stay.
final _table = <KycGateState, Map<int, _Next>>{
  _required: {
    0: const _Next(_inKyc, [KycGateOpenKyc(_cad)]),
    3: const _Next(_left),
  },
  _inKyc: {1: _Next(_passed), 2: const _Next(_required)},
  _passed: {},
  _left: {},
};

void main() {
  test('the table has a row for every state', () {
    expect(_table.keys, _states);
  });

  for (final state in _states) {
    for (final (index, event) in _events.indexed) {
      test('$state + ${event.runtimeType} #$index', () {
        final next = transitionKycGate(state, event);
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

  test('the start checks the groups against the market and amount', () {
    expect(_passed, isA<KycGatePassed>());
    expect((_passed as KycGatePassed).cleared.market, _cad);
    expect(
      kycGateStart(_cad, {KycGroup.limited}, amount: 1500),
      const _Next(_required),
    );
    expect(kycGateStart(_cad, {KycGroup.limited}).state, isA<KycGatePassed>());
    expect(
      kycGateStart(ExchangeCatalog.eur, {KycGroup.limited}),
      const _Next(KycGateRequired(ExchangeCatalog.eur)),
    );
  });

  test('every state is reachable', () {
    final reached = <Type>{};
    var frontier = <KycGateState>[
      kycGateStart(_cad, const {}, amount: 1500).state,
    ];
    reached.add(frontier.single.runtimeType);
    while (frontier.isNotEmpty) {
      final next = <KycGateState>[];
      for (final state in frontier) {
        for (final event in _events) {
          final target = transitionKycGate(state, event).state;
          if (reached.add(target.runtimeType)) next.add(target);
        }
      }
      frontier = next;
    }
    expect(reached, {for (final state in _states) state.runtimeType});
  });
}
