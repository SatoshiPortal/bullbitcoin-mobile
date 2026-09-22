import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/sepa_payment_processor.dart';
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

Response<dynamic> _confidentialSepaNotActivated() => Response(
  requestOptions: RequestOptions(path: '/ak/api-orders'),
  statusCode: 200,
  data: {
    'error': {
      'code': -32602,
      'message': 'Invalid method parameter(s)',
      'data': {
        'apiError': {
          'code': 'ERR_ORD_CSRCP400',
          'message': 'Please activate virtual payment option',
        },
      },
    },
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

  group('confidential SEPA activation errors', () {
    setUp(() {
      when(
        () => dio.post(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => _confidentialSepaNotActivated());
    });

    test('sellToRecipient reads the nested api error code', () async {
      expect(
        datasource.createPayOrder(
          apiKey: 'key',
          orderAmount: const FiatAmount(100),
          recipientId: 'recipient-1',
          network: OrderBitcoinNetwork.bitcoin,
          paymentProcessor: SepaPaymentProcessor.confidential,
        ),
        throwsA(isA<ConfidentialSepaNotActivatedApiException>()),
      );

      final request =
          verify(
                () => dio.post(
                  any(),
                  data: captureAny(named: 'data'),
                  options: any(named: 'options'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(request['params']['paymentProcessor'], 'CONFIDENTIAL_SEPA');
    });

    test('createWithdrawalOrder reads the nested api error code', () async {
      expect(
        datasource.createWithdrawalOrder(
          apiKey: 'key',
          fiatAmount: 100,
          recipientId: 'recipient-1',
          paymentProcessor: SepaPaymentProcessor.regular,
          paymentDescription: '  invoice 42  ',
        ),
        throwsA(isA<ConfidentialSepaNotActivatedApiException>()),
      );

      final request =
          verify(
                () => dio.post(
                  any(),
                  data: captureAny(named: 'data'),
                  options: any(named: 'options'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(request['params']['paymentProcessor'], 'REGULAR_SEPA');
      expect(request['params']['paymentDescription'], 'invoice 42');
    });
  });
}
