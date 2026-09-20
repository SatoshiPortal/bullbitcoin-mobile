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

Response<dynamic> _order(Map<String, dynamic> order) => Response(
  requestOptions: RequestOptions(path: '/ak/api-orders'),
  statusCode: 200,
  data: {'result': order},
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

  group('createWithdrawalOrder', () {
    test('sends the withdrawal amount and recipient reference', () async {
      when(
        () => dio.post(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => _order(orderJsonFixture()));

      await datasource.createWithdrawalOrder(
        apiKey: 'key',
        fiatAmount: 100,
        recipientId: 'recipient-1',
      );

      final request =
          verify(
                () => dio.post(
                  '/ak/api-orders',
                  data: captureAny(named: 'data'),
                  options: any(named: 'options'),
                ),
              ).captured.single
              as Map<String, dynamic>;

      expect(request, {
        'jsonrpc': '2.0',
        'id': '0',
        'method': 'createWithdrawalOrder',
        'params': {'fiatAmount': 100.0, 'recipientId': 'recipient-1'},
      });
    });

    test('sends supplied Interac security details', () async {
      when(
        () => dio.post(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => _order(orderJsonFixture()));

      await datasource.createWithdrawalOrder(
        apiKey: 'key',
        fiatAmount: 100,
        recipientId: 'recipient-1',
        securityQuestion: 'Favourite city?',
        securityAnswer: 'Montreal',
      );

      final request =
          verify(
                () => dio.post(
                  '/ak/api-orders',
                  data: captureAny(named: 'data'),
                  options: any(named: 'options'),
                ),
              ).captured.single
              as Map<String, dynamic>;

      expect(request['params'], {
        'fiatAmount': 100.0,
        'recipientId': 'recipient-1',
        'paymentProcessorData': {
          'securityQuestion': 'Favourite city?',
          'securityAnswer': 'Montreal',
        },
      });
    });
  });
}
