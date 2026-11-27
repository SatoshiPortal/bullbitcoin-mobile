import 'package:bull_exchange/src/auth/exchange_auth_machine.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';

final _config = ExchangeAuthConfig(
  isTestnet: true,
  signInUrl: Uri.https('accounts.example.invalid'),
);
const _failure = ExchangeNetworkFailure();

const ExchangeAuthState _loading = AuthLoadingConfig();
const ExchangeAuthState _configFailed = AuthConfigFailed(_failure);
final ExchangeAuthState _browsing = AuthBrowsing(_config);
final ExchangeAuthState _generating = AuthGeneratingKey(_config);
final ExchangeAuthState _keyFailed = AuthKeyFailed(_config, _failure);
const ExchangeAuthState _done = AuthDone();
const ExchangeAuthState _closing = AuthClosing();

final _states = <String, ExchangeAuthState>{
  'LoadingConfig': _loading,
  'ConfigFailed': _configFailed,
  'Browsing': _browsing,
  'GeneratingKey': _generating,
  'KeyFailed': _keyFailed,
  'Done': _done,
  'Closing': _closing,
};

/// Per event, the next state from each entry of [_states], in order.
final _table = <String, (ExchangeAuthEvent, List<ExchangeAuthState>)>{
  'config loaded': (
    AuthConfigLoaded(_config),
    [
      _browsing,
      _configFailed,
      _browsing,
      _generating,
      _keyFailed,
      _done,
      _closing,
    ],
  ),
  'config unavailable': (
    const AuthConfigUnavailable(_failure),
    [
      _configFailed,
      _configFailed,
      _browsing,
      _generating,
      _keyFailed,
      _done,
      _closing,
    ],
  ),
  'retry': (
    const AuthRetryRequested(),
    [_loading, _loading, _browsing, _generating, _keyFailed, _done, _closing],
  ),
  'web session seen (B2: one key at a time)': (
    const AuthWebSessionSeen(),
    [
      _loading,
      _configFailed,
      _generating,
      _generating,
      _keyFailed,
      _done,
      _closing,
    ],
  ),
  'key stored (B2: Done on Ok)': (
    const AuthKeyStored(),
    [_loading, _configFailed, _browsing, _done, _keyFailed, _done, _closing],
  ),
  'key deferred': (
    const AuthKeyDeferred(),
    [
      _loading,
      _configFailed,
      _browsing,
      _browsing,
      _keyFailed,
      _done,
      _closing,
    ],
  ),
  'key not stored': (
    const AuthKeyNotStored(_failure),
    [
      _loading,
      _configFailed,
      _browsing,
      _keyFailed,
      _keyFailed,
      _done,
      _closing,
    ],
  ),
  'error acknowledged': (
    const AuthErrorAcknowledged(),
    [
      _loading,
      _configFailed,
      _browsing,
      _generating,
      _browsing,
      _done,
      _closing,
    ],
  ),
  'close requested': (
    const AuthCloseRequested(),
    [_closing, _closing, _closing, _closing, _closing, _done, _closing],
  ),
};

void main() {
  final names = _states.keys.toList();
  for (final MapEntry(key: row, value: (event, next)) in _table.entries) {
    test('row $row names every state', () {
      expect(next, hasLength(names.length));
    });
    for (var i = 0; i < names.length; i++) {
      test('${names[i]} + $row', () {
        expect((_states[names[i]]!).next(event), next[i]);
      });
    }
  }

  test('every state is reachable from LoadingConfig', () {
    final events = [for (final (event, _) in _table.values) event];
    final seen = <ExchangeAuthState>{_loading};
    var frontier = <ExchangeAuthState>[_loading];
    while (frontier.isNotEmpty) {
      final next = <ExchangeAuthState>[];
      for (final state in frontier) {
        for (final event in events) {
          final target = state.next(event);
          if (seen.add(target)) next.add(target);
        }
      }
      frontier = next;
    }
    expect(seen.map((s) => s.runtimeType).toSet(), {
      for (final state in _states.values) state.runtimeType,
    });
  });

  group('KYC WebView (B15)', () {
    for (final (state, event, next)
        in <(ExchangeKycState, ExchangeKycEvent, ExchangeKycState)>[
          (
            ExchangeKycState.browsing,
            const KycLeftFlow(),
            ExchangeKycState.leaving,
          ),
          (
            ExchangeKycState.browsing,
            const KycCloseRequested(),
            ExchangeKycState.leaving,
          ),
          (
            ExchangeKycState.leaving,
            const KycLeftFlow(),
            ExchangeKycState.leaving,
          ),
          (
            ExchangeKycState.leaving,
            const KycCloseRequested(),
            ExchangeKycState.leaving,
          ),
        ]) {
      test('${state.name} + ${event.runtimeType}', () {
        expect(state.next(event), next);
      });
    }
  });
}
