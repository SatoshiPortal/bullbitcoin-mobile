import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/swap/domain/swap_failure.dart';
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

double _rate(Result<double, SwapFailure> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => fail('Expected a rate, got $failure'),
};

SwapFailure _failure(Result<double, SwapFailure> result) => switch (result) {
  Ok(:final value) => fail('Expected a failure, got $value'),
  Err(:final failure) => failure,
};

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
      expect(_rate(await usecase.execute()), 114214.20);
      expect(getIndexPrice.requests.single, (
        network: BitcoinNetwork.mainnet,
        currency: SupportedCurrency.usd,
      ));
    },
  );

  test('asks the requested currency', () async {
    expect(_rate(await usecase.execute(currencyCode: 'cad')), 114214.20);
    expect(getIndexPrice.requests.single.currency, SupportedCurrency.cad);
  });

  test('asks the testnet price in the testnet environment', () async {
    when(
      getSettings.execute,
    ).thenAnswer((_) async => _settings(environment: Environment.testnet));

    _rate(await usecase.execute());
    expect(getIndexPrice.requests.single.network, BitcoinNetwork.testnet);
  });

  test('no price is a price unavailable failure', () async {
    getIndexPrice.failure = const PricerNetworkFailure('offline');

    expect(
      _failure(await usecase.execute()),
      isA<SwapPriceUnavailableFailure>(),
    );
  });

  test('a currency without a price is a price unavailable failure, never '
      'asked', () async {
    expect(
      _failure(await usecase.execute(currencyCode: 'JPY')),
      isA<SwapPriceUnavailableFailure>(),
    );
    expect(getIndexPrice.requests, isEmpty);
  });

  test('a failed settings read is an unexpected failure', () async {
    when(getSettings.execute).thenThrow(Exception('storage locked'));

    expect(_failure(await usecase.execute()), isA<SwapUnexpectedFailure>());
    expect(getIndexPrice.requests, isEmpty);
  });
}
