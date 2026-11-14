import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/bitcoin_price/domain/usecases/get_bitcoin_price_usecase.dart';
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
  late GetBitcoinPriceUsecase usecase;

  setUp(() {
    getSettings = _MockGetSettings();
    when(getSettings.execute).thenAnswer((_) async => _settings());
    getIndexPrice = FakeIndexPriceReader(fiatAmount: 114214.20);
    usecase = GetBitcoinPriceUsecase(
      getSettingsUsecase: getSettings,
      getIndexPrice: getIndexPrice.call,
    );
  });

  test('gives the mainnet price of one bitcoin in the currency', () async {
    final result = await usecase.execute(currencyCode: 'CAD');

    expect((result as Ok<double, PricerFailure>).value, 114214.20);
    expect(getIndexPrice.requests.single, (
      network: BitcoinNetwork.mainnet,
      currency: SupportedCurrency.cad,
    ));
  });

  test('asks the testnet price in the testnet environment', () async {
    when(
      getSettings.execute,
    ).thenAnswer((_) async => _settings(environment: Environment.testnet));

    expect(
      await usecase.execute(currencyCode: 'CAD'),
      isA<Ok<double, PricerFailure>>(),
    );

    expect(getIndexPrice.requests.single.network, BitcoinNetwork.testnet);
  });

  test('no price is the pricer failure, as it came', () async {
    getIndexPrice.failure = const PricerRateLimitedFailure('429');

    final result = await usecase.execute(currencyCode: 'CAD');

    expect(
      (result as Err<double, PricerFailure>).failure,
      isA<PricerRateLimitedFailure>(),
    );
  });

  test('a currency without a price is unexpected, never asked', () async {
    final result = await usecase.execute(currencyCode: 'JPY');

    expect(
      (result as Err<double, PricerFailure>).failure,
      isA<PricerUnexpectedFailure>(),
    );
    expect(getIndexPrice.requests, isEmpty);
  });

  test('a failed settings read is sanitized', () async {
    when(getSettings.execute).thenThrow(Exception('storage locked'));

    final result = await usecase.execute(currencyCode: 'CAD');

    expect(
      (result as Err<double, PricerFailure>).failure,
      isA<PricerUnexpectedFailure>(),
    );
    expect(getIndexPrice.requests, isEmpty);
  });
}
