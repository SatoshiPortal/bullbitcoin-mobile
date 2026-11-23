import 'package:exchange/exchange.dart';
import 'package:exchange/src/session/exchange_access_machine.dart';
import 'package:test/test.dart';

const _main = ExchangeEnvironment.mainnet;
const _test = ExchangeEnvironment.testnet;
const _current = ExchangeSession(environment: _main, epoch: 3, sessionId: 'a');
const _candidate = ExchangeSession(
  environment: _main,
  epoch: 4,
  sessionId: 'b',
);
const _other = ExchangeSession(environment: _test, epoch: 4, sessionId: 'c');

const _resolving = ExchangeAccessResolving();
const _unreadable = ExchangeAccessUnreadable();
const _disabled = ExchangeAccessDisabled();
const _incomplete = ExchangeAccessSignOutIncomplete();
const _signedOut = ExchangeAccessSignedOut(_main);
const _signedIn = ExchangeAccessSignedIn(_current);
const _expiring = ExchangeAccessExpiring(_current);
const _keyUnreadable = ExchangeAccessCredentialUnreadable(_main);

/// Every state, in the order of the rows below.
const _states = <ExchangeAccess>[
  _resolving,
  _unreadable,
  _disabled,
  _incomplete,
  _signedOut,
  _signedIn,
  _expiring,
  _keyUnreadable,
];

/// One row per event: the next state from each of [_states], in order.
final _table = <(ExchangeAccessEvent, List<ExchangeAccess>)>[
  (
    const AccessChoiceUnreadable(),
    [
      _unreadable,
      _unreadable,
      _unreadable,
      _incomplete,
      _unreadable,
      _unreadable,
      _unreadable,
      _unreadable,
    ],
  ),
  (
    const AccessFoundDisabled(),
    [
      _disabled,
      _disabled,
      _disabled,
      _incomplete,
      _disabled,
      _disabled,
      _disabled,
      _disabled,
    ],
  ),
  (const AccessFoundSignOutPending(), List.filled(8, _incomplete)),
  (
    const AccessFoundSignedOut(_test),
    [
      const ExchangeAccessSignedOut(_test),
      const ExchangeAccessSignedOut(_test),
      const ExchangeAccessSignedOut(_test),
      _incomplete,
      const ExchangeAccessSignedOut(_test),
      const ExchangeAccessSignedOut(_test),
      const ExchangeAccessSignedOut(_test),
      const ExchangeAccessSignedOut(_test),
    ],
  ),
  (
    const AccessFoundKey(_candidate),
    [
      const ExchangeAccessSignedIn(_candidate),
      const ExchangeAccessSignedIn(_candidate),
      const ExchangeAccessSignedIn(_candidate),
      _incomplete,
      const ExchangeAccessSignedIn(_candidate),
      // Same environment: the current session goes on, no new epoch.
      _signedIn,
      const ExchangeAccessSignedIn(_candidate),
      const ExchangeAccessSignedIn(_candidate),
    ],
  ),
  (
    const AccessKeyUnreadable(_test),
    [
      const ExchangeAccessCredentialUnreadable(_test),
      const ExchangeAccessCredentialUnreadable(_test),
      const ExchangeAccessCredentialUnreadable(_test),
      _incomplete,
      const ExchangeAccessCredentialUnreadable(_test),
      const ExchangeAccessCredentialUnreadable(_test),
      const ExchangeAccessCredentialUnreadable(_test),
      const ExchangeAccessCredentialUnreadable(_test),
    ],
  ),
  (
    const AccessKeyStored(_candidate),
    [
      _resolving,
      _unreadable,
      _disabled,
      _incomplete,
      const ExchangeAccessSignedIn(_candidate),
      const ExchangeAccessSignedIn(_candidate),
      const ExchangeAccessSignedIn(_candidate),
      const ExchangeAccessSignedIn(_candidate),
    ],
  ),
  (const AccessSignOutStarted(), List.filled(8, _incomplete)),
  (
    const AccessSignOutCompleted(),
    [
      _resolving,
      _unreadable,
      _disabled,
      _disabled,
      _signedOut,
      _signedIn,
      _expiring,
      _keyUnreadable,
    ],
  ),
  (const AccessSignOutFailed(), _states),
  (
    const AccessSessionRejected(3),
    [
      _resolving,
      _unreadable,
      _disabled,
      _incomplete,
      _signedOut,
      _expiring,
      _expiring,
      _keyUnreadable,
    ],
  ),
  (
    const AccessExpiryCompleted(3),
    [
      _resolving,
      _unreadable,
      _disabled,
      _incomplete,
      _signedOut,
      _signedIn,
      _signedOut,
      _keyUnreadable,
    ],
  ),
  (const AccessExpiryFailed(3), _states),
];

void main() {
  test('the table names every event once and every state per event', () {
    expect(
      _table.map((row) => row.$1.runtimeType).toSet(),
      hasLength(_table.length),
    );
    expect(_table, hasLength(13));
    for (final (_, next) in _table) {
      expect(next, hasLength(_states.length));
    }
  });

  for (final (event, next) in _table) {
    for (var i = 0; i < _states.length; i++) {
      final state = _states[i];
      test('${state.runtimeType} + ${event.runtimeType} -> '
          '${next[i].runtimeType}', () {
        expect(transitionAccess(state, event), next[i]);
      });
    }
  }

  group('guards', () {
    test('a key found for another environment starts a new session', () {
      expect(
        transitionAccess(_signedIn, const AccessFoundKey(_other)),
        const ExchangeAccessSignedIn(_other),
      );
    });

    test('a rejection for another epoch leaves the session alone', () {
      expect(
        transitionAccess(_signedIn, const AccessSessionRejected(2)),
        _signedIn,
      );
    });

    test('an expiry of another epoch does not end the expiring one', () {
      expect(
        transitionAccess(_expiring, const AccessExpiryCompleted(9)),
        _expiring,
      );
    });

    test('a key stored while signed in replaces the session', () {
      expect(
        transitionAccess(_signedIn, const AccessKeyStored(_other)),
        const ExchangeAccessSignedIn(_other),
      );
    });
  });

  test('every state is reachable from resolving', () {
    final reached = <Type>{_resolving.runtimeType};
    var frontier = <ExchangeAccess>[_resolving];
    final events = [
      for (final (event, _) in _table) event,
      const AccessFoundKey(_current),
    ];
    while (frontier.isNotEmpty) {
      final next = <ExchangeAccess>[];
      for (final state in frontier) {
        for (final event in events) {
          final target = transitionAccess(state, event);
          if (reached.add(target.runtimeType)) next.add(target);
        }
      }
      frontier = next;
    }
    expect(reached, {for (final state in _states) state.runtimeType});
  });

  test('a sign-in is accepted only while the exchange is enabled', () {
    expect(
      {for (final state in _states) state.runtimeType: accessAcceptsKey(state)},
      {
        ExchangeAccessResolving: false,
        ExchangeAccessUnreadable: false,
        ExchangeAccessDisabled: false,
        ExchangeAccessSignOutIncomplete: false,
        ExchangeAccessSignedOut: true,
        ExchangeAccessSignedIn: true,
        ExchangeAccessExpiring: true,
        ExchangeAccessCredentialUnreadable: true,
      },
    );
  });
}
