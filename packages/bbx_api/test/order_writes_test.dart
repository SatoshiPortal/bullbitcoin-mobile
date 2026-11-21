import 'dart:convert';

import 'package:bbx_api/bbx_api.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

import 'fake_http.dart';

const _order = {
  'orderId': 'o-1',
  'orderType': 'Buy Bitcoin',
  'orderNumber': 7,
  'payinAmount': 100,
  'payinCurrency': 'CAD',
  'payoutAmount': 0.001,
  'payoutCurrency': 'BTC',
  'orderStatus': 'Completed',
  'payinStatus': 'Completed',
  'payoutStatus': 'Completed',
  'createdAt': '2026-11-20T10:00:00Z',
  'payinMethod': 'Interac e-Transfer (CAD)',
  'payoutMethod': 'Bitcoin On-Chain',
};

Map<String, Object?> _limit(
  Object amount,
  String operator, {
  String currency = 'CAD',
}) => {
  'entity': 'ORDER',
  'code': 'LIMIT_AMOUNT',
  'amount': amount,
  'conditionalOperator': operator,
  'currencyCode': currency,
};

Map<String, Object?> _reasons(List<Map<String, Object?>> limits) => {
  'error': {
    'code': -32000,
    'message': 'No valid payment options available after applying limits',
    'data': {
      'reasons': [
        for (final limit in limits) {'amount': '5', 'limit': limit},
      ],
      'details': [null],
    },
  },
};

const _min = 'GREATER_THAN_OR_EQUAL';
const _max = 'LESS_THAN_OR_EQUAL';

/// The JSON-RPC request sent through [dio], as the JSON text on the wire.
String _sent(Dio dio) {
  final request = (dio.httpClientAdapter as FakeHttp).requests.single;
  expect(request.path, '/ak/api-orders');
  return jsonEncode(request.data);
}

String _rpc(String method, Map<String, Object?> params) => jsonEncode({
  'jsonrpc': '2.0',
  'id': '0',
  'method': method,
  'params': params,
});

void main() {
  late Dio dio;
  late OrdersApi orders;

  void answer(Object? body, {int status = 200}) {
    dio = FakeHttp.dio(status: status, body: body);
    orders = BbxApiClient(dio).orders;
  }

  setUp(() => answer({'result': _order}));

  group('createOrderBuy', () {
    test('sends the address and a fiat amount', () async {
      final order = await orders.createOrderBuy(
        fiatCurrency: 'CAD',
        network: 'liquid',
        isOwner: true,
        address: 'lq1address',
        fiatAmount: 5,
      );
      expect(
        _sent(dio),
        _rpc('createOrderBuy', {
          'fiatCurrency': 'CAD',
          'network': 'liquid',
          'isOwner': true,
          'address': 'lq1address',
          'fiatAmount': 5.0,
        }),
      );
      expect(order.orderId, 'o-1');
    });

    test('sends the bip21URI instead of the address, with sats', () async {
      await orders.createOrderBuy(
        fiatCurrency: 'EUR',
        network: 'bitcoin',
        isOwner: false,
        bip21URI: 'bitcoin:bc1q?pj=https://payjo.in/s',
        bitcoinAmount: 0.001,
      );
      expect(
        _sent(dio),
        _rpc('createOrderBuy', {
          'fiatCurrency': 'EUR',
          'network': 'bitcoin',
          'isOwner': false,
          'bip21URI': 'bitcoin:bc1q?pj=https://payjo.in/s',
          'bitcoinAmount': 0.001,
        }),
      );
    });

    for (final (name, address, uri) in [
      ('neither', null, null),
      ('both', 'bc1q', 'bitcoin:bc1q?pj=x'),
    ]) {
      test('$name address and bip21URI is an argument error', () async {
        await expectLater(
          orders.createOrderBuy(
            fiatCurrency: 'CAD',
            network: 'bitcoin',
            isOwner: true,
            address: address,
            bip21URI: uri,
          ),
          throwsArgumentError,
        );
        expect((dio.httpClientAdapter as FakeHttp).requests, isEmpty);
      });
    }
  });

  group('sellToBalance', () {
    test('omits usePayjoin when false', () async {
      await orders.sellToBalance(
        fiatCurrency: 'EUR',
        bitcoinNetwork: 'bitcoin',
        fiatAmount: 100,
      );
      expect(
        _sent(dio),
        _rpc('sellToBalance', {
          'fiatCurrency': 'EUR',
          'bitcoinNetwork': 'bitcoin',
          'fiatAmount': 100.0,
        }),
      );
    });

    test('sends usePayjoin when true', () async {
      await orders.sellToBalance(
        fiatCurrency: 'CAD',
        bitcoinNetwork: 'bitcoin',
        usePayjoin: true,
        bitcoinAmount: 0.01,
      );
      expect(
        _sent(dio),
        _rpc('sellToBalance', {
          'fiatCurrency': 'CAD',
          'bitcoinNetwork': 'bitcoin',
          'usePayjoin': true,
          'bitcoinAmount': 0.01,
        }),
      );
    });
  });

  group('sellToRecipient', () {
    test('sends the recipient, processor, payjoin and description', () async {
      await orders.sellToRecipient(
        recipientId: 'r-1',
        paymentProcessor: SepaPaymentProcessor.confidential,
        bitcoinNetwork: 'bitcoin',
        usePayjoin: true,
        bitcoinAmount: 0.001,
        paymentDescription: 'rent',
      );
      expect(
        _sent(dio),
        _rpc('sellToRecipient', {
          'recipientId': 'r-1',
          'paymentProcessor': 'CONFIDENTIAL_SEPA',
          'bitcoinNetwork': 'bitcoin',
          'usePayjoin': true,
          'bitcoinAmount': 0.001,
          'paymentDescription': 'rent',
        }),
      );
    });

    test('omits what is not given', () async {
      await orders.sellToRecipient(
        recipientId: 'r-1',
        bitcoinNetwork: 'lightning',
        fiatAmount: 20,
      );
      expect(
        _sent(dio),
        _rpc('sellToRecipient', {
          'recipientId': 'r-1',
          'bitcoinNetwork': 'lightning',
          'fiatAmount': 20.0,
        }),
      );
    });

    test('REGULAR_SEPA is the regular processor', () async {
      await orders.sellToRecipient(
        recipientId: 'r-1',
        paymentProcessor: SepaPaymentProcessor.regular,
        bitcoinNetwork: 'liquid',
        fiatAmount: 20,
      );
      expect(_sent(dio), contains('"paymentProcessor":"REGULAR_SEPA"'));
    });
  });

  group('createWithdrawalOrder', () {
    test('sends the amount, recipient and processor', () async {
      await orders.createWithdrawalOrder(
        fiatAmount: 50,
        recipientId: 'r-2',
        paymentProcessor: SepaPaymentProcessor.regular,
      );
      expect(
        _sent(dio),
        _rpc('createWithdrawalOrder', {
          'fiatAmount': 50.0,
          'recipientId': 'r-2',
          'paymentProcessor': 'REGULAR_SEPA',
        }),
      );
    });

    test('sends the Interac security details only together', () async {
      await orders.createWithdrawalOrder(
        fiatAmount: 50,
        recipientId: 'r-2',
        securityQuestion: 'q',
        securityAnswer: 'a',
      );
      expect(
        _sent(dio),
        _rpc('createWithdrawalOrder', {
          'fiatAmount': 50.0,
          'recipientId': 'r-2',
          'paymentProcessorData': {
            'securityQuestion': 'q',
            'securityAnswer': 'a',
          },
        }),
      );

      answer({'result': _order});
      await orders.createWithdrawalOrder(
        fiatAmount: 50,
        recipientId: 'r-2',
        securityQuestion: 'q',
      );
      expect(
        _sent(dio),
        _rpc('createWithdrawalOrder', {
          'fiatAmount': 50.0,
          'recipientId': 'r-2',
        }),
      );
    });
  });

  group('confirmOrderSummary and unbatchAndExpressOrder', () {
    for (final (method, call) in [
      ('confirmOrderSummary', (OrdersApi o) => o.confirmOrderSummary('o-1')),
      (
        'unbatchAndExpressOrder',
        (OrdersApi o) => o.unbatchAndExpressOrder('o-1'),
      ),
    ]) {
      test('$method sends the order id and reads the result', () async {
        final order = await call(orders);
        expect(_sent(dio), _rpc(method, {'orderId': 'o-1'}));
        expect(order.orderId, 'o-1');
      });

      test('$method does not read order limits', () async {
        answer(_reasons([_limit(20, _min)]));
        await expectLater(
          call(orders),
          throwsA(
            isA<BbxApiRpcException>().having(
              (e) => e,
              'type',
              isNot(isA<BbxApiOrderLimitException>()),
            ),
          ),
        );
      });
    }
  });

  group('order rejections', () {
    Future<OrderSummary> sell() => orders.sellToBalance(
      fiatCurrency: 'CAD',
      bitcoinNetwork: 'bitcoin',
      fiatAmount: 5,
    );

    Matcher limit(
      BbxApiOrderLimitBound bound,
      double amount,
      String currency,
    ) => throwsA(
      isA<BbxApiOrderLimitException>()
          .having((e) => e.bound, 'bound', bound)
          .having((e) => e.amount, 'amount', amount)
          .having((e) => e.currency, 'currency', currency)
          .having((e) => e.code, 'code', -32000),
    );

    Matcher plain() => throwsA(
      isA<BbxApiRpcException>()
          .having((e) => e.runtimeType, 'type', BbxApiRpcException)
          .having((e) => e.code, 'code', -32000),
    );

    test('aggregate minimums are the lowest one', () async {
      answer(_reasons([_limit('20', _min), _limit(50, _min)]));
      await expectLater(
        sell(),
        limit(BbxApiOrderLimitBound.minimum, 20, 'CAD'),
      );
    });

    test('aggregate maximums are the highest one', () async {
      answer(_reasons([_limit(1000, _max), _limit('3000.5', _max)]));
      await expectLater(
        sell(),
        limit(BbxApiOrderLimitBound.maximum, 3000.5, 'CAD'),
      );
    });

    test('a single reason.limit is read', () async {
      answer({
        'error': {
          'code': -32000,
          'data': {
            'reason': {'limit': _limit(10, _min, currency: 'EUR')},
          },
        },
      });
      await expectLater(
        sell(),
        limit(BbxApiOrderLimitBound.minimum, 10, 'EUR'),
      );
    });

    for (final (name, body) in [
      ('mixed bounds', _reasons([_limit(20, _min), _limit(50, _max)])),
      (
        'mixed currencies',
        _reasons([_limit(20, _min), _limit(50, _min, currency: 'EUR')]),
      ),
      ('another operator', _reasons([_limit(20, 'EQUAL')])),
      ('empty reasons', _reasons([])),
      (
        'reasons without a limit',
        {
          'error': {
            'code': -32000,
            'data': {
              'reasons': [
                {'amount': '5'},
                {'limit': 'x'},
              ],
            },
          },
        },
      ),
      (
        'an unreadable limit',
        _reasons([
          {'amount': 'x', 'conditionalOperator': _min, 'currencyCode': 'CAD'},
        ]),
      ),
      (
        'no data',
        {
          'error': {'code': -32000, 'message': 'no'},
        },
      ),
    ]) {
      test('$name is a plain JSON-RPC error', () async {
        answer(body);
        await expectLater(sell(), plain());
      });
    }

    test('ERR_ORD_CSRCP400 is the not-activated error', () async {
      answer({
        'error': {
          'code': -32603,
          'message': 'Recipient DE00 1234 not activated',
          'data': {
            'apiError': {'code': 'ERR_ORD_CSRCP400', 'message': 'DE00 1234'},
            'reasons': [
              {'limit': _limit(20, _min)},
            ],
          },
        },
      });
      await expectLater(
        orders.createWithdrawalOrder(fiatAmount: 5, recipientId: 'r'),
        throwsA(
          isA<BbxApiConfidentialSepaNotActivatedException>()
              .having((e) => e.code, 'code', -32603)
              .having((e) => e.apiCode, 'apiCode', 'ERR_ORD_CSRCP400')
              .having((e) => e.toString(), 'text', isNot(contains('DE00'))),
        ),
      );
    });

    test('the apiError code is kept only when it is an ERR_ code', () async {
      answer({
        'error': {
          'code': -32603,
          'message': 'Account details',
          'data': {
            'apiError': {'code': 'ERR_ORD_PO404', 'message': 'Account details'},
          },
        },
      });
      await expectLater(
        sell(),
        throwsA(
          isA<BbxApiRpcException>().having(
            (e) => e.apiCode,
            'apiCode',
            'ERR_ORD_PO404',
          ),
        ),
      );

      answer({
        'error': {
          'code': -32603,
          'data': {
            'apiError': {'code': 'account 1234'},
          },
        },
      });
      await expectLater(
        sell(),
        throwsA(
          isA<BbxApiRpcException>().having((e) => e.apiCode, 'apiCode', null),
        ),
      );
    });

    test('limit errors do not quote the server message', () async {
      answer(_reasons([_limit(20, _min)]));
      await expectLater(
        sell(),
        throwsA(
          isA<BbxApiOrderLimitException>()
              .having((e) => e.message, 'message', null)
              .having(
                (e) => e.toString(),
                'text',
                isNot(contains('No valid payment options')),
              ),
        ),
      );
    });

    test('a non-200 status is an HTTP error', () async {
      answer({'result': _order}, status: 204);
      await expectLater(sell(), throwsA(isA<BbxApiHttpException>()));
    });

    test('a result that is not an object is a format error', () async {
      answer({'result': null});
      await expectLater(sell(), throwsA(isA<BbxApiFormatException>()));
    });
  });
}
