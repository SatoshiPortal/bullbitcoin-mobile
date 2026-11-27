import 'dart:convert';
import 'dart:typed_data';

import 'package:bbx_api/bbx_api.dart';
import 'package:bbx_api/bbx_api_testing.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'package:exchange/exchange.dart';
import 'package:exchange/src/data/bbx_api_order_stats_datasource.dart';

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
BbxApiOrderStatsDatasource _new(
  HttpClientAdapter http, {
  Future<Result<String?, BbxFailure>> Function()? readApiKey,
}) => BbxApiOrderStatsDatasource(
  api: bbxForTesting(
    endpoint: 'https://example.invalid',
    adapter: http,
    readActiveApiKey: readApiKey ?? () async => const Ok('synthetic-key'),
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

    final result = await repository.getOrderStats();
    final stats = (result as Ok<OrderStatistics, ExchangeFailure>).value;

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

  test('a missing API key is not authenticated', () async {
    final http = _Http(const {});

    final result = await _new(
      http,
      readApiKey: () async => const Ok(null),
    ).getOrderStats();
    expect(
      (result as Err<OrderStatistics, ExchangeFailure>).failure,
      isA<ExchangeNotAuthenticatedFailure>(),
    );
    expect(http.calls, 0);
  });

  test('an unreadable API key is a credential failure', () async {
    final http = _Http(const {});

    final result = await _new(
      http,
      readApiKey: () async => const Err(BbxCredentialUnavailableFailure()),
    ).getOrderStats();
    expect(
      (result as Err<OrderStatistics, ExchangeFailure>).failure,
      isA<ExchangeCredentialReadFailure>(),
    );
    expect(http.calls, 0);
  });

  test('a malformed response is a generic failure', () async {
    final repository = _new(_Http({'result': {}}));
    final result = await repository.getOrderStats();
    expect(
      (result as Err<OrderStatistics, ExchangeFailure>).failure,
      isA<ExchangeStatisticsUnavailableFailure>(),
    );
  });
}
