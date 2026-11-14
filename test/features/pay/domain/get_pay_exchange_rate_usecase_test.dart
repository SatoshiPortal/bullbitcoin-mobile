import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/pay/domain/get_pay_exchange_rate_usecase.dart';
import 'package:bb_mobile/features/pay/domain/pay_failure.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

import '../../../fake_index_price_reader.dart';

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
  late GetPayExchangeRateUsecase usecase;

  setUp(() {
    getSettings = _MockGetSettings();
    when(getSettings.execute).thenAnswer((_) async => _settings());
    getIndexPrice = FakeIndexPriceReader(fiatAmount: 114214.20);
    usecase = GetPayExchangeRateUsecase(
      getSettingsUsecase: getSettings,
      getIndexPrice: getIndexPrice.call,
    );
  });

  test('gives the mainnet price of one bitcoin in the currency', () async {
    final result = await usecase.execute(currencyCode: 'CAD');

    expect((result as Ok<double, PayFailure>).value, 114214.20);
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
      isA<Ok<double, PayFailure>>(),
    );

    expect(getIndexPrice.requests.single.network, BitcoinNetwork.testnet);
  });

  test('no price is an unavailable quote, not a zero rate', () async {
    getIndexPrice.failure = const PricerRateLimitedFailure('429');

    final result = await usecase.execute(currencyCode: 'CAD');

    expect(
      (result as Err<double, PayFailure>).failure,
      isA<PayQuoteUnavailableFailure>(),
    );
  });

  test('a currency without a price is unexpected, never asked', () async {
    final result = await usecase.execute(currencyCode: 'JPY');

    expect(
      (result as Err<double, PayFailure>).failure,
      isA<PayUnexpectedFailure>(),
    );
    expect(getIndexPrice.requests, isEmpty);
  });

  test('a failed settings read is sanitized', () async {
    when(getSettings.execute).thenThrow(Exception('storage locked'));

    final result = await usecase.execute(currencyCode: 'CAD');

    expect(
      (result as Err<double, PayFailure>).failure,
      isA<PayUnexpectedFailure>(),
    );
    expect(getIndexPrice.requests, isEmpty);
  });
}
