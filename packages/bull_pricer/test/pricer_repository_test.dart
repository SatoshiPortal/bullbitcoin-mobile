import 'dart:async';
import 'dart:io';

import 'package:bull_pricer/src/data/datasources/pricer_cache_datasource.dart';
import 'package:bull_pricer/src/data/pricer_database.dart';
import 'package:bull_pricer/src/data/pricer_repository.dart';
import 'package:bull_pricer/src/domain/entities/bitcoin_price.dart';
import 'package:bull_pricer/src/domain/entities/supported_currency.dart';
import 'package:bull_pricer/src/domain/pricer_failure.dart';
import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

import 'fake_price_api.dart';

void main() {
  const mainnet = BitcoinNetwork.mainnet;
  const testnet = BitcoinNetwork.testnet;
  const cad = SupportedCurrency.cad;

  late FakePriceApi api;
  late PricerDatabase database;
  late PricerRepository repository;
  var now = DateTime.utc(2026, 10, 26, 12);

  setUp(() async {
    api = await FakePriceApi.start();
    database = PricerDatabase.forTesting(NativeDatabase.memory());
    repository = PricerRepository(
      pricerCacheDatasource: PricerCacheDatasource(database),
    );
    now = DateTime.utc(2026, 10, 26, 12);
  });

  tearDown(() async {
    await database.close();
    await api.close();
  });

  /// Runs [body] with the clock reading [now].
  Future<T> atNow<T>(Future<T> Function() body) =>
      withClock(Clock(() => now), body);

  BitcoinPrice price(Result<BitcoinPrice, PricerFailure> result) =>
      switch (result) {
        Ok(:final value) => value,
        Err(:final failure) => fail('Expected a price, got $failure'),
      };

  double amount(Result<BitcoinPrice, PricerFailure> result) =>
      price(result).fiatAmount;

  PricerFailure failure(Result<BitcoinPrice, PricerFailure> result) =>
      switch (result) {
        Ok(:final value) => fail('Expected a failure, got $value'),
        Err(:final failure) => failure,
      };

  group('prices', () {
    test('the index price comes from getRate, without the API key', () async {
      expect(
        amount(
          await atNow(
            () => repository.indexPrice(network: mainnet, currency: cad),
          ),
        ),
        closeTo(114214.20, 1e-9),
      );
      expect(api.requests.single.method, 'getRate');
      expect(api.requests.single.apiKey, isNull);
    });

    test('each network is asked on its own host', () async {
      expect(
        amount(
          await atNow(
            () => repository.indexPrice(network: testnet, currency: cad),
          ),
        ),
        testnetIndexPrice / 100,
      );
      expect(api.requests.single.host, 'api05.bullbitcoin.dev');
    });

    test(
      'a network without a price service is a failure, never asked',
      () async {
        for (final network in [BitcoinNetwork.signet, BitcoinNetwork.regtest]) {
          expect(
            failure(
              await atNow(
                () => repository.indexPrice(network: network, currency: cad),
              ),
            ),
            isA<PricerUnsupportedNetworkFailure>(),
            reason: network.name,
          );
        }
        expect(api.requests, isEmpty);
      },
    );
  });

  group('cache', () {
    test('a price younger than 60 s is served without a request', () async {
      await atNow(() => repository.indexPrice(network: mainnet, currency: cad));
      now = now.add(const Duration(seconds: 59));
      await atNow(() => repository.indexPrice(network: mainnet, currency: cad));

      expect(api.requests, hasLength(1));
    });

    test('a price is fetched again at 60 s', () async {
      await atNow(() => repository.indexPrice(network: mainnet, currency: cad));
      now = now.add(const Duration(seconds: 60));
      await atNow(() => repository.indexPrice(network: mainnet, currency: cad));

      expect(api.requests, hasLength(2));
    });

    test('each currency and network has its own entry', () async {
      await atNow(() async {
        price(await repository.indexPrice(network: mainnet, currency: cad));
        price(
          await repository.indexPrice(
            network: mainnet,
            currency: SupportedCurrency.usd,
          ),
        );
        price(await repository.indexPrice(network: testnet, currency: cad));
        // All cached now: none of these asks again.
        price(await repository.indexPrice(network: mainnet, currency: cad));
        price(await repository.indexPrice(network: testnet, currency: cad));
      });

      expect(api.requests, hasLength(3));
    });

    test('a testnet price is never served for mainnet', () async {
      await atNow(() async {
        expect(
          amount(await repository.indexPrice(network: testnet, currency: cad)),
          testnetIndexPrice / 100,
        );
        expect(
          amount(await repository.indexPrice(network: mainnet, currency: cad)),
          mainnetIndexPrice / 100,
        );
      });
    });

    test('simultaneous callers share one request', () async {
      final answer = Completer<void>();
      api.answerAfter = answer.future;

      final reads = atNow(
        () => Future.wait([
          repository.indexPrice(network: mainnet, currency: cad),
          repository.indexPrice(network: mainnet, currency: cad),
          repository.indexPrice(network: mainnet, currency: cad),
        ]),
      );
      // Let the first request reach the API before it answers.
      while (api.requests.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      answer.complete();

      for (final result in await reads) {
        expect(amount(result), closeTo(114214.20, 1e-9));
      }
      expect(api.requests, hasLength(1));
    });

    test('a cached price keeps the time it was fetched', () async {
      final fetchedAt = now;
      final fetched = await atNow(
        () => repository.indexPrice(network: mainnet, currency: cad),
      );
      now = now.add(const Duration(seconds: 30));
      final cached = await atNow(
        () => repository.indexPrice(network: mainnet, currency: cad),
      );

      expect(price(fetched).fetchedAt, fetchedAt);
      expect(price(cached).fetchedAt, fetchedAt);
    });

    test('a fetched and a cached price carry the same UTC time', () async {
      // Local time with microseconds, as on a device; the cache keeps
      // milliseconds only.
      now = DateTime(2026, 10, 26, 12, 0, 0, 319, 449);
      final fetched = await atNow(
        () => repository.indexPrice(network: mainnet, currency: cad),
      );
      final cached = await atNow(
        () => repository.indexPrice(network: mainnet, currency: cad),
      );

      expect(price(cached).fetchedAt, price(fetched).fetchedAt);
      expect(price(fetched).fetchedAt.isUtc, isTrue);
      expect(price(cached), price(fetched));
    });

    test('a price stamped in the future is fetched again', () async {
      await atNow(() => repository.indexPrice(network: mainnet, currency: cad));
      // The device clock moved back: the cached price now looks like it was
      // fetched in the future, so it must not count as fresh.
      now = now.subtract(const Duration(minutes: 5));
      await atNow(() => repository.indexPrice(network: mainnet, currency: cad));

      expect(api.requests, hasLength(2));
    });

    test('an unreadable cache falls back to the price service', () async {
      final directory = Directory.systemTemp.createTempSync('bull_pricer');
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = File('${directory.path}/pricer.sqlite')
        ..writeAsStringSync('not a database');
      // One database at a time: drift warns when two are open at once.
      await database.close();
      final broken = PricerDatabase.open(file.path);
      addTearDown(broken.close);
      final repository = PricerRepository(
        pricerCacheDatasource: PricerCacheDatasource(broken),
      );

      expect(
        amount(
          await atNow(
            () => repository.indexPrice(network: mainnet, currency: cad),
          ),
        ),
        closeTo(114214.20, 1e-9),
      );
      expect(api.requests, hasLength(1));
    });
  });

  group('failures', () {
    Future<PricerFailure> indexFailure() async => failure(
      await atNow(() => repository.indexPrice(network: mainnet, currency: cad)),
    );

    test('HTTP 429 is a rate limit', () async {
      api.respond = (_) => (status: 429, body: const <String, Object>{});

      expect(await indexFailure(), isA<PricerRateLimitedFailure>());
    });

    test('a server error is a network failure', () async {
      api.respond = (_) => (status: 503, body: const <String, Object>{});

      expect(await indexFailure(), isA<PricerNetworkFailure>());
    });

    test(
      'a price service silent for 10 s is a network failure',
      () async {
        api.answerAfter = Completer<void>().future;
        final watch = Stopwatch()..start();

        expect(await indexFailure(), isA<PricerNetworkFailure>());
        expect(watch.elapsed, lessThan(const Duration(seconds: 12)));
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test('a dropped connection is a network failure', () async {
      api.offline = true;

      expect(await indexFailure(), isA<PricerNetworkFailure>());
    });

    test('another HTTP error is unexpected', () async {
      api.respond = (_) => (status: 400, body: const <String, Object>{});

      expect(
        await indexFailure(),
        isA<PricerUnexpectedFailure>().having(
          (f) => f.logMessage,
          'logMessage',
          'HTTP 400',
        ),
      );
    });

    test('a JSON-RPC error is unexpected', () async {
      api.respond = (_) => (
        status: 200,
        body: const {
          'jsonrpc': '2.0',
          'id': 1,
          'error': {'code': -32000, 'message': 'Server error'},
        },
      );

      expect(await indexFailure(), isA<PricerUnexpectedFailure>());
    });

    test('a failure is not cached, and a lapsed price is not served', () async {
      await atNow(() => repository.indexPrice(network: mainnet, currency: cad));
      now = now.add(const Duration(seconds: 61));
      api.respond = (_) => (status: 503, body: const <String, Object>{});

      expect(await indexFailure(), isA<PricerNetworkFailure>());

      api.respond = realisticAnswer;
      expect(
        amount(
          await atNow(
            () => repository.indexPrice(network: mainnet, currency: cad),
          ),
        ),
        closeTo(114214.20, 1e-9),
      );
      expect(api.requests, hasLength(3));
    });
  });
}
