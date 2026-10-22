import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/exchange/domain/entity/sepa_payment_processor.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
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

Response<dynamic> _rpcError(Map<String, dynamic> error) => Response(
  requestOptions: RequestOptions(path: '/ak/api-orders'),
  statusCode: 200,
  data: {'error': error},
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

  void stubPost(Response<dynamic> response) {
    when(
      () => dio.post(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) async => response);
  }

  Map<String, dynamic> capturedRequest() {
    final request =
        verify(
              () => dio.post(
                '/ak/api-orders',
                data: captureAny(named: 'data'),
                options: any(named: 'options'),
              ),
            ).captured.single
            as Map<String, dynamic>;
    return request;
  }

  Map<String, dynamic> capturedParams() =>
      capturedRequest()['params'] as Map<String, dynamic>;

  void stubList(List<Map<String, dynamic>> elements) {
    when(
      () => dio.post(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) async => _elements(elements));
  }

  group('EUR Sell payout requests', () {
    test('keeps rejection codes without exposing account details', () async {
      stubPost(
        _rpcError({
          'code': -32603,
          'message': 'Account details must stay out of diagnostics',
          'data': {
            'apiError': {
              'code': 'ERR_ORD_PO404',
              'message': 'Account details must stay out of diagnostics',
            },
          },
        }),
      );

      await expectLater(
        datasource.createSellOrder(
          apiKey: 'key',
          fiatCurrency: FiatCurrency.eur,
          recipientId: 'own-account',
          paymentProcessor: SepaPaymentProcessor.regular,
          orderAmount: const FiatAmount(100),
          network: OrderBitcoinNetwork.liquid,
        ),
        throwsA(
          isA<BullBitcoinApiOrderException>()
              .having((error) => error.apiCode, 'apiCode', 'ERR_ORD_PO404')
              .having((error) => error.rpcCode, 'rpcCode', -32603)
              .having(
                (error) => error.toString(),
                'diagnostics',
                isNot(contains('Account details')),
              ),
        ),
      );
    });

    test('balance keeps the sellToBalance contract', () async {
      stubPost(_order(orderJsonFixture(orderType: 'Sell Bitcoin')));
      await datasource.createSellOrder(
        apiKey: 'key',
        fiatCurrency: FiatCurrency.eur,
        orderAmount: const FiatAmount(100),
        network: OrderBitcoinNetwork.bitcoin,
      );
      final request = capturedRequest();
      expect(request['method'], 'sellToBalance');
      expect(request['params'], {
        'fiatCurrency': 'EUR',
        'bitcoinNetwork': 'bitcoin',
        'fiatAmount': 100.0,
      });
    });

    for (final processor in SepaPaymentProcessor.values) {
      test(
        'bank payout sends ${processor.name} processor and recipient',
        () async {
          stubPost(_order(orderJsonFixture(orderType: 'Fiat Payment')));
          final model = await datasource.createSellOrder(
            apiKey: 'key',
            fiatCurrency: FiatCurrency.eur,
            recipientId: 'own-account',
            paymentProcessor: processor,
            orderAmount: const BitcoinAmount(0.001),
            network: OrderBitcoinNetwork.bitcoin,
            usePayjoin: true,
          );
          final request = capturedRequest();
          expect(request['method'], 'sellToRecipient');
          expect(request['params'], {
            'recipientId': 'own-account',
            'paymentProcessor': processor == SepaPaymentProcessor.confidential
                ? 'CONFIDENTIAL_SEPA'
                : 'REGULAR_SEPA',
            'bitcoinNetwork': 'bitcoin',
            'bitcoinAmount': 0.001,
            'usePayjoin': true,
          });
          expect(model.toEntity(isTestnet: false), isA<FiatPaymentOrder>());
        },
      );
    }

    test(
      'maps inactive confidential recipient to the activation failure',
      () async {
        stubPost(
          _rpcError({
            'message': 'Recipient not activated',
            'data': {
              'apiError': {'code': 'ERR_ORD_CSRCP400'},
            },
          }),
        );
        await expectLater(
          datasource.createSellOrder(
            apiKey: 'key',
            fiatCurrency: FiatCurrency.eur,
            recipientId: 'own-account',
            paymentProcessor: SepaPaymentProcessor.confidential,
            orderAmount: const FiatAmount(100),
            network: OrderBitcoinNetwork.bitcoin,
          ),
          throwsA(isA<BullBitcoinApiConfidentialSepaNotActivatedException>()),
        );
      },
    );
  });

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

  group('confidential sepa', () {
    const notActivated = {
      'code': -32602,
      'message': 'Invalid params',
      'data': {
        'apiError': {
          'code': 'ERR_ORD_CSRCP400',
          'message':
              'Please activate virtual payment option for the SEPA recipient with IBAN: {iban}',
          'messageData': {'iban': 'FR7630006000011234567890189'},
        },
      },
    };

    test('a withdrawal sends the selected payment processor', () async {
      stubPost(_order(orderJsonFixture()));

      await datasource.createWithdrawalOrder(
        apiKey: 'key',
        fiatAmount: 100,
        recipientId: 'recipient-1',
        paymentProcessor: SepaPaymentProcessor.confidential,
      );

      expect(capturedParams(), {
        'fiatAmount': 100.0,
        'recipientId': 'recipient-1',
        'paymentProcessor': 'CONFIDENTIAL_SEPA',
      });
    });

    test('an inactive virtual payee rejects a withdrawal', () async {
      stubPost(_rpcError(notActivated));

      await expectLater(
        datasource.createWithdrawalOrder(
          apiKey: 'key',
          fiatAmount: 100,
          recipientId: 'recipient-1',
          paymentProcessor: SepaPaymentProcessor.confidential,
        ),
        throwsA(isA<BullBitcoinApiConfidentialSepaNotActivatedException>()),
      );
    });
  });
}
