import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

final class _Preferences implements ExchangeTestnetBasicAuthPreferences {
  final Result<ExchangeWebPreferences, PreferencesFailure> _value;

  const _Preferences(this._value);

  @override
  Future<Result<ExchangeWebPreferences, PreferencesFailure>>
  readExchangeWebPreferences() async => _value;

  @override
  Future<Result<void, PreferencesFailure>> setExchangeTestnetBasicAuth({
    String? username,
    String? password,
  }) async => throw StateError('Unexpected credentials write');
}

void main() {
  final mainnet = Uri.parse('https://verify.example.invalid');
  final testnet = Uri.parse('https://verify-testnet.example.invalid');

  Exchange open(Result<ExchangeWebPreferences, PreferencesFailure> settings) {
    final exchange = Exchange.open(
      mainnetEndpoint: mainnet,
      testnetEndpoint: testnet,
      readSession: () async => fail('KYC must not read a session key'),
      kyc: (
        mainnetUrl: mainnet,
        testnetUrl: testnet,
        preferences: _Preferences(settings),
      ),
    );
    addTearDown(exchange.close);
    return exchange;
  }

  test('testnet authentication is never sent to mainnet', () async {
    final exchange = open(
      const Ok((
        environment: Environment.mainnet,
        exchangeTestnetBasicAuthUsername: 'test-user',
        exchangeTestnetBasicAuthPassword: 'test-password',
      )),
    );
    final result = await exchange.loadKyc();
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
    final exchange = open(
      const Ok((
        environment: Environment.testnet,
        exchangeTestnetBasicAuthUsername: 'test-user',
        exchangeTestnetBasicAuthPassword: 'test-password',
      )),
    );
    final result = await exchange.loadKyc();
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

  test('regtest cannot load a verification web view', () async {
    final exchange = open(
      const Ok((
        environment: Environment.regtest,
        exchangeTestnetBasicAuthUsername: null,
        exchangeTestnetBasicAuthPassword: null,
      )),
    );
    final result = await exchange.loadKyc();
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
    final exchange = open(const Err(PreferencesReadFailure()));
    final result = await exchange.loadKyc();
    expect(
      result,
      isA<Err<ExchangeKycConfiguration, ExchangeFailure>>().having(
        (err) => err.failure,
        'failure',
        isA<ExchangeUnexpectedFailure>(),
      ),
    );
  });
}
