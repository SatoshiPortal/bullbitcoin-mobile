import 'package:bbx_api/bbx_api.dart';
import 'package:test/test.dart';

import 'fake_http.dart';
import 'result_helpers.dart';

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

void main() {
  group('complete order summary page', () {
    test('requires an explicit list, even for the last page', () async {
      for (final result in <Map<String, Object?>>[
        {},
        {'elements': null},
        {'elements': {}},
      ]) {
        final orders = bbx(FakeHttp(body: {'result': result})).orders;
        expect(
          await failedCall(
            orders.listOrderSummaries(requireCompletePage: true),
          ),
          isA<BbxResponseFormatFailure>(),
        );
      }

      final orders = bbx(
        FakeHttp(
          body: const {
            'result': {'elements': <Object>[]},
          },
        ),
      ).orders;
      final page = valueOf(
        await orders.listOrderSummaries(requireCompletePage: true),
      );
      expect(page.orders, isEmpty);
    });

    test('rejects the whole page if any row cannot be decoded', () async {
      final orders = bbx(
        FakeHttp(
          body: {
            'result': {
              'elements': [
                _order(),
                {'orderId': 'missing-fields'},
              ],
            },
          },
        ),
      ).orders;
      expect(
        await failedCall(orders.listOrderSummaries(requireCompletePage: true)),
        isA<BbxResponseFormatFailure>(),
      );
    });
  });

  group('getOrderSummary', () {
    test('sends the order id and reads the wrapped element', () async {
      final http = FakeHttp(
        body: {
          'result': {'element': _order()},
        },
      );
      final orders = bbx(http).orders;
      final order = valueOf(await orders.getOrderSummary('o-1'));

      final request = http.requests.single;
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
      final message = order.message ?? fail('Expected an order message');
      expect(message.code, '42');
      expect(message.message, 'note');
      expect(order.isPPBitcoinOutUpdatable, isTrue);
      final payinAmountChanged =
          order.payinAmountChanged ?? fail('Expected a payin amount change');
      expect(payinAmountChanged.requestedAmount, 100.0);
      expect(payinAmountChanged.receivedAmount, 90.5);
      expect(order.unbatchedBuyOnchainFees, 125.0);
      expect(order.bip21URI, 'bitcoin:bc1q?pj=x');
      final payjoinDetails =
          order.payjoinDetails ?? fail('Expected Payjoin details');
      expect(payjoinDetails.txid, 'pj-tx');
    });

    test('reads an unwrapped result', () async {
      final order = valueOf(
        await bbx(FakeHttp(body: {'result': _order(orderId: 'o-2')})).orders
            .getOrderSummary('o-2'),
      );
      expect(order.orderId, 'o-2');
    });

    test('omitted optional fields are null', () async {
      final order = valueOf(
        await bbx(
          FakeHttp(
            body: {
              'result': {
                'orderId': 'o-3',
                'orderType': 'Reward',
                'orderNumber': 1,
                'createdAt': '2026-11-20T10:00:00Z',
              },
            },
          ),
        ).orders.getOrderSummary('o-3'),
      );
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
        expect(
          await failedCall(
            bbx(FakeHttp(body: {'result': _order()..remove(field)})).orders
                .getOrderSummary('o-1'),
          ),
          isA<BbxResponseFormatFailure>(),
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
        expect(
          await failedCall(
            bbx(
              FakeHttp(
                body: {
                  'result': {..._order(), field: value},
                },
              ),
            ).orders.getOrderSummary('o-1'),
          ),
          isA<BbxResponseFormatFailure>(),
        );
      });
    }

    test('no result is a format error', () async {
      expect(
        await failedCall(
          bbx(FakeHttp(body: {'result': null})).orders.getOrderSummary('o-1'),
        ),
        isA<BbxResponseFormatFailure>(),
      );
    });

    test('a JSON-RPC error is a failure', () async {
      expect(
        await failedCall(
          bbx(FakeHttp(body: _rpcError())).orders.getOrderSummary('o-1'),
        ),
        isA<BbxRpcFailure>(),
      );
    });
  });

  group('refreshOrderSummary', () {
    test('sends the order id and reads the result', () async {
      final http = FakeHttp(body: {'result': _order()});
      final orders = bbx(http).orders;
      final order = valueOf(await orders.refreshOrderSummary('o-1'));

      final request = http.requests.single;
      expect(request.path, '/ak/api-orders');
      expect((request.data as Map)['method'], 'refreshOrderSummary');
      expect((request.data as Map)['params'], {'orderId': 'o-1'});
      expect(order.orderId, 'o-1');
    });

    test('a JSON-RPC error is a failure', () async {
      expect(
        await failedCall(
          bbx(FakeHttp(body: _rpcError())).orders.refreshOrderSummary('o-1'),
        ),
        isA<BbxRpcFailure>(),
      );
    });
  });

  group('listOrderSummaries', () {
    test('asks for the newest page and reads every order', () async {
      final http = FakeHttp(
        body: {
          'result': {
            'elements': [_order(), _order(orderId: 'o-2')],
          },
        },
      );
      final orders = bbx(http).orders;
      final list = valueOf(await orders.listOrderSummaries());

      final request = http.requests.single;
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
      final list = valueOf(
        await bbx(
          FakeHttp(
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
        ).orders.listOrderSummaries(),
      );
      expect(list.orders.single.orderId, 'o-2');
      expect(list.rejected, hasLength(2));
      expect(list.rejected, everyElement(isA<BbxResponseFormatFailure>()));
    });

    test('missing elements are an empty list', () async {
      final list = valueOf(
        await bbx(FakeHttp(body: {'result': <String, Object?>{}})).orders
            .listOrderSummaries(),
      );
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
        expect(
          await failedCall(
            bbx(FakeHttp(body: body)).orders.listOrderSummaries(),
          ),
          isA<BbxResponseFormatFailure>(),
        );
      });
    }

    test('a JSON-RPC error is a failure', () async {
      expect(
        await failedCall(
          bbx(FakeHttp(body: _rpcError())).orders.listOrderSummaries(),
        ),
        isA<BbxRpcFailure>(),
      );
    });
  });

  for (final (method, call) in [
    ('getBuyLimits', (OrdersApi o) => o.getBuyLimits()),
    ('getSellLimits', (OrdersApi o) => o.getSellLimits()),
  ]) {
    group(method, () {
      test('decodes owned limit values', () async {
        final http = FakeHttp(
          body: {
            'result': {
              'min': 10,
              'max': 1000,
              'unrecognizedFutureField': 'is ignored',
              'limits': {
                'CAD': [1, 2],
              },
            },
          },
        );
        final orders = bbx(http).orders;
        final limits = valueOf(await call(orders));
        expect(limits.minimum, 10);
        expect(limits.maximum, 1000);
        expect(limits.currencyLimits, hasLength(1));
        expect(limits.currencyLimits.single.currencyCode, 'CAD');
        expect(limits.currencyLimits.single.values, [1, 2]);

        final request = http.requests.single;
        expect(request.path, '/ak/api-orders');
        expect((request.data as Map)['method'], method);
        expect((request.data as Map)['params'], isEmpty);
      });

      for (final result in <Map<String, Object?>>[
        <String, Object?>{},
        {'min': null, 'max': null, 'limits': null},
      ]) {
        test('missing and null limit fields stay empty: $result', () async {
          final orders = bbx(FakeHttp(body: {'result': result})).orders;

          final limits = valueOf(await call(orders));

          expect(limits.minimum, isNull);
          expect(limits.maximum, isNull);
          expect(limits.currencyLimits, isEmpty);
        });
      }

      test('no result is a format error', () async {
        expect(
          await failedCall(call(bbx(FakeHttp(body: {'result': null})).orders)),
          isA<BbxResponseFormatFailure>(),
        );
      });

      test('a JSON-RPC error is a failure', () async {
        expect(
          await failedCall(call(bbx(FakeHttp(body: _rpcError())).orders)),
          isA<BbxRpcFailure>(),
        );
      });
    });
  }
}
