import 'package:bbx_api/bbx_api.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

import 'fake_http.dart';

Map<String, Object?> _order({String orderId = 'o-1'}) => {
  'orderId': orderId,
  'orderType': 'Buy Bitcoin',
  'orderSubtype': 'Express',
  'orderNumber': 7,
  'exchangeRateAmount': 100000,
  'exchangeRateCurrency': 'CAD',
  'payinAmount': 100,
  'payinCurrency': 'CAD',
  'payoutAmount': 0.001,
  'payoutCurrency': 'BTC',
  'orderStatus': 'Completed',
  'payinStatus': 'Completed',
  'payoutStatus': 'Completed',
  'createdAt': '2026-11-20T10:00:00Z',
  'message': {'code': 42, 'message': 'note'},
  'payinMethod': 'Interac e-Transfer (CAD)',
  'payoutMethod': 'Bitcoin On-Chain',
  'triggerType': 'MANUAL',
  'isPPBitcoinOutUpdatable': true,
  'payinAmountChanged': {'requestedAmount': 100, 'receivedAmount': 90.5},
  'bitcoinTransactionId': 'tx-1',
  'unbatchedBuyOnchainFees': 125,
  'bip21URI': 'bitcoin:bc1q?pj=x',
  'payjoinDetails': {'txid': 'pj-tx'},
};

Map<String, Object?> _rpcError() => {
  'error': {'code': -1, 'message': 'no'},
};

FakeHttp _adapter(Dio dio) => dio.httpClientAdapter as FakeHttp;

void main() {
  group('getOrderSummary', () {
    test('sends the order id and reads the wrapped element', () async {
      final dio = FakeHttp.dio(
        body: {
          'result': {'element': _order()},
        },
      );
      final orders = BbxApiClient(dio).orders;
      final order = await orders.getOrderSummary('o-1');

      final request = _adapter(dio).requests.single;
      expect(request.path, '/ak/api-orders');
      expect((request.data as Map)['method'], 'getOrderSummary');
      expect((request.data as Map)['params'], {'orderId': 'o-1'});

      expect(order.orderId, 'o-1');
      expect(order.orderType, 'Buy Bitcoin');
      expect(order.orderSubtype, 'Express');
      expect(order.orderNumber, 7);
      expect(order.exchangeRateAmount, 100000.0);
      expect(order.payoutAmount, 0.001);
      expect(order.createdAt, '2026-11-20T10:00:00Z');
      expect(order.message!.code, '42');
      expect(order.message!.message, 'note');
      expect(order.isPPBitcoinOutUpdatable, isTrue);
      expect(order.payinAmountChanged!.requestedAmount, 100.0);
      expect(order.payinAmountChanged!.receivedAmount, 90.5);
      expect(order.unbatchedBuyOnchainFees, 125.0);
      expect(order.bip21URI, 'bitcoin:bc1q?pj=x');
      expect(order.payjoinDetails!.txid, 'pj-tx');
    });

    test('reads an unwrapped result', () async {
      final order = await BbxApiClient(
        FakeHttp.dio(body: {'result': _order(orderId: 'o-2')}),
      ).orders.getOrderSummary('o-2');
      expect(order.orderId, 'o-2');
    });

    test('omitted optional fields are null', () async {
      final order = await BbxApiClient(
        FakeHttp.dio(
          body: {
            'result': {
              'orderId': 'o-3',
              'orderType': 'Reward',
              'orderNumber': 1,
              'createdAt': '2026-11-20T10:00:00Z',
            },
          },
        ),
      ).orders.getOrderSummary('o-3');
      expect(order.payinAmount, isNull);
      expect(order.payinCurrency, isNull);
      expect(order.orderStatus, isNull);
      expect(order.payinMethod, isNull);
      expect(order.message, isNull);
      expect(order.payinAmountChanged, isNull);
      expect(order.payjoinDetails, isNull);
    });

    for (final field in ['orderId', 'orderType', 'orderNumber', 'createdAt']) {
      test('a missing $field is a format error', () async {
        await expectLater(
          BbxApiClient(FakeHttp.dio(body: {'result': _order()..remove(field)}))
              .orders
              .getOrderSummary('o-1'),
          throwsA(isA<BbxApiFormatException>()),
        );
      });
    }

    for (final (field, value) in [
      ('orderNumber', 7.5),
      ('payinAmount', '100'),
      ('message', 'note'),
      ('payinAmountChanged', {'requestedAmount': '1'}),
      ('payjoinDetails', {'txid': 1}),
    ]) {
      test('an invalid $field is a format error', () async {
        await expectLater(
          BbxApiClient(
            FakeHttp.dio(
              body: {
                'result': {..._order(), field: value},
              },
            ),
          ).orders.getOrderSummary('o-1'),
          throwsA(isA<BbxApiFormatException>()),
        );
      });
    }

    test('no result is a format error', () async {
      await expectLater(
        BbxApiClient(FakeHttp.dio(body: {'result': null})).orders
            .getOrderSummary('o-1'),
        throwsA(isA<BbxApiFormatException>()),
      );
    });

    test('a JSON-RPC error throws', () async {
      await expectLater(
        BbxApiClient(FakeHttp.dio(body: _rpcError())).orders
            .getOrderSummary('o-1'),
        throwsA(isA<BbxApiRpcException>()),
      );
    });
  });

  group('refreshOrderSummary', () {
    test('sends the order id and reads the result', () async {
      final dio = FakeHttp.dio(body: {'result': _order()});
      final orders = BbxApiClient(dio).orders;
      final order = await orders.refreshOrderSummary('o-1');

      final request = _adapter(dio).requests.single;
      expect(request.path, '/ak/api-orders');
      expect((request.data as Map)['method'], 'refreshOrderSummary');
      expect((request.data as Map)['params'], {'orderId': 'o-1'});
      expect(order.orderId, 'o-1');
    });

    test('a JSON-RPC error throws', () async {
      await expectLater(
        BbxApiClient(FakeHttp.dio(body: _rpcError())).orders
            .refreshOrderSummary('o-1'),
        throwsA(isA<BbxApiRpcException>()),
      );
    });
  });

  group('listOrderSummaries', () {
    test('asks for the newest page and reads every order', () async {
      final dio = FakeHttp.dio(
        body: {
          'result': {
            'elements': [_order(), _order(orderId: 'o-2')],
          },
        },
      );
      final orders = BbxApiClient(dio).orders;
      final list = await orders.listOrderSummaries();

      final request = _adapter(dio).requests.single;
      expect(request.path, '/ak/api-orders');
      expect((request.data as Map)['method'], 'listOrderSummaries');
      expect((request.data as Map)['params'], {
        'sortBy': {'id': 'createdAt', 'sort': 'desc'},
        'paginator': {'page': 1, 'pageSize': 50},
      });
      expect([for (final o in list.orders) o.orderId], ['o-1', 'o-2']);
      expect(list.rejected, isEmpty);
    });

    test('a malformed element is rejected, not the whole list', () async {
      final list = await BbxApiClient(
        FakeHttp.dio(
          body: {
            'result': {
              'elements': [
                _order()..remove('orderId'),
                'not an object',
                _order(orderId: 'o-2'),
              ],
            },
          },
        ),
      ).orders.listOrderSummaries();
      expect(list.orders.single.orderId, 'o-2');
      expect(list.rejected, hasLength(2));
    });

    test('missing elements are an empty list', () async {
      final list = await BbxApiClient(
        FakeHttp.dio(body: {'result': <String, Object?>{}}),
      ).orders.listOrderSummaries();
      expect(list.orders, isEmpty);
      expect(list.rejected, isEmpty);
    });

    for (final body in [
      {'result': null},
      {
        'result': {'elements': 'x'},
      },
    ]) {
      test('$body is a format error', () async {
        await expectLater(
          BbxApiClient(FakeHttp.dio(body: body)).orders.listOrderSummaries(),
          throwsA(isA<BbxApiFormatException>()),
        );
      });
    }

    test('a JSON-RPC error throws', () async {
      await expectLater(
        BbxApiClient(FakeHttp.dio(body: _rpcError())).orders
            .listOrderSummaries(),
        throwsA(isA<BbxApiRpcException>()),
      );
    });
  });

  for (final (method, call) in [
    ('getBuyLimits', (OrdersApi o) => o.getBuyLimits()),
    ('getSellLimits', (OrdersApi o) => o.getSellLimits()),
  ]) {
    group(method, () {
      test('returns the result object', () async {
        final dio = FakeHttp.dio(
          body: {
            'result': {'min': 10, 'max': 1000},
          },
        );
        final orders = BbxApiClient(dio).orders;
        expect(await call(orders), {'min': 10, 'max': 1000});

        final request = _adapter(dio).requests.single;
        expect(request.path, '/ak/api-orders');
        expect((request.data as Map)['method'], method);
        expect((request.data as Map)['params'], isEmpty);
      });

      test('no result is a format error', () async {
        await expectLater(
          call(BbxApiClient(FakeHttp.dio(body: {'result': null})).orders),
          throwsA(isA<BbxApiFormatException>()),
        );
      });

      test('a JSON-RPC error throws', () async {
        await expectLater(
          call(BbxApiClient(FakeHttp.dio(body: _rpcError())).orders),
          throwsA(isA<BbxApiRpcException>()),
        );
      });
    });
  }
}
