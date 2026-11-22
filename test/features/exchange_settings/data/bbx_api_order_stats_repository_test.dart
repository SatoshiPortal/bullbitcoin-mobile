import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/data/exchange_authentication.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order_stats.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_api_key_failure.dart';
import 'package:bb_mobile/features/exchange_settings/data/bbx_api_order_stats_repository.dart';
import 'package:bbx_api/bbx_api_testing.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../exchange/data/bbx_api_test_http.dart';

class _Http implements HttpClientAdapter {
  final Object? body;
  int calls = 0;

  _Http(this.body);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// A repository whose client reads [readApiKey] before each request.
BbxApiOrderStatsRepository _new(
  HttpClientAdapter http, {
  ReadExchangeApiKey? readApiKey,
}) => BbxApiOrderStatsRepository(
  api: bbxForTesting(
    endpoint: testBbxEndpoint,
    adapter: http,
    readActiveApiKey: bbxCredentialRead(readApiKey),
  ),
);

void main() {
  test('maps the bbx_api report to the order stats entity', () async {
    final http = _Http({
      'result': {
        'element': {
          'orderStats': {
            'bitcoinBuyVolume': [
              {'currency': 'CAD', 'value': 1500},
            ],
            'buySellRatio': '3:1',
          },
          'billerStats': {
            'currency': 'CAD',
            'stats': [
              {
                'billerName': 'Hydro',
                'billerCode': 'H1',
                'totalAmount': 120.5,
                'tradeCount': 2,
              },
            ],
          },
          'asOf': '2026-11-20T10:00:00Z',
        },
      },
    });
    final repository = _new(http);

    final stats = await repository.getOrderStats();

    expect(stats.orderStats.bitcoinBuyVolume, const [
      AmountByCurrencyCode(currency: 'CAD', value: 1500),
    ]);
    expect(stats.orderStats.bitcoinSellVolume, isEmpty);
    expect(stats.orderStats.buySellRatio, '3:1');
    expect(stats.billerStats.currency, 'CAD');
    expect(stats.billerStats.stats.single.billerName, 'Hydro');
    expect(stats.billerStats.stats.single.tradeCount, 2);
    expect(stats.asOf, DateTime.utc(2026, 11, 20, 10));
  });

  test('a missing API key is reported as ApiKeyNotFoundException', () async {
    final http = _Http(const {});

    await expectLater(
      _new(http, readApiKey: () async => const Ok(null)).getOrderStats(),
      throwsA(isA<ApiKeyNotFoundException>()),
    );
    expect(http.calls, 0);
  });

  test('an unreadable API key is a credential failure', () async {
    final http = _Http(const {});

    await expectLater(
      _new(
        http,
        readApiKey: () async => const Err(ExchangeApiKeyReadFailure()),
      ).getOrderStats(),
      throwsA(isA<ExchangeCredentialUnavailableException>()),
    );
    expect(http.calls, 0);
  });

  test('a malformed response is a generic failure', () async {
    final repository = _new(_Http({'result': {}}));
    await expectLater(repository.getOrderStats(), throwsA(isA<Exception>()));
  });
}
