import 'package:bitcoin_price/src/domain/bitcoin_price_failure.dart';
import 'package:preferences/preferences.dart';
import 'package:bitcoin_price/src/domain/usecases/get_bitcoin_price_usecase.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockActiveEnvironment extends Mock implements ActiveEnvironmentReader {}

void main() {
  late _MockActiveEnvironment environment;
  late List<({BitcoinNetwork network, SupportedCurrency currency})> requests;
  PricerFailure? engineFailure;
  late GetBitcoinPriceUsecase usecase;

  setUp(() {
    environment = _MockActiveEnvironment();
    when(environment.readActiveEnvironment)
        .thenAnswer((_) async => Ok(Environment.mainnet));
    requests = [];
    engineFailure = null;
    usecase = GetBitcoinPriceUsecase(
      environment: environment,
      getIndexPrice: ({required currency, required network}) async {
        requests.add((network: network, currency: currency));
        final failure = engineFailure;
        if (failure != null) return Err(failure);
        return Ok(
          BitcoinPrice(
            currency: currency,
            fiatAmount: 114214.20,
            fetchedAt: DateTime.utc(2026),
          ),
        );
      },
    );
  });

  test('gives the mainnet price of one bitcoin in the currency', () async {
    final result = await usecase.execute(currencyCode: 'CAD');

    expect((result as Ok<double, BitcoinPriceFailure>).value, 114214.20);
    expect(requests.single, (
      network: BitcoinNetwork.mainnet,
      currency: SupportedCurrency.cad,
    ));
  });

  test('asks the testnet price in the testnet environment', () async {
    when(environment.readActiveEnvironment)
        .thenAnswer((_) async => Ok(Environment.testnet));

    expect(
      await usecase.execute(currencyCode: 'CAD'),
      isA<Ok<double, BitcoinPriceFailure>>(),
    );

    expect(requests.single.network, BitcoinNetwork.testnet);
  });

  test('rate limiting maps to an unavailable rate', () async {
    engineFailure = const PricerRateLimitedFailure('429');

    final result = await usecase.execute(currencyCode: 'CAD');

    expect(
      (result as Err<double, BitcoinPriceFailure>).failure,
      isA<BitcoinPriceRateUnavailableFailure>(),
    );
  });

  test('a currency without a price is unexpected, never asked', () async {
    final result = await usecase.execute(currencyCode: 'JPY');

    expect(
      (result as Err<double, BitcoinPriceFailure>).failure,
      isA<BitcoinPriceUnexpectedFailure>(),
    );
    expect(requests, isEmpty);
  });

  test('a failed settings read is sanitized', () async {
    when(environment.readActiveEnvironment)
        .thenAnswer((_) async => const Err(PreferencesReadFailure()));

    final result = await usecase.execute(currencyCode: 'CAD');

    expect(
      (result as Err<double, BitcoinPriceFailure>).failure,
      isA<BitcoinPricePreferencesFailure>(),
    );
    expect(requests, isEmpty);
  });
}
