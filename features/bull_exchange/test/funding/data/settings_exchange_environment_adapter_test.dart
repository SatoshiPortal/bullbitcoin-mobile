import 'package:preferences/preferences.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/setup.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _Settings extends Mock implements Preferences {}

void main() {
  test('regtest refuses funding before either repository', () async {
    final settings = _Settings();
    when(() => settings.fetch()).thenAnswer(
      (_) async => Ok(
        const SettingsEntity(
          environment: Environment.regtest,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
        ),
      ),
    );
    final exchange = exchangeWithTransportForTesting(
      readSession: () => readLegacyExchangeSession(
        preferences: settings,
        readSession: () => null,
        readKey: ({required isTestnet}) async => fail('unexpected key read'),
      ),
      openClient: (_, _) => fail('unexpected HTTP request'),
    );

    expect(
      await exchange.funding.consent(
        const ExchangeSession(
          environment: ExchangeEnvironment.testnet,
          epoch: 0,
          sessionId: 'session',
        ),
      ),
      isA<Err<void, ExchangeWriteFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<ExchangeWriteNotSentFailure>().having(
          (result) => result.reason,
          'reason',
          ExchangeNotSentReason.unreachable,
        ),
      ),
    );
  });
}
