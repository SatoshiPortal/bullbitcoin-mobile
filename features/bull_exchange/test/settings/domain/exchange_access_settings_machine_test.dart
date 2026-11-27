import 'package:bull_exchange/src/settings/domain/exchange_access_settings_machine.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';

const _off = ExchangeAccessDisabled();
const _signedOut = ExchangeAccessSignedOut(ExchangeEnvironment.mainnet);
const _incomplete = ExchangeAccessSignOutIncomplete();
const _resolving = ExchangeAccessResolving();
const _failure = ExchangeSessionClearFailure();

const _enable = ExchangeAccessAttempt.enable;
const _signOut = ExchangeAccessAttempt.signOut;
const _retry = ExchangeAccessAttempt.retry;

void main() {
  final states = <String, ExchangeAccessSettingsState>{
    'Idle(off)': const AccessSettingsIdle(_off),
    'Idle(signOutIncomplete)': const AccessSettingsIdle(_incomplete),
    'Idle(resolving)': const AccessSettingsIdle(_resolving),
    'Working(off, enable)': const AccessSettingsWorking(_off, _enable),
    'Succeeded(signedOut, enable)': const AccessSettingsSucceeded(
      _signedOut,
      _enable,
    ),
    'Failed(off, signOut)': const AccessSettingsFailed(
      _off,
      _signOut,
      _failure,
    ),
  };
  final events = <String, ExchangeAccessSettingsEvent>{
    'AccessChanged(off)': const AccessSettingsAccessChanged(_off),
    'AccessChanged(signedOut)': const AccessSettingsAccessChanged(_signedOut),
    'EnableRequested': const AccessSettingsEnableRequested(),
    'SignOutRequested': const AccessSettingsSignOutRequested(),
    'RetryRequested': const AccessSettingsRetryRequested(),
    'AttemptSucceeded(signedOut)': const AccessSettingsAttemptSucceeded(
      _signedOut,
    ),
    'AttemptFailed': const AccessSettingsAttemptFailed(_failure),
  };

  // Rows follow [events]; one expected state per pair.
  final table = <String, List<ExchangeAccessSettingsState>>{
    'Idle(off)': [
      const AccessSettingsIdle(_off),
      const AccessSettingsIdle(_signedOut),
      const AccessSettingsWorking(_off, _enable),
      const AccessSettingsWorking(_off, _signOut),
      const AccessSettingsWorking(_off, _retry),
      const AccessSettingsIdle(_off),
      const AccessSettingsIdle(_off),
    ],
    'Idle(signOutIncomplete)': [
      const AccessSettingsIdle(_off),
      const AccessSettingsIdle(_signedOut),
      // An unfinished sign-out must finish before enabling.
      const AccessSettingsIdle(_incomplete),
      const AccessSettingsWorking(_incomplete, _signOut),
      const AccessSettingsWorking(_incomplete, _retry),
      const AccessSettingsIdle(_incomplete),
      const AccessSettingsIdle(_incomplete),
    ],
    'Idle(resolving)': [
      const AccessSettingsIdle(_off),
      const AccessSettingsIdle(_signedOut),
      const AccessSettingsIdle(_resolving),
      const AccessSettingsWorking(_resolving, _signOut),
      const AccessSettingsWorking(_resolving, _retry),
      const AccessSettingsIdle(_resolving),
      const AccessSettingsIdle(_resolving),
    ],
    'Working(off, enable)': [
      const AccessSettingsWorking(_off, _enable),
      const AccessSettingsWorking(_signedOut, _enable),
      // One attempt at a time.
      const AccessSettingsWorking(_off, _enable),
      const AccessSettingsWorking(_off, _enable),
      const AccessSettingsWorking(_off, _enable),
      const AccessSettingsSucceeded(_signedOut, _enable),
      const AccessSettingsFailed(_off, _enable, _failure),
    ],
    'Succeeded(signedOut, enable)': [
      const AccessSettingsIdle(_off),
      const AccessSettingsSucceeded(_signedOut, _enable),
      const AccessSettingsWorking(_signedOut, _enable),
      const AccessSettingsWorking(_signedOut, _signOut),
      const AccessSettingsWorking(_signedOut, _retry),
      const AccessSettingsSucceeded(_signedOut, _enable),
      const AccessSettingsSucceeded(_signedOut, _enable),
    ],
    'Failed(off, signOut)': [
      // The same access again is not a transition: the failure stays.
      const AccessSettingsFailed(_off, _signOut, _failure),
      // The next access transition drops it (INT-15).
      const AccessSettingsIdle(_signedOut),
      const AccessSettingsWorking(_off, _enable),
      const AccessSettingsWorking(_off, _signOut),
      const AccessSettingsWorking(_off, _retry),
      const AccessSettingsFailed(_off, _signOut, _failure),
      const AccessSettingsFailed(_off, _signOut, _failure),
    ],
  };

  test('the table names every (state, event) pair', () {
    expect(table.keys, states.keys);
    for (final row in table.values) {
      expect(row, hasLength(events.length));
    }
  });

  for (final MapEntry(key: stateName, value: state) in states.entries) {
    final eventNames = events.keys.toList();
    for (var i = 0; i < eventNames.length; i++) {
      final eventName = eventNames[i];
      test('$stateName x $eventName', () {
        expect(state.next(events[eventName]!), table[stateName]![i]);
      });
    }
  }

  test('a working attempt keeps running across access changes', () {
    var state = (const AccessSettingsIdle(_signedOut))
        .next(const AccessSettingsSignOutRequested());
    state = state.next(const AccessSettingsAccessChanged(_incomplete));
    expect(state, const AccessSettingsWorking(_incomplete, _signOut));
    state = state.next(const AccessSettingsAttemptSucceeded(_off));
    expect(state, const AccessSettingsSucceeded(_off, _signOut));
  });

  group('sameAccess', () {
    test('compares states without fields by kind', () {
      // ignore: prefer_const_constructors
      expect(sameAccess(ExchangeAccessDisabled(), _off), isTrue);
      expect(sameAccess(_off, _incomplete), isFalse);
    });
    test('compares sessions and environments by value', () {
      expect(
        sameAccess(
          _signedOut,
          const ExchangeAccessSignedOut(ExchangeEnvironment.testnet),
        ),
        isFalse,
      );
      expect(
        sameAccess(
          const ExchangeAccessExpiring(
            ExchangeSession(
              environment: ExchangeEnvironment.mainnet,
              epoch: 1,
              sessionId: 'a',
            ),
          ),
          const ExchangeAccessSignedIn(
            ExchangeSession(
              environment: ExchangeEnvironment.mainnet,
              epoch: 1,
              sessionId: 'a',
            ),
          ),
        ),
        isFalse,
      );
    });
  });

  group('accessSettingsCanEnable', () {
    final expected = <ExchangeAccess, bool>{
      _resolving: false,
      _incomplete: false,
      const ExchangeAccessUnreadable(): true,
      _off: true,
      _signedOut: true,
      const ExchangeAccessCredentialUnreadable(ExchangeEnvironment.mainnet):
          true,
    };
    for (final MapEntry(key: access, value: allowed) in expected.entries) {
      test('${access.runtimeType} -> $allowed', () {
        expect(accessSettingsCanEnable(access), allowed);
      });
    }
  });
}
