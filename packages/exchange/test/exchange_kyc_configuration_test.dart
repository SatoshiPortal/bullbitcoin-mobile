import 'package:exchange/exchange.dart';
import 'package:exchange/setup.dart';
import 'package:exchange/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

class _Preferences extends Mock implements Preferences {}

final class _UnreadableStorage extends InMemoryExchangeCredentialStorage {
  @override
  Future<ExchangeBasicAuthValues> readBasicAuth() async =>
      throw const FormatException();
}

void main() {
  final mainnet = Uri.parse('https://verify.example.invalid');
  final testnet = Uri.parse('https://verify-testnet.example.invalid');

  Exchange open(
    Result<Environment, PreferencesFailure> environment, {
    InMemoryExchangeCredentialStorage? storage,
  }) {
    final preferences = _Preferences();
    when(preferences.readActiveEnvironment)
        .thenAnswer((_) async => environment);
    final exchange = Exchange.open(
      mainnetEndpoint: mainnet,
      testnetEndpoint: testnet,
      readSession: () async => fail('KYC must not read a session key'),
      sessionPreferences: preferences,
      basicAuth: ExchangeCredentials.openBasicAuth(
        storage ??
            (InMemoryExchangeCredentialStorage()
              ..username = 'test-user'
              ..password = 'test-password'),
      ),
      kyc: (mainnetUrl: mainnet, testnetUrl: testnet),
    );
    addTearDown(exchange.close);
    return exchange;
  }

  test('testnet authentication is never sent to mainnet', () async {
    final result = await open(const Ok(Environment.mainnet)).loadKyc();
    expect(
      result,
      isA<Ok<ExchangeKycConfiguration, ExchangeFailure>>().having(
        (ok) => ok.value,
        'configuration',
        (url: mainnet, basicAuth: null),
      ),
    );
  });

  test('testnet configuration carries complete credentials', () async {
    final result = await open(const Ok(Environment.testnet)).loadKyc();
    expect(
      result,
      isA<Ok<ExchangeKycConfiguration, ExchangeFailure>>().having(
        (ok) => ok.value,
        'configuration',
        (
          url: testnet,
          basicAuth: (username: 'test-user', password: 'test-password'),
        ),
      ),
    );
  });

  test('a half-stored credential is not sent', () async {
    final result = await open(
      const Ok(Environment.testnet),
      storage: InMemoryExchangeCredentialStorage()..username = 'test-user',
    ).loadKyc();
    expect(
      result,
      isA<Ok<ExchangeKycConfiguration, ExchangeFailure>>().having(
        (ok) => ok.value,
        'configuration',
        (url: testnet, basicAuth: null),
      ),
    );
  });

  test('regtest cannot load a verification web view', () async {
    final result = await open(const Ok(Environment.regtest)).loadKyc();
    expect(
      result,
      isA<Err<ExchangeKycConfiguration, ExchangeFailure>>().having(
        (err) => err.failure,
        'failure',
        isA<ExchangeUnsupportedNetworkFailure>(),
      ),
    );
  });

  test('a preference read failure produces a typed failure', () async {
    final result = await open(const Err(PreferencesReadFailure())).loadKyc();
    expect(
      result,
      isA<Err<ExchangeKycConfiguration, ExchangeFailure>>().having(
        (err) => err.failure,
        'failure',
        isA<ExchangeUnexpectedFailure>(),
      ),
    );
  });

  test('an unreadable credential store is reported, not emptied', () async {
    final result = await open(
      const Ok(Environment.testnet),
      storage: _UnreadableStorage(),
    ).loadKyc();
    expect(
      result,
      isA<Err<ExchangeKycConfiguration, ExchangeFailure>>().having(
        (err) => err.failure,
        'failure',
        isA<ExchangeCredentialReadFailure>(),
      ),
    );
  });
}
