import 'dart:convert';

import 'package:bbx_api/bbx_api.dart';
import 'package:test/test.dart';

import 'fake_http.dart';
import 'result_helpers.dart';

const _rate = {
  'fromCurrency': 'CAD',
  'toCurrency': 'BTC',
  'indexPrice': 12345678,
  'userPrice': 12400000,
  'precision': 2,
};

void main() {
  late FakeHttp http;
  late PricesApi api;

  void answer(Object? body) {
    http = FakeHttp(body: body);
    api = bbx(http).prices;
  }

  test('getUserRate sends the old request and reads the element', () async {
    answer({
      'result': {'element': _rate},
    });

    final rate = valueOf(
      await api.getUserRate(fromCurrency: 'CAD', toCurrency: 'BTC'),
    );

    final request = http.requests.single;
    expect(request.path, '/public/price');
    expect(
      jsonEncode(request.data),
      '{"jsonrpc":"2.0","id":"0","method":"getUserRate","params":'
      '{"element":{"fromCurrency":"CAD","toCurrency":"BTC"}}}',
    );
    expect(rate.fromCurrency, 'CAD');
    expect(rate.indexPrice, 12345678);
    expect(rate.userPrice, 12400000);
    expect(rate.precision, 2);
  });

  test('reads a rate returned as the result itself', () async {
    answer({'result': _rate});

    final rate = valueOf(
      await api.getUserRate(fromCurrency: 'CAD', toCurrency: 'BTC'),
    );

    expect(rate.userPrice, 12400000);
  });

  test('fromCurrency and precision may be missing', () async {
    answer({
      'result': {'indexPrice': 1.5, 'userPrice': 2},
    });

    final rate = valueOf(
      await api.getUserRate(fromCurrency: 'CAD', toCurrency: 'BTC'),
    );

    expect(rate.fromCurrency, isNull);
    expect(rate.precision, isNull);
    expect(rate.indexPrice, 1.5);
  });

  test('a missing price is a format error', () async {
    answer({
      'result': {'indexPrice': 1},
    });

    expect(
      await failedCall(api.getUserRate(fromCurrency: 'CAD', toCurrency: 'BTC')),
      isA<BbxResponseFormatFailure>().having(
        (f) => f.reason,
        'reason',
        'invalid userPrice',
      ),
    );
  });
}
