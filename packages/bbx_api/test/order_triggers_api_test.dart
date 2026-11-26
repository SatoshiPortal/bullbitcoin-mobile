import 'dart:convert';

import 'package:bbx_api/bbx_api.dart';
import 'package:test/test.dart';

import 'fake_http.dart';
import 'result_helpers.dart';

const _limitOrder = {
  'limitOrderId': 'lo-1',
  'limitOrderNbr': '42',
  'fiatAmount': '100.00',
  'currencyCode': 'CAD',
  'limitPrice': '90000.00',
  'estimatedBtcAmount': '0.00111111',
  'status': 'ACTIVE',
  'createdAt': '2026-11-20T10:00:00Z',
  'expiresAt': '2026-12-20T10:00:00Z',
  'executedAt': null,
  'cancelledAt': null,
  'executedOrderId': null,
  'address': 'bc1qaddress',
};

const _dca = {
  'userId': 'u-1',
  'userNbr': 7,
  'amountStr': '25.5',
  'currencyCode': 'CAD',
  'recurringFrequency': 'WEEKLY',
  'recipientType': 'OUT_BITCOIN_ADDRESS',
  'nextRunAt': '2026-11-27T00:00:00Z',
  'createdAt': '2026-11-20T00:00:00Z',
  'address': 'bc1qaddress',
};

/// The JSON-RPC request sent through [http], as the JSON text on the wire.
String _sent(FakeHttp http) {
  final request = http.requests.single;
  expect(request.path, '/ak/api-ordertrigger');
  expect(request.method, 'POST');
  return jsonEncode(request.data);
}

void main() {
  late FakeHttp http;
  late OrderTriggersApi api;

  void answer(Object? body, {int status = 200}) {
    http = FakeHttp(status: status, body: body);
    api = bbx(http).orderTriggers;
  }

  group('createDca', () {
    test('sends the old request with id 1 and reads the element', () async {
      answer({
        'result': {'element': _dca},
      });

      final dca = valueOf(
        await api.createDca(
          amount: 25.5,
          currencyCode: 'CAD',
          frequency: DcaFrequency.weekly,
          recipientType: DcaRecipientType.bitcoinAddress,
          address: 'bc1qaddress',
        ),
      );

      expect(
        _sent(http),
        '{"jsonrpc":"2.0","id":"1","method":"createDCA","params":{"element":'
        '{"amountStr":"25.5","currencyCode":"CAD","recurringFrequency":"WEEKLY",'
        '"recipientType":"OUT_BITCOIN_ADDRESS","address":"bc1qaddress"}}}',
      );
      expect(dca.userId, 'u-1');
      expect(dca.userNbr, 7);
      expect(dca.amountStr, '25.5');
      expect(dca.currencyCode, 'CAD');
      expect(dca.recurringFrequency, 'WEEKLY');
      expect(dca.recipientType, 'OUT_BITCOIN_ADDRESS');
      expect(dca.nextRunAt, '2026-11-27T00:00:00Z');
      expect(dca.createdAt, '2026-11-20T00:00:00Z');
      expect(dca.address, 'bc1qaddress');
    });

    test('sends the amount as Dart prints the double', () async {
      answer({
        'result': {'element': _dca},
      });

      valueOf(
        await api.createDca(
          amount: 100,
          currencyCode: 'EUR',
          frequency: DcaFrequency.hourly,
          recipientType: DcaRecipientType.lightningAddress,
          address: 'sat@example.com',
        ),
      );

      final params = jsonDecode(_sent(http))['params']['element'] as Map;
      expect(params['amountStr'], '100.0');
      expect(params['recurringFrequency'], 'HOURLY');
      expect(params['recipientType'], 'OUT_LIGHTNING_ADDRESS');
    });

    test('maps every frequency and recipient type to its wire value', () {
      expect(DcaFrequency.values.map((f) => f.value), [
        'HOURLY',
        'DAILY',
        'WEEKLY',
        'MONTHLY',
      ]);
      expect(DcaRecipientType.values.map((t) => t.value), [
        'OUT_BITCOIN_ADDRESS',
        'OUT_LIGHTNING_ADDRESS',
        'OUT_LIQUID_ADDRESS',
      ]);
    });

    test('a missing element or field is an unknown outcome', () async {
      answer({'result': <String, Object?>{}});
      expect(
        await failedCall(
          api.createDca(
            amount: 1,
            currencyCode: 'CAD',
            frequency: DcaFrequency.daily,
            recipientType: DcaRecipientType.liquidAddress,
            address: 'lq1',
          ),
        ),
        isA<BbxOutcomeUnknownFailure>(),
      );

      answer({
        'result': {
          'element': {..._dca}..remove('userId'),
        },
      });
      expect(
        await failedCall(
          api.createDca(
            amount: 1,
            currencyCode: 'CAD',
            frequency: DcaFrequency.daily,
            recipientType: DcaRecipientType.liquidAddress,
            address: 'lq1',
          ),
        ),
        isA<BbxOutcomeUnknownFailure>().having(
          (f) => f.reason,
          'reason',
          'invalid userId',
        ),
      );
    });

    test('a JSON-RPC error keeps its code and message', () async {
      answer({
        'error': {'code': -32000, 'message': 'nope'},
      });
      expect(
        await failedCall(
          api.createDca(
            amount: 1,
            currencyCode: 'CAD',
            frequency: DcaFrequency.monthly,
            recipientType: DcaRecipientType.bitcoinAddress,
            address: 'bc1',
          ),
        ),
        isA<BbxRpcFailure>()
            .having((f) => f.code, 'code', -32000)
            .having((f) => f.message, 'message', 'nope'),
      );
    });
  });

  group('limit orders', () {
    test('listLimitOrders sends the old request and reads elements', () async {
      answer({
        'result': {
          'elements': [_limitOrder],
        },
      });

      final orders = valueOf(await api.listLimitOrders());

      expect(
        _sent(http),
        '{"jsonrpc":"2.0","id":"0","method":"listLimitOrders","params":'
        '{"paginator":{"page":1,"pageSize":50},'
        '"sortBy":{"id":"createdAt","sort":"desc"}}}',
      );
      final order = orders.single;
      expect(order.limitOrderId, 'lo-1');
      expect(order.limitOrderNumber, '42');
      expect(order.fiatAmount, '100.00');
      expect(order.currencyCode, 'CAD');
      expect(order.limitPrice, '90000.00');
      expect(order.estimatedBtcAmount, '0.00111111');
      expect(order.status, 'ACTIVE');
      expect(order.createdAt, '2026-11-20T10:00:00Z');
      expect(order.expiresAt, '2026-12-20T10:00:00Z');
      expect(order.executedAt, isNull);
      expect(order.cancelledAt, isNull);
      expect(order.executedOrderId, isNull);
      expect(order.address, 'bc1qaddress');
    });

    test('a missing element list is empty', () async {
      answer({'result': <String, Object?>{}});
      expect(valueOf(await api.listLimitOrders()), isEmpty);

      answer({'result': <String, Object?>{}});
      expect(valueOf(await api.cancelAllLimitOrders()), isEmpty);
    });

    test('getLimitOrder sends the old request', () async {
      answer({'result': _limitOrder});

      final order = valueOf(await api.getLimitOrder('lo-1'));

      expect(
        _sent(http),
        '{"jsonrpc":"2.0","id":"0","method":"getLimitOrder","params":'
        '{"limitOrderId":"lo-1"}}',
      );
      expect(order.limitOrderId, 'lo-1');
    });

    test('addLimitOrder sends the old request', () async {
      answer({'result': _limitOrder});

      valueOf(
        await api.addLimitOrder(
          limitPrice: '90000.00',
          fiatAmount: '100.00',
          currencyCode: 'CAD',
          estimatedBtcAmount: '0.00111111',
          address: 'bc1qaddress',
        ),
      );

      expect(
        _sent(http),
        '{"jsonrpc":"2.0","id":"0","method":"addLimitOrder","params":'
        '{"element":{"limitPrice":"90000.00","fiatAmount":"100.00",'
        '"currencyCode":"CAD","estimatedBtcAmount":"0.00111111",'
        '"address":"bc1qaddress"}}}',
      );
    });

    test('cancelLimitOrder sends the old request', () async {
      answer({'result': _limitOrder});

      valueOf(await api.cancelLimitOrder('lo-1'));

      expect(
        _sent(http),
        '{"jsonrpc":"2.0","id":"0","method":"cancelLimitOrder","params":'
        '{"limitOrderId":"lo-1"}}',
      );
    });

    test('cancelAllLimitOrders sends the old request', () async {
      answer({
        'result': {
          'elements': [_limitOrder, _limitOrder],
        },
      });

      final orders = valueOf(await api.cancelAllLimitOrders());

      expect(
        _sent(http),
        '{"jsonrpc":"2.0","id":"0","method":"cancelAllLimitOrders",'
        '"params":{}}',
      );
      expect(orders, hasLength(2));
    });

    test('optional fields may be missing', () async {
      answer({
        'result': {..._limitOrder}
          ..remove('limitOrderNbr')
          ..remove('address'),
      });

      final order = valueOf(await api.getLimitOrder('lo-1'));

      expect(order.limitOrderNumber, isNull);
      expect(order.address, isNull);
    });

    test('a missing or mistyped field is a format error', () async {
      answer({
        'result': {..._limitOrder}..remove('status'),
      });
      expect(
        await failedCall(api.getLimitOrder('lo-1')),
        isA<BbxResponseFormatFailure>().having(
          (f) => f.reason,
          'reason',
          'invalid status',
        ),
      );

      answer({
        'result': {
          'elements': ['not an object'],
        },
      });
      expect(
        await failedCall(api.listLimitOrders()),
        isA<BbxResponseFormatFailure>(),
      );

      answer({'result': 'not an object'});
      expect(
        await failedCall(api.cancelLimitOrder('lo-1')),
        isA<BbxResponseFormatFailure>(),
      );
    });

    test('a refusal keeps the ERR_ code from data.code', () async {
      answer({
        'error': {
          'code': -32000,
          'message': 'Too many limit orders for sat@example.com',
          'data': {'code': 'ERR_ORDTRG_LOMAX429'},
        },
      });

      expect(
        await failedCall(
          api.addLimitOrder(
            limitPrice: '1.00',
            fiatAmount: '1.00',
            currencyCode: 'CAD',
            estimatedBtcAmount: '0.00000001',
            address: 'bc1',
          ),
        ),
        isA<BbxRpcFailure>()
            .having((f) => f.code, 'code', -32000)
            .having((f) => f.apiCode, 'apiCode', 'ERR_ORDTRG_LOMAX429'),
      );
    });

    test('a refusal ignores data.apiError and non-ERR_ data codes', () async {
      answer({
        'error': {
          'code': -32000,
          'data': {
            'apiError': {'code': 'ERR_ORDTRG_LO404'},
          },
        },
      });
      expect(
        await failedCall(api.getLimitOrder('lo-1')),
        isA<BbxRpcFailure>().having((f) => f.apiCode, 'apiCode', null),
      );

      answer({
        'error': {
          'code': -32000,
          'data': {'code': 'sat@example.com'},
        },
      });
      expect(
        await failedCall(api.getLimitOrder('lo-1')),
        isA<BbxRpcFailure>().having((f) => f.apiCode, 'apiCode', null),
      );

      answer({'error': 'nope'});
      expect(
        await failedCall(api.getLimitOrder('lo-1')),
        isA<BbxRpcFailure>()
            .having((f) => f.code, 'code', null)
            .having((f) => f.apiCode, 'apiCode', null),
      );
    });

    test('a refused status is an HTTP failure with its status', () async {
      answer({}, status: 401);
      expect(
        await failedCall(api.listLimitOrders()),
        isA<BbxHttpFailure>().having((f) => f.status, 'status', 401),
      );
    });
  });
}
