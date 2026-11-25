import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:test/test.dart';

const _s = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 1,
  sessionId: 'a',
);
const _s2 = ExchangeSession(
  environment: ExchangeEnvironment.testnet,
  epoch: 2,
  sessionId: 'b',
);

const _checking = SessionChecking();
const _signIn = SessionSignInRequired();
const _unavailable = SessionUnavailable(SessionUnavailableReason.unreadable);
const _open = SessionOpen(_s);
const _ended = SessionEnded();
const _closed = SessionClosed();

const _states = <SessionGateState>[
  _checking,
  _signIn,
  _unavailable,
  _open,
  _ended,
  _closed,
];

const _events = <SessionGateEvent>[
  SessionAccessChanged(ExchangeAccessResolving()),
  SessionAccessChanged(ExchangeAccessUnreadable()),
  SessionAccessChanged(ExchangeAccessDisabled()),
  SessionAccessChanged(ExchangeAccessSignOutIncomplete()),
  SessionAccessChanged(ExchangeAccessSignedOut(ExchangeEnvironment.mainnet)),
  SessionAccessChanged(ExchangeAccessSignedIn(_s)),
  SessionAccessChanged(ExchangeAccessSignedIn(_s2)),
  SessionAccessChanged(ExchangeAccessExpiring(_s)),
  SessionAccessChanged(
    ExchangeAccessCredentialUnreadable(ExchangeEnvironment.mainnet),
  ),
  SessionSignInFinished(_s),
  SessionSignInCancelled(),
  SessionRetryPressed(),
  SessionServerRejected(_s),
  SessionServerRejected(_s2),
];

typedef _Next = StepNext<SessionGateState, SessionGateEffect>;

/// null = an explicit stay (same instance, no effect).
const _stay = null;
const _toEnded = _Next(_ended, [SessionShowEnded()]);

/// One row per state, one entry per event of [_events], in order.
final _table = <SessionGateState, List<_Next?>>{
  _checking: [
    _stay,
    const _Next(SessionUnavailable(SessionUnavailableReason.unreadable)),
    const _Next(SessionUnavailable(SessionUnavailableReason.disabled)),
    const _Next(SessionUnavailable(SessionUnavailableReason.signOutIncomplete)),
    const _Next(_signIn, [SessionOpenSignIn()]),
    const _Next(SessionOpen(_s)),
    const _Next(SessionOpen(_s2)),
    _stay,
    const _Next(SessionUnavailable(SessionUnavailableReason.unreadable)),
    _stay,
    _stay,
    _stay,
    _stay,
    _stay,
  ],
  _signIn: [
    _stay,
    _stay,
    _stay,
    _stay,
    _stay,
    const _Next(SessionOpen(_s)),
    const _Next(SessionOpen(_s2)),
    _stay,
    _stay,
    const _Next(SessionOpen(_s)),
    const _Next(_closed, [SessionCloseFlow()]),
    _stay,
    _stay,
    _stay,
  ],
  _unavailable: [
    for (var i = 0; i < 11; i++) _stay,
    const _Next(_checking, [SessionReadAccess()]),
    _stay,
    _stay,
  ],
  _open: [
    _toEnded,
    _toEnded,
    _toEnded,
    _toEnded,
    _toEnded,
    _stay,
    _toEnded,
    _toEnded,
    _toEnded,
    _stay,
    _stay,
    _stay,
    _toEnded,
    _stay,
  ],
  _ended: List.filled(_events.length, _stay),
  _closed: List.filled(_events.length, _stay),
};

void main() {
  test('the table has a row for every state and an answer for every event', () {
    expect(_table.keys, _states);
    for (final row in _table.values) {
      expect(row, hasLength(_events.length));
    }
  });

  for (final state in _states) {
    for (final (index, event) in _events.indexed) {
      test('$state + ${event.runtimeType} #$index', () {
        final next = transitionSessionGate(state, event);
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

  test('the gate starts by reading the access', () {
    expect(sessionGateStart(), const _Next(_checking, [SessionReadAccess()]));
  });

  test('every state is reachable from the start', () {
    final reached = <Type>{};
    var frontier = <SessionGateState>[sessionGateStart().state];
    reached.add(frontier.single.runtimeType);
    while (frontier.isNotEmpty) {
      final next = <SessionGateState>[];
      for (final state in frontier) {
        for (final event in _events) {
          final target = transitionSessionGate(state, event).state;
          if (reached.add(target.runtimeType)) next.add(target);
        }
      }
      frontier = next;
    }
    expect(reached, {for (final state in _states) state.runtimeType});
  });

  test('every access state has a reading', () {
    expect(
      readSessionAccess(const ExchangeAccessSignedIn(_s)),
      isA<AccessReadingSignedIn>().having((r) => r.session, 'session', _s),
    );
    expect(
      readSessionAccess(const ExchangeAccessExpiring(_s)),
      isA<AccessReadingPending>(),
    );
  });
}
