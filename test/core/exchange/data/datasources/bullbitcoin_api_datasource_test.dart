import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../order_json_fixture.dart';

class _MockDio extends Mock implements Dio {}

Response<dynamic> _elements(List<Map<String, dynamic>> elements) => Response(
  requestOptions: RequestOptions(path: '/ak/api-orders'),
  statusCode: 200,
  data: {
    'result': {'elements': elements},
  },
);

void main() {
  late _MockDio dio;
  late BullbitcoinApiDatasource datasource;

  setUp(() {
    dio = _MockDio();
    datasource = BullbitcoinApiDatasource(bullbitcoinApiHttpClient: dio);
  });

  void stubList(List<Map<String, dynamic>> elements) {
    when(
      () => dio.post(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) async => _elements(elements));
  }

  group('listOrderSummaries', () {
    test('skips an unparseable element and keeps the rest', () async {
      stubList([
        orderJsonFixture(orderId: 'good-1'),
        // Without orderId the cast in fromJson throws — on this element only.
        orderJsonFixture()..remove('orderId'),
        orderJsonFixture(orderId: 'good-2'),
      ]);

      final orders = await datasource.listOrderSummaries(apiKey: 'key');

      expect(orders.map((o) => o.orderId), ['good-1', 'good-2']);
    });

    test('an order with an unknown status no longer costs the list', () async {
      stubList([
        orderJsonFixture(orderId: 'expired-1', orderStatus: 'Expired'),
        orderJsonFixture(orderId: 'good-1'),
      ]);

      final orders = await datasource.listOrderSummaries(apiKey: 'key');

      expect(orders.map((o) => o.orderId), ['expired-1', 'good-1']);
    });
  });
}
