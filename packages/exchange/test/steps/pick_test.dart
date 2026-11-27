import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

typedef _S = PickState<DestinationOption, Destination>;
typedef _E = PickEvent<DestinationOption, Destination>;
typedef _Next = StepNext<_S, PickEffect<DestinationOption>>;

const _appW = DestinationOptionAppWallet('w1', BtcNetwork.bitcoin);
const _appW2 = DestinationOptionAppWallet('w2', BtcNetwork.liquid);
const _defW = DestinationOptionDefaultWallet(BtcNetwork.bitcoin, 'bc1qdef');
const _notOffered = DestinationOptionDefaultWallet(BtcNetwork.liquid, 'lq1');
const _opts = <DestinationOption>[_appW, _defW];

const _appDest = DestinationAppWallet('w1', BtcNetwork.bitcoin, 'bc1qrecv');
const _defDest = DestinationDefaultWallet(BtcNetwork.bitcoin, 'bc1qdef');
const _typedDest = DestinationAddress(BtcNetwork.bitcoin, 'bc1q');
const _f = ExchangeDestinationInvalidFailure();

final _policy = destinationPolicy(acceptsTyped: true);

const _choosing = PickChoosing<DestinationOption, Destination>(_opts);
const _choosingProblem = PickChoosing<DestinationOption, Destination>(
  _opts,
  problem: PickTextInvalid('x', _f),
);
const _resolving = PickResolving<DestinationOption, Destination>(_opts, _appW);
const _validating = PickValidating<DestinationOption, Destination>(
  _opts,
  'bc1q',
);
const _chosen = PickChosen<DestinationOption, Destination>(_opts, _defDest);

const _states = <_S>[
  _choosing,
  _choosingProblem,
  _resolving,
  _validating,
  _chosen,
];

const _events = <_E>[
  PickChose(_appW),
  PickChose(_defW),
  PickChose(_notOffered),
  PickTyped('bc1q'),
  PickTyped(' lnaddr@x.y '),
  PickTyped(''),
  PickValidated('bc1q', Ok(_typedDest)),
  PickValidated('other', Ok(_typedDest)),
  PickValidated('bc1q', Err(_f)),
  PickResolved(_appW, Ok(_appDest)),
  PickResolved(_appW, Err(_f)),
  PickResolved(_appW2, Ok(_appDest)),
  PickBackPressed(),
];

const _toResolving = _Next(_resolving, [PickResolve(_appW)]);
const _toDefChosen = _Next(_chosen);
const _toValidating = _Next(_validating, [PickValidate('bc1q')]);
const _toValidatingLn = _Next(
  PickValidating<DestinationOption, Destination>(_opts, 'lnaddr@x.y'),
  [PickValidate('lnaddr@x.y')],
);
const _toChoosing = _Next(_choosing);

/// null = an explicit stay.
final _table = <_S, List<_Next?>>{
  _choosing: [
    _toResolving,
    _toDefChosen,
    null,
    _toValidating,
    _toValidatingLn,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
  ],
  _choosingProblem: [
    _toResolving,
    _toDefChosen,
    null,
    _toValidating,
    _toValidatingLn,
    _toChoosing,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
  ],
  _resolving: [
    null,
    _toDefChosen,
    null,
    _toValidating,
    _toValidatingLn,
    null,
    null,
    null,
    null,
    const _Next(PickChosen(_opts, _appDest)),
    const _Next(PickChoosing(_opts, problem: PickResolveFailed(_appW, _f))),
    null,
    _toChoosing,
  ],
  _validating: [
    _toResolving,
    _toDefChosen,
    null,
    null,
    _toValidatingLn,
    _toChoosing,
    const _Next(PickChosen(_opts, _typedDest)),
    null,
    const _Next(PickChoosing(_opts, problem: PickTextInvalid('bc1q', _f))),
    null,
    null,
    null,
    _toChoosing,
  ],
  _chosen: [for (var i = 0; i < 12; i++) null, _toChoosing],
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

  test('a destination pick without a typed address ignores typing', () {
    final noTyped = destinationPolicy(acceptsTyped: false);
    final next = _choosing.next(noTyped, const PickTyped('bc1q'));
    expect(identical(next.state, _choosing), isTrue);
  });

  test('payin sources are values at once and never typed', () {
    const app = PayinOptionAppWallet('w1', BtcNetwork.liquid);
    const outside = PayinOptionExternal(BtcNetwork.lightning);
    final start = pickStart<PayinOption, PayinSource>([app, outside]);
    expect(
      start.state.next(payinSourcePolicy, const PickChose(outside)),
      const StepNext<
        PickState<PayinOption, PayinSource>,
        PickEffect<PayinOption>
      >(PickChosen([app, outside], PayinFromExternal(BtcNetwork.lightning))),
    );
    expect(
      start.state.next(payinSourcePolicy, const PickChose(app)).state,
      const PickChosen<PayinOption, PayinSource>([
        app,
        outside,
      ], PayinFromAppWallet('w1', BtcNetwork.liquid)),
    );
    final typed = start.state.next(payinSourcePolicy, const PickTyped('bc1q'));
    expect(identical(typed.state, start.state), isTrue);
  });

  test('every state is reachable from the start', () {
    final reached = <Type>{};
    var frontier = <_S>[pickStart<DestinationOption, Destination>(_opts).state];
    reached.add(frontier.single.runtimeType);
    while (frontier.isNotEmpty) {
      final next = <_S>[];
      for (final state in frontier) {
        for (final event in _events) {
          final target = state.next(_policy, event).state;
          if (reached.add(target.runtimeType)) next.add(target);
        }
      }
      frontier = next;
    }
    expect(reached, {for (final state in _states) state.runtimeType});
  });
}
