import 'package:bull_pricer/src/data/datasources/pricer_api_datasource.dart';
import 'package:bull_pricer/src/domain/entities/supported_currency.dart';
import 'package:dio/dio.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

import 'fake_price_api.dart';

// A real `getRate` answer from api05 (2026-10-22).
final _getRateAnswer = element({
  'fromCurrency': 'BTC',
  'toCurrency': 'CAD',
  'price': 11228945,
  'priceCurrency': 'CAD',
  'precision': 2,
  'indexPrice': 11424220,
  'createdAt': '2026-10-22T16:31:08.709Z',
});

void main() {
  late FakePriceApi api;
  const datasource = PricerApiDatasource();
  const mainnet = BitcoinNetwork.mainnet;

  setUp(() async => api = await FakePriceApi.start());
  tearDown(() => api.close());

  group('requests', () {
    test('indexPrice asks getRate from BTC, without the API key', () async {
      api.respond = (_) => _getRateAnswer;

      final response = await datasource.indexPrice(
        mainnet,
        SupportedCurrency.cad,
      );

      expect(response.indexPrice(), closeTo(114242.20, 1e-9));
      final request = api.requests.single;
      expect(request.method, 'getRate');
      expect(request.params, {'fromCurrency': 'BTC', 'toCurrency': 'CAD'});
      expect(request.apiKey, isNull);
    });
  });

  group('networks', () {
    test('mainnet asks api.bullbitcoin.com', () async {
      await datasource.indexPrice(mainnet, SupportedCurrency.cad);

      expect(api.requests.single.host, 'api.bullbitcoin.com');
    });

    test('testnet asks api05.bullbitcoin.dev', () async {
      await datasource.indexPrice(
        BitcoinNetwork.testnet,
        SupportedCurrency.cad,
      );

      expect(api.requests.single.host, 'api05.bullbitcoin.dev');
    });

    test('a network without a price service is never asked', () async {
      for (final network in [BitcoinNetwork.signet, BitcoinNetwork.regtest]) {
        await expectLater(
          datasource.indexPrice(network, SupportedCurrency.cad),
          throwsA(isA<PricerUnsupportedNetworkException>()),
          reason: network.name,
        );
      }
      expect(api.requests, isEmpty);
    });
  });

  group('errors', () {
    test('HTTP 429 surfaces as a DioException with its status', () async {
      api.respond = (_) => (status: 429, body: const <String, Object>{});

      await expectLater(
        datasource.indexPrice(mainnet, SupportedCurrency.cad),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            429,
          ),
        ),
      );
    });

    test('a JSON-RPC error is a FormatException', () async {
      api.respond = (_) => (
        status: 200,
        body: const {
          'jsonrpc': '2.0',
          'id': 1,
          'error': {'code': -32000, 'message': 'Server error'},
        },
      );

      await expectLater(
        datasource.indexPrice(mainnet, SupportedCurrency.cad),
        throwsFormatException,
      );
    });

    test('an answer without a price is a FormatException', () async {
      api.respond = (_) => (status: 200, body: const {'jsonrpc': '2.0'});

      await expectLater(
        datasource.indexPrice(mainnet, SupportedCurrency.cad),
        throwsFormatException,
      );
    });
  });
}
