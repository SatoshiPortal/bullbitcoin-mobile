import 'package:bull_exchange/setup.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';

class _Preferences extends Mock implements Preferences {}

void main() {
  late _Preferences preferences;

  setUp(() {
    preferences = _Preferences();
  });

  Future<ExchangeAvailability> tradingEntry(ExchangePlatform platform) async {
    final exchange = BullExchangeServices.open(
      storage: InMemoryExchangeCredentialStorage(),
      preferences: preferences,
      platform: platform,
    );
    addTearDown(exchange.close);
    final result = await exchange.guardTradingEntry();
    return (result as Ok<ExchangeAvailability, ExchangeFailure>).value;
  }

  test(
    'unreadable iOS preferences send trading to the website without failing',
    () async {
      when(preferences.fetch)
          .thenAnswer((_) async => const Err(PreferencesReadFailure()));

      expect(
        await tradingEntry(ExchangePlatform.ios),
        ExchangeAvailability.websiteOnly,
      );
    },
  );

  test('the non-iOS platform check does not read preferences', () async {
    expect(
      await tradingEntry(ExchangePlatform.other),
      isNot(ExchangeAvailability.websiteOnly),
    );
    verifyZeroInteractions(preferences);
  });

  test('the iOS superuser override keeps trading reachable', () async {
    when(preferences.fetch).thenAnswer(
      (_) async => const Ok(
        SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.btc,
          currencyCode: 'CAD',
          isSuperuser: true,
        ),
      ),
    );

    expect(
      await tradingEntry(ExchangePlatform.ios),
      isNot(ExchangeAvailability.websiteOnly),
    );
  });
}
