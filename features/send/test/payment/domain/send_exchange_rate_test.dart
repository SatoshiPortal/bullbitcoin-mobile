import 'package:preferences/preferences.dart';
import 'package:send/send.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockGetSettings extends Mock implements Preferences {}

SettingsEntity _settings({Environment environment = Environment.mainnet}) =>
    SettingsEntity(
      environment: environment,
      bitcoinUnit: BitcoinUnit.sats,
      currencyCode: 'USD',
    );

double _rate(Result<double, SendFailure> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => fail('Expected a rate, got $failure'),
};

SendFailure _failure(Result<double, SendFailure> result) => switch (result) {
  Ok(:final value) => fail('Expected a failure, got $value'),
  Err(:final failure) => failure,
};

void main() {
  late _MockGetSettings getSettings;
  late _FakeIndexPriceReader getIndexPrice;
  late Send send;

  setUp(() {
    getSettings = _MockGetSettings();
    when(getSettings.fetch).thenAnswer((_) async => Ok(_settings()));
    getIndexPrice = _FakeIndexPriceReader(fiatAmount: 114214.20);
    send = Send.open(preferences: getSettings, readPrice: getIndexPrice.call);
  });

  test(
    'gives the mainnet price of one bitcoin in the settings currency',
    () async {
      expect(_rate(await send.exchangeRate()), 114214.20);
      expect(getIndexPrice.requests.single, (
        network: BitcoinNetwork.mainnet,
        currency: SupportedCurrency.usd,
      ));
    },
  );

  test('asks the requested currency', () async {
    expect(_rate(await send.exchangeRate(currencyCode: 'cad')), 114214.20);
    expect(getIndexPrice.requests.single.currency, SupportedCurrency.cad);
  });

  test('asks the testnet price in the testnet environment', () async {
    when(
      getSettings.fetch,
    ).thenAnswer((_) async => Ok(_settings(environment: Environment.testnet)));

    _rate(await send.exchangeRate());
    expect(getIndexPrice.requests.single.network, BitcoinNetwork.testnet);
  });

  test('no price is a price unavailable failure', () async {
    getIndexPrice.failure = const PricerNetworkFailure('offline');

    expect(
      _failure(await send.exchangeRate()),
      isA<SendPriceUnavailableFailure>(),
    );
  });

  test('a currency without a price is a price unavailable failure, never '
      'asked', () async {
    expect(
      _failure(await send.exchangeRate(currencyCode: 'JPY')),
      isA<SendPriceUnavailableFailure>(),
    );
    expect(getIndexPrice.requests, isEmpty);
  });

  test('a failed settings read is an unexpected failure', () async {
    when(getSettings.fetch).thenThrow(Exception('storage locked'));

    expect(_failure(await send.exchangeRate()), isA<SendUnexpectedFailure>());
    expect(getIndexPrice.requests, isEmpty);
  });
}

/// Stands in for `Pricer.getIndexPrice`: answers [fiatAmount] in the
/// requested currency, or [failure] when set, and records each request.
class _FakeIndexPriceReader {
  double fiatAmount;
  PricerFailure? failure;
  DateTime fetchedAt = DateTime.utc(2026, 11, 4, 12);
  final List<({BitcoinNetwork network, SupportedCurrency currency})> requests =
      [];

  _FakeIndexPriceReader({this.fiatAmount = 100000, this.failure});

  Future<Result<BitcoinPrice, PricerFailure>> call({
    required BitcoinNetwork network,
    required SupportedCurrency currency,
  }) async {
    requests.add((network: network, currency: currency));
    final failure = this.failure;
    if (failure != null) return Err(failure);
    return Ok(
      BitcoinPrice(
        currency: currency,
        fiatAmount: fiatAmount,
        fetchedAt: fetchedAt,
      ),
    );
  }
}
