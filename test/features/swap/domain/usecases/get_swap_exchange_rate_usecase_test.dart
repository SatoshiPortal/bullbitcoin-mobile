import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/swap/domain/usecases/get_swap_exchange_rate_usecase.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

import '../../../../fake_index_price_reader.dart';

class _MockGetSettings extends Mock implements GetSettingsUsecase {}

SettingsEntity _settings({Environment environment = Environment.mainnet}) =>
    SettingsEntity(
      environment: environment,
      bitcoinUnit: BitcoinUnit.sats,
      currencyCode: 'USD',
    );

void main() {
  late _MockGetSettings getSettings;
  late FakeIndexPriceReader getIndexPrice;
  late GetSwapExchangeRateUsecase usecase;

  setUp(() {
    getSettings = _MockGetSettings();
    when(getSettings.execute).thenAnswer((_) async => _settings());
    getIndexPrice = FakeIndexPriceReader(fiatAmount: 114214.20);
    usecase = GetSwapExchangeRateUsecase(
      getSettingsUsecase: getSettings,
      getIndexPrice: getIndexPrice.call,
    );
  });

  test(
    'gives the mainnet price of one bitcoin in the settings currency',
    () async {
      expect(await usecase.execute(), 114214.20);
      expect(getIndexPrice.requests.single, (
        network: BitcoinNetwork.mainnet,
        currency: SupportedCurrency.usd,
      ));
    },
  );

  test('asks the requested currency', () async {
    expect(await usecase.execute(currencyCode: 'cad'), 114214.20);
    expect(getIndexPrice.requests.single.currency, SupportedCurrency.cad);
  });

  test('asks the testnet price in the testnet environment', () async {
    when(
      getSettings.execute,
    ).thenAnswer((_) async => _settings(environment: Environment.testnet));

    expect(await usecase.execute(), isNotNull);
    expect(getIndexPrice.requests.single.network, BitcoinNetwork.testnet);
  });

  test('no price is no rate', () async {
    getIndexPrice.failure = const PricerNetworkFailure('offline');

    expect(await usecase.execute(), isNull);
  });

  test('a currency without a price is no rate, never asked', () async {
    expect(await usecase.execute(currencyCode: 'JPY'), isNull);
    expect(getIndexPrice.requests, isEmpty);
  });

  test('a failed settings read is no rate', () async {
    when(getSettings.execute).thenThrow(Exception('storage locked'));

    expect(await usecase.execute(), isNull);
    expect(getIndexPrice.requests, isEmpty);
  });
}
