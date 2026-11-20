import 'package:bbx_api/bbx_api.dart';
import 'package:test/test.dart';

import 'fake_http.dart';

Map<String, Object?> _stats({Object? asOf = '2026-11-20T10:00:00Z'}) => {
  'result': {
    'element': {
      'orderStats': {
        'bitcoinBuyVolume': [
          {'currency': 'CAD', 'value': 1500},
        ],
        'bitcoinSellTradeCount': [
          {'currency': 'EUR', 'value': 3.5},
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
          <String, Object?>{},
        ],
      },
      'asOf': asOf,
    },
  },
};

void main() {
  test('getOrderStats calls api-orders and reads the element', () async {
    final dio = FakeHttp.dio(body: _stats());
    final report = await BbxApiClient(dio).orders.getOrderStats();

    final request = (dio.httpClientAdapter as FakeHttp).requests.single;
    expect(request.path, '/ak/api-orders');
    expect((request.data as Map)['method'], 'getOrderStats');

    expect(report.asOf, DateTime.utc(2026, 11, 20, 10));
    final orders = report.orderStats;
    expect(orders.bitcoinBuyVolume.single.currency, 'CAD');
    expect(orders.bitcoinBuyVolume.single.value, 1500.0);
    expect(orders.bitcoinSellTradeCount.single.value, 3.5);
    expect(orders.averageBitcoinBuyPrice, isEmpty);
    expect(orders.buySellRatio, '3:1');

    expect(report.billerStats.currency, 'CAD');
    final [hydro, empty] = report.billerStats.stats;
    expect(hydro.billerName, 'Hydro');
    expect(hydro.totalAmount, 120.5);
    expect(hydro.tradeCount, 2);
    expect(empty.billerName, '');
    expect(empty.totalAmount, 0.0);
    expect(empty.tradeCount, 0);
  });

  test('a missing ratio defaults to 0:0', () async {
    final body = _stats();
    final element = (body['result'] as Map)['element'] as Map;
    (element['orderStats'] as Map).remove('buySellRatio');
    final report = await BbxApiClient(FakeHttp.dio(body: body)).orders
        .getOrderStats();
    expect(report.orderStats.buySellRatio, '0:0');
  });

  for (final asOf in [null, 'not a date', 7]) {
    test('an invalid asOf ($asOf) is a format error', () async {
      await expectLater(
        BbxApiClient(FakeHttp.dio(body: _stats(asOf: asOf))).orders
            .getOrderStats(),
        throwsA(isA<BbxApiFormatException>()),
      );
    });
  }

  test('a missing element is a format error', () async {
    await expectLater(
      BbxApiClient(FakeHttp.dio(body: {'result': <String, Object?>{}})).orders
          .getOrderStats(),
      throwsA(isA<BbxApiFormatException>()),
    );
  });
}
