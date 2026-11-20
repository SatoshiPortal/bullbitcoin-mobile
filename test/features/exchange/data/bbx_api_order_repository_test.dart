import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_api_key_failure.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_order_failure.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/features/exchange/data/bbx_api_order_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

import '../../../core/exchange/order_json_fixture.dart';
import 'bbx_api_test_http.dart';

class _Writes extends Mock implements ExchangeOrderRepository {}

const _rpcError = {
  'error': {'code': -1, 'message': 'rejected for sat@example.com'},
};

Map<String, Object?> _list(List<Object?> elements) => {
  'result': {'elements': elements},
};

BbxApiOrderRepository _repository(
  FakeBbxHttp http, {
  ExchangeOrderRepository? writes,
  bool isTestnet = false,
}) => BbxApiOrderRepository(
  api: http.client(),
  writes: writes ?? _Writes(),
  isTestnet: isTestnet,
);

BbxApiOrderRepository _signedOut(FakeBbxHttp http) => BbxApiOrderRepository(
  api: http.client(readApiKey: () async => const Ok(null)),
  writes: _Writes(),
  isTestnet: false,
);

BbxApiOrderRepository _unreadableKey(FakeBbxHttp http) => BbxApiOrderRepository(
  api: http.client(
    readApiKey: () async => const Err(ExchangeApiKeyReadFailure()),
  ),
  writes: _Writes(),
  isTestnet: false,
);

F _failureOf<T, F extends Failure>(Result<T, F> result) => switch (result) {
  Ok() => fail('expected an Err, got Ok'),
  Err(:final failure) => failure,
};

T _valueOf<T, F extends Failure>(Result<T, F> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => fail('expected an Ok, got ${failure.runtimeType}'),
};

void main() {
  group('getOrder', () {
    test('reads the order through api-orders', () async {
      final http = FakeBbxHttp(
        body: {
          'result': {'element': orderJsonFixture(orderId: 'o-9')},
        },
      );
      final order = await _repository(http, isTestnet: true).getOrder('o-9');

      final request = http.requests.single;
      expect(request.path, '/ak/api-orders');
      expect((request.data as Map)['method'], 'getOrderSummary');
      expect((request.data as Map)['params'], {'orderId': 'o-9'});
      expect(order, isA<BuyOrder>());
      expect(order.orderId, 'o-9');
      expect(order.isTestnet, isTrue);
    });

    test(
      'no stored key is ApiKeyNotFoundException, without a request',
      () async {
        final http = FakeBbxHttp();
        await expectLater(
          _signedOut(http).getOrder('o-1'),
          throwsA(isA<ApiKeyNotFoundException>()),
        );
        expect(http.requests, isEmpty);
      },
    );

    test('an unreadable key is a credential exception', () async {
      await expectLater(
        _unreadableKey(FakeBbxHttp()).getOrder('o-1'),
        throwsA(isA<ExchangeCredentialUnavailableException>()),
      );
    });

    test('a JSON-RPC error is wrapped without its message', () async {
      await expectLater(
        _repository(FakeBbxHttp(body: _rpcError)).getOrder('o-1'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            allOf(
              startsWith('Exception: Failed to get order:'),
              isNot(contains('sat@example.com')),
            ),
          ),
        ),
      );
    });
  });

  group('refresh', () {
    FakeBbxHttp refreshed(String orderType) =>
        FakeBbxHttp(body: {'result': orderJsonFixture(orderType: orderType)});

    test('refreshBuyOrder asks api-orders to refresh the order', () async {
      final http = refreshed('Buy Bitcoin');
      final order = await _repository(http).refreshBuyOrder('order-1');

      final request = http.requests.single;
      expect((request.data as Map)['method'], 'refreshOrderSummary');
      expect((request.data as Map)['params'], {'orderId': 'order-1'});
      expect(order.orderId, 'order-1');
    });

    test('refreshSellOrder and refreshPayOrder return their types', () async {
      expect(
        await _repository(refreshed('Sell Bitcoin')).refreshSellOrder('o'),
        isA<SellOrder>(),
      );
      expect(
        await _repository(refreshed('Fiat Payment')).refreshPayOrder('o'),
        isA<FiatPaymentOrder>(),
      );
    });

    test('another order type fails as before', () async {
      await expectLater(
        _repository(refreshed('Sell Bitcoin')).refreshBuyOrder('o'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            startsWith('Exception: Failed to refresh order:'),
          ),
        ),
      );
      await expectLater(
        _repository(refreshed('Buy Bitcoin')).refreshSellOrder('o'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Expected SellOrder'),
          ),
        ),
      );
      await expectLater(
        _repository(refreshed('Buy Bitcoin')).refreshPayOrder('o'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            startsWith('Exception: Failed to refresh pay order:'),
          ),
        ),
      );
    });

    test('no stored key is ApiKeyNotFoundException', () async {
      await expectLater(
        _signedOut(FakeBbxHttp()).refreshPayOrder('o'),
        throwsA(isA<ApiKeyNotFoundException>()),
      );
    });

    test('an unreadable key is a credential exception', () async {
      await expectLater(
        _unreadableKey(FakeBbxHttp()).refreshBuyOrder('o'),
        throwsA(isA<ExchangeCredentialUnavailableException>()),
      );
    });
  });

  group('getOrders', () {
    test('maps the history, dropping what cannot be read', () async {
      final http = FakeBbxHttp(
        body: _list([
          orderJsonFixture(orderId: 'buy'),
          orderJsonFixture(orderId: 'sell', orderType: 'Sell Bitcoin'),
          orderJsonFixture(orderId: 'gold', orderType: 'Buy Gold Bars'),
          {'orderId': 'broken'},
          orderJsonFixture(
            orderId: 'bad-date',
            overrides: const {'createdAt': 'x'},
          ),
        ]),
      );
      final orders = _valueOf(await _repository(http).getOrders());

      expect((http.requests.single.data as Map)['params'], {
        'sortBy': {'id': 'createdAt', 'sort': 'desc'},
        'paginator': {'page': 1, 'pageSize': 50},
      });
      expect([for (final o in orders) o.orderId], ['buy', 'sell', 'gold']);
    });

    test('filters by type and pages locally', () async {
      FakeBbxHttp history() => FakeBbxHttp(
        body: _list([
          for (var i = 0; i < 4; i++) orderJsonFixture(orderId: 'buy-$i'),
          orderJsonFixture(orderId: 'sell', orderType: 'Sell Bitcoin'),
          orderJsonFixture(orderId: 'gold', orderType: 'Buy Gold Bars'),
        ]),
      );
      expect(
        [
          for (final o in _valueOf(
            await _repository(history()).getOrders(type: OrderType.sell),
          ))
            o.orderId,
        ],
        ['sell'],
      );
      expect(
        [
          for (final o in _valueOf(
            await _repository(history()).getOrders(type: OrderType.unknown),
          ))
            o.orderId,
        ],
        ['gold'],
      );
      expect(
        [
          for (final o in _valueOf(
            await _repository(history())
                .getOrders(type: OrderType.buy, offset: 1, limit: 2),
          ))
            o.orderId,
        ],
        ['buy-1', 'buy-2'],
      );
      expect(
        _valueOf(await _repository(history()).getOrders(offset: 10)),
        isEmpty,
      );
    });

    test('missing elements are an empty history', () async {
      expect(
        _valueOf(
          await _repository(FakeBbxHttp(body: {'result': <String, Object?>{}}))
              .getOrders(),
        ),
        isEmpty,
      );
    });

    test('no stored key is an empty history, without a request', () async {
      final http = FakeBbxHttp();
      expect(_valueOf(await _signedOut(http).getOrders()), isEmpty);
      expect(http.requests, isEmpty);
    });

    test('an unreadable key is a credential failure', () async {
      expect(
        _failureOf(await _unreadableKey(FakeBbxHttp()).getOrders()),
        isA<ExchangeOrderCredentialFailure>(),
      );
    });

    for (final (name, http) in [
      ('a JSON-RPC error', () => FakeBbxHttp(body: _rpcError)),
      ('no result', () => FakeBbxHttp(body: {'result': null})),
      ('a 503', () => FakeBbxHttp(status: 503, body: const {})),
      (
        'a timeout',
        () => FakeBbxHttp(error: DioExceptionType.connectionTimeout),
      ),
    ]) {
      test('$name is a load failure', () async {
        expect(
          _failureOf(await _repository(http()).getOrders()),
          isA<ExchangeOrderLoadFailure>(),
        );
      });
    }
  });

  group('getOrderByTxId', () {
    FakeBbxHttp history() => FakeBbxHttp(
      body: _list([
        orderJsonFixture(
          orderId: 'onchain',
          overrides: const {'bitcoinTransactionId': 'btc-tx'},
        ),
        orderJsonFixture(
          orderId: 'payjoin',
          orderType: 'Sell Bitcoin',
          overrides: const {
            'bitcoinTransactionId': 'original',
            'payjoinDetails': {'txid': 'pj-tx'},
          },
        ),
      ]),
    );

    test('finds an order by its own or its payjoin txid', () async {
      expect(
        _valueOf(await _repository(history()).getOrderByTxId('btc-tx'))
            ?.orderId,
        'onchain',
      );
      final payjoin = _valueOf(
        await _repository(history()).getOrderByTxId('pj-tx'),
      );
      expect(payjoin, isA<SellOrder>());
      expect(payjoin?.orderId, 'payjoin');
    });

    test('no match is Ok(null)', () async {
      expect(
        _valueOf(await _repository(history()).getOrderByTxId('other')),
        isNull,
      );
    });

    test('no stored key is Ok(null)', () async {
      expect(
        _valueOf(await _signedOut(FakeBbxHttp()).getOrderByTxId('btc-tx')),
        isNull,
      );
    });

    test('an unreadable key is a credential failure', () async {
      expect(
        _failureOf(await _unreadableKey(FakeBbxHttp()).getOrderByTxId('x')),
        isA<ExchangeOrderCredentialFailure>(),
      );
    });

    test('a JSON-RPC error is a load failure', () async {
      expect(
        _failureOf(
          await _repository(FakeBbxHttp(body: _rpcError)).getOrderByTxId('x'),
        ),
        isA<ExchangeOrderLoadFailure>(),
      );
    });

    test('an unmappable match is a load failure', () async {
      final http = FakeBbxHttp(
        body: _list([
          orderJsonFixture(
            overrides: const {'createdAt': 'x', 'bitcoinTransactionId': 't'},
          ),
        ]),
      );
      expect(
        _failureOf(await _repository(http).getOrderByTxId('t')),
        isA<ExchangeOrderLoadFailure>(),
      );
    });
  });

  group('limits', () {
    test('getBuyLimits and getSellLimits return the result object', () async {
      final http = FakeBbxHttp(
        body: {
          'result': {'min': 10},
        },
      );
      expect(await _repository(http).getBuyLimits(), {'min': 10});
      expect(await _repository(http).getSellLimits(), {'min': 10});
      expect(
        [for (final r in http.requests) (r.data as Map)['method']],
        ['getBuyLimits', 'getSellLimits'],
      );
    });

    test('a JSON-RPC error is wrapped without its message', () async {
      await expectLater(
        _repository(FakeBbxHttp(body: _rpcError)).getSellLimits(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            allOf(
              startsWith('Exception: Failed to get sell limits:'),
              isNot(contains('sat@example.com')),
            ),
          ),
        ),
      );
    });

    test('no stored key is ApiKeyNotFoundException', () async {
      await expectLater(
        _signedOut(FakeBbxHttp()).getBuyLimits(),
        throwsA(isA<ApiKeyNotFoundException>()),
      );
    });
  });

  test('order writes go to the old repository', () async {
    final writes = _Writes();
    final buy = await _repository(
      FakeBbxHttp(body: {'result': orderJsonFixture()}),
    ).refreshBuyOrder('order-1');
    when(() => writes.confirmBuyOrder('order-1')).thenAnswer((_) async => buy);
    when(() => writes.accelerateBuyOrder('order-1'))
        .thenAnswer((_) async => buy);

    final http = FakeBbxHttp();
    final repository = _repository(http, writes: writes);
    expect(await repository.confirmBuyOrder('order-1'), same(buy));
    expect(await repository.accelerateBuyOrder('order-1'), same(buy));
    verify(() => writes.confirmBuyOrder('order-1')).called(1);
    verify(() => writes.accelerateBuyOrder('order-1')).called(1);
    expect(http.requests, isEmpty);
  });
}
