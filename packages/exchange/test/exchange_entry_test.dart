import 'package:exchange/exchange.dart';
import 'package:exchange/setup.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';

class _Preferences extends Mock implements Preferences {}

class _Access extends Mock implements ExchangeAccessLifecycle {}

class _Credentials extends Mock implements ExchangeCredentials {}

void main() {
  group('networkUnavailable', () {
    late _Preferences preferences;

    setUp(() => preferences = _Preferences());

    void stubEnvironment(Environment environment) =>
        when(preferences.readActiveEnvironment)
            .thenAnswer((_) async => Ok(environment));

    Exchange open() => exchangeForTesting(
      sessionPreferences: preferences,
      basicAuth: ExchangeCredentials.openBasicAuth(
        InMemoryExchangeCredentialStorage(),
      ),
    );

    test('only a network without Exchange redirects entry', () async {
      final exchange = open();

      stubEnvironment(Environment.regtest);
      expect(await exchange.networkUnavailable(), isTrue);
      stubEnvironment(Environment.mainnet);
      expect(await exchange.networkUnavailable(), isFalse);
    });

    test('an unreadable preference does not hide Exchange', () async {
      when(preferences.readActiveEnvironment)
          .thenAnswer((_) async => const Err(PreferencesReadFailure()));

      expect(await open().networkUnavailable(), isFalse);
    });
  });

  group('guardTradingEntry', () {
    test('is unavailable without an access lifecycle', () async {
      final result = await exchangeForTesting().guardTradingEntry();

      expect(
        result,
        isA<Err<ExchangeAvailability, ExchangeFailure>>().having(
          (err) => err.failure,
          'failure',
          isA<ExchangeAccountUnavailableFailure>(),
        ),
      );
    });

    test('returns the lifecycle decision', () async {
      final access = _Access();
      when(
        access.tradingAvailability,
      ).thenAnswer((_) async => const Ok(ExchangeAvailability.signInRequired));

      final result = await exchangeForTesting(access: access)
          .guardTradingEntry();

      expect(
        (result as Ok<ExchangeAvailability, ExchangeFailure>).value,
        ExchangeAvailability.signInRequired,
      );
    });

    test(
      'a platform refusal sends trading to the website without reconciling',
      () async {
        final access = ExchangeAccessLifecycle.open(
          apiKeyRepository: _Credentials(),
          readEnvironment: () async => false,
          platformAllowed: () async => false,
          disconnectNotifications: () async {},
          clearCookies: () async {},
          readPreference: () async => null,
          writePreference: (_) async => true,
        );

        final result = await access.tradingAvailability();

        expect(
          (result as Ok<ExchangeAvailability, ExchangeFailure>).value,
          ExchangeAvailability.websiteOnly,
        );
      },
    );
  });
}
