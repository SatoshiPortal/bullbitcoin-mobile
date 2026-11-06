import 'dart:io';

import 'package:bull_pricer/bull_pricer.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

import 'fake_price_api.dart';

// Pricer is static and cannot be closed, so this file shares one pricer and
// one cache across its tests, in order. Each test reads its own currency, so
// no test is served a price another one cached. Every test file runs in its
// own isolate, so the pricer starts uninitialised here.
void main() {
  late Directory directory;
  late FakePriceApi api;

  setUpAll(() => directory = Directory.systemTemp.createTempSync('pricer'));
  tearDownAll(() => directory.deleteSync(recursive: true));

  setUp(() async => api = await FakePriceApi.start());
  tearDown(() => api.close());

  String databasePath(String name) => '${directory.path}/$name.sqlite';

  double amount(Result<BitcoinPrice, PricerFailure> result) => switch (result) {
    Ok(:final value) => value.fiatAmount,
    Err(:final failure) => fail('Expected a price, got $failure'),
  };

  test('asking a price before init is a programming error', () {
    expect(
      () => Pricer.getIndexPrice(
        network: BitcoinNetwork.mainnet,
        currency: SupportedCurrency.usd,
      ),
      throwsStateError,
    );
  });

  group('once initialised', () {
    setUp(() => Pricer.init(databasePath: databasePath('pricer')));

    test('a second init keeps the first database', () async {
      await Pricer.init(databasePath: databasePath('other'));

      expect(File(databasePath('other')).existsSync(), isFalse);
    });

    test('the index price on mainnet is asked on mainnet', () async {
      expect(
        amount(
          await Pricer.getIndexPrice(
            network: BitcoinNetwork.mainnet,
            currency: SupportedCurrency.usd,
          ),
        ),
        mainnetIndexPrice / 100,
      );
      expect(api.requests.single.host, 'api.bullbitcoin.com');
      expect(api.requests.single.apiKey, isNull);
    });

    test('the index price on testnet is asked on testnet', () async {
      expect(
        amount(
          await Pricer.getIndexPrice(
            network: BitcoinNetwork.testnet,
            currency: SupportedCurrency.eur,
          ),
        ),
        testnetIndexPrice / 100,
      );
      expect(api.requests.single.host, 'api05.bullbitcoin.dev');
    });

    test('callers share the cached price', () async {
      for (var i = 0; i < 3; i++) {
        amount(
          await Pricer.getIndexPrice(
            network: BitcoinNetwork.mainnet,
            currency: SupportedCurrency.ars,
          ),
        );
      }

      expect(api.requests, hasLength(1));
    });
  });
}
