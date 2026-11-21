import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/bitcoin_price/domain/usecases/get_bitcoin_price_usecase.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

import '../../../../fake_index_price_reader.dart';

class _MockActiveEnvironment extends Mock implements ActiveEnvironmentReader {}

void main() {
  late _MockActiveEnvironment environment;
  late FakeIndexPriceReader getIndexPrice;
  late GetBitcoinPriceUsecase usecase;

  setUp(() {
    environment = _MockActiveEnvironment();
    when(environment.readActiveEnvironment)
        .thenAnswer((_) async => Environment.mainnet);
    getIndexPrice = FakeIndexPriceReader(fiatAmount: 114214.20);
    usecase = GetBitcoinPriceUsecase(
      environment: environment,
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
    when(environment.readActiveEnvironment)
        .thenAnswer((_) async => Environment.testnet);

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
    when(environment.readActiveEnvironment)
        .thenThrow(Exception('storage locked'));

    final result = await usecase.execute(currencyCode: 'CAD');

    expect(
      (result as Err<double, PricerFailure>).failure,
      isA<PricerUnexpectedFailure>(),
    );
    expect(getIndexPrice.requests, isEmpty);
  });
}
