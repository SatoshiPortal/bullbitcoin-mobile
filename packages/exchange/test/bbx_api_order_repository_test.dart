import 'dart:convert';

import 'package:exchange/exchange.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'order_json_fixture.dart';
import 'exchange_log_capture.dart';
import 'bbx_api_test_http.dart';

const _rpcError = {
  'error': {'code': -1, 'message': 'rejected for sat@example.com'},
};

const _min = 'GREATER_THAN_OR_EQUAL';
const _max = 'LESS_THAN_OR_EQUAL';

const _notActivated = {
  'error': {
    'code': -32603,
    'message': 'Recipient not activated',
    'data': {
      'apiError': {'code': 'ERR_ORD_CSRCP400'},
    },
  },
};

Map<String, Object?> _limit(
  num amount,
  String operator, {
  String currency = 'CAD',
}) => {
  'entity': 'ORDER',
  'code': 'LIMIT_AMOUNT',
  'amount': '$amount',
  'conditionalOperator': operator,
  'currencyCode': currency,
};

Map<String, Object?> _limits(List<(num, String)> limits) => {
  'error': {
    'code': -32000,
    'message': 'No valid payment options available after applying limits',
    'data': {
      'reasons': [
        for (final (amount, operator) in limits)
          {'amount': '5', 'limit': _limit(amount, operator)},
      ],
    },
  },
};

Map<String, Object?> _params(FakeBbxHttp http) =>
    (http.requests.single.data as Map)['params'] as Map<String, Object?>;

Map<String, Object?> _list(List<Object?> elements) => {
  'result': {'elements': elements},
};

ExchangeOrders _repository(FakeBbxHttp http, {bool isTestnet = false}) =>
    testExchangeOrders(http, isTestnet: isTestnet);

ExchangeOrders _signedOut(FakeBbxHttp http) =>
    testExchangeOrders(http, readApiKey: () async => const Ok(null));

ExchangeOrders _unreadableKey(FakeBbxHttp http) => testExchangeOrders(
  http,
  readApiKey: () async => const Err(ExchangeCredentialReadFailure()),
);

Matcher _fails(Matcher matcher) => isA<Err<dynamic, ExchangeFailure>>().having(
  (r) => r.failure,
  'failure',
  matcher,
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
      final order = _valueOf(
        await _repository(http, isTestnet: true).getOrder('o-9'),
      );

      final request = http.requests.single;
      expect(request.path, '/ak/api-orders');
      expect((request.data as Map)['method'], 'getOrderSummary');
      expect((request.data as Map)['params'], {'orderId': 'o-9'});
      expect(order, isA<BuyOrder>());
      expect(order.orderId, 'o-9');
      expect(order.isTestnet, isTrue);
    });

    test(
      'no stored key is ExchangeNotAuthenticatedFailure, without a request',
      () async {
        final http = FakeBbxHttp();
        expect(
          await _signedOut(http).getOrder('o-1'),
          _fails(isA<ExchangeNotAuthenticatedFailure>()),
        );
        expect(http.requests, isEmpty);
      },
    );

    test('an unreadable key is a credential failure', () async {
      expect(
        await _unreadableKey(FakeBbxHttp()).getOrder('o-1'),
        _fails(isA<ExchangeCredentialReadFailure>()),
      );
    });

    test('a JSON-RPC rejection omits its message', () async {
      expect(
        await _repository(FakeBbxHttp(body: _rpcError)).getOrder('o-1'),
        _fails(
          isA<ExchangeOrderRejectedFailure>().having(
            (e) => e.toString(),
            'diagnostics',
            isNot(contains('sat@example.com')),
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
      final order = _valueOf(
        await _repository(http).refreshBuyOrder('order-1'),
      );

      final request = http.requests.single;
      expect((request.data as Map)['method'], 'refreshOrderSummary');
      expect((request.data as Map)['params'], {'orderId': 'order-1'});
      expect(order.orderId, 'order-1');
    });

    test('refreshSellOrder and refreshPayOrder return their types', () async {
      expect(
        _valueOf(
          await _repository(refreshed('Sell Bitcoin')).refreshSellOrder('o'),
        ),
        isA<SellOrder>(),
      );
      expect(
        _valueOf(
          await _repository(refreshed('Fiat Payment')).refreshPayOrder('o'),
        ),
        isA<FiatPaymentOrder>(),
      );
    });

    test('another order type returns a load failure', () async {
      expect(
        await _repository(refreshed('Sell Bitcoin')).refreshBuyOrder('o'),
        _fails(isA<ExchangeOrderLoadFailure>()),
      );
      expect(
        await _repository(refreshed('Buy Bitcoin')).refreshSellOrder('o'),
        _fails(isA<ExchangeOrderLoadFailure>()),
      );
      expect(
        await _repository(refreshed('Buy Bitcoin')).refreshPayOrder('o'),
        _fails(isA<ExchangeOrderLoadFailure>()),
      );
    });

    test('no stored key is ExchangeNotAuthenticatedFailure', () async {
      expect(
        await _signedOut(FakeBbxHttp()).refreshPayOrder('o'),
        _fails(isA<ExchangeNotAuthenticatedFailure>()),
      );
    });

    test('an unreadable key is a credential failure', () async {
      expect(
        await _unreadableKey(FakeBbxHttp()).refreshBuyOrder('o'),
        _fails(isA<ExchangeCredentialReadFailure>()),
      );
    });
  });

  group('getOrders', () {
    test(
      'order history hides server identifiers and invalid dates from logs',
      () async {
        final capture = await captureExchangeLogs();
        final http = FakeBbxHttp(
          body: _list([
            orderJsonFixture(orderId: 'good-order'),
            orderJsonFixture(
              orderId: 'fixture-sensitive-order-id',
              overrides: const {'createdAt': 'fixture-sensitive-date'},
            ),
          ]),
        );

        final orders = _valueOf(await _repository(http).getOrders());

        expect(orders.map((order) => order.orderId), ['good-order']);
        expect(capture.reporter.errors, [
          ('Error mapping exchange order', 'FormatException'),
        ]);
        final logs = (await capture.logger.readLogs()).join('\n');
        expect(logs, contains('Error mapping exchange order'));
        expect(logs, isNot(contains('fixture-sensitive-order-id')));
        expect(logs, isNot(contains('fixture-sensitive-date')));
      },
    );

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

    test('keeps orders with an Expired status or the Sell USDT type', () async {
      final orders = _valueOf(
        await _repository(
          FakeBbxHttp(
            body: _list([
              orderJsonFixture(orderId: 'expired-1', orderStatus: 'Expired'),
              orderJsonFixture(orderId: 'good-1'),
              orderJsonFixture(orderId: 'usdt-1', orderType: 'Sell USDT'),
            ]),
          ),
        ).getOrders(),
      );

      expect(
        [for (final o in orders) o.orderId],
        ['expired-1', 'good-1', 'usdt-1'],
      );
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
        isA<ExchangeCredentialReadFailure>(),
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
        isA<ExchangeCredentialReadFailure>(),
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

  group('placeBuyOrder', () {
    FakeBbxHttp created() => FakeBbxHttp(body: {'result': orderJsonFixture()});

    test('sends the address and the fiat amount', () async {
      final http = created();
      final order = _valueOf(
        await _repository(http, isTestnet: true).placeBuyOrder(
          toAddress: 'lq1address',
          orderAmount: const FiatAmount(5),
          currency: FiatCurrency.cad,
          network: OrderBitcoinNetwork.liquid,
          isOwner: true,
        ),
      );

      final request = http.requests.single;
      expect(request.path, '/ak/api-orders');
      expect((request.data as Map)['method'], 'createOrderBuy');
      expect(_params(http), {
        'fiatCurrency': 'CAD',
        'network': 'liquid',
        'isOwner': true,
        'address': 'lq1address',
        'fiatAmount': 5.0,
      });
      expect(order.orderId, 'order-1');
      expect(order.isTestnet, isTrue);
    });

    test('a payjoin buy sends the bip21URI instead of the address', () async {
      final http = created();
      expect(
        await _repository(http).placeBuyOrder(
          toAddress: 'bc1address',
          orderAmount: const BitcoinAmount(0.001),
          currency: FiatCurrency.eur,
          network: OrderBitcoinNetwork.bitcoin,
          isOwner: false,
          payjoinBip21: 'bitcoin:bc1address?pj=https://payjo.in/s',
        ),
        isA<Ok<BuyOrder, ExchangeFailure>>(),
      );
      expect(_params(http), {
        'fiatCurrency': 'EUR',
        'network': 'bitcoin',
        'isOwner': false,
        'bip21URI': 'bitcoin:bc1address?pj=https://payjo.in/s',
        'bitcoinAmount': 0.001,
      });
    });

    Future<Result<BuyOrder, ExchangeFailure>> buy(FakeBbxHttp http) =>
        _repository(http).placeBuyOrder(
          toAddress: 'bc1address',
          orderAmount: const FiatAmount(5),
          currency: FiatCurrency.cad,
          network: OrderBitcoinNetwork.bitcoin,
          isOwner: true,
        );

    test('aggregate minimums are the lowest minimum', () async {
      expect(
        await buy(FakeBbxHttp(body: _limits([(20, _min), (50, _min)]))),
        _fails(
          isA<ExchangeOrderLimitFailure>()
              .having((e) => e.bound, 'bound', ExchangeOrderAmountBound.minimum)
              .having((e) => e.amount, 'minAmount', 20)
              .having((e) => e.currency, 'currency', 'CAD'),
        ),
      );
    });

    test('aggregate maximums are the highest maximum', () async {
      expect(
        await buy(FakeBbxHttp(body: _limits([(1000, _max), (3000, _max)]))),
        _fails(
          isA<ExchangeOrderLimitFailure>()
              .having((e) => e.bound, 'bound', ExchangeOrderAmountBound.maximum)
              .having((e) => e.amount, 'maxAmount', 3000)
              .having((e) => e.currency, 'currency', 'CAD'),
        ),
      );
    });

    test('mixed limits are rejected without exposing the message', () async {
      expect(
        await buy(FakeBbxHttp(body: _limits([(20, _min), (50, _max)]))),
        _fails(isA<ExchangeOrderRejectedFailure>()),
      );
    });

    test('a transport failure keeps its safe classification', () async {
      expect(
        await buy(FakeBbxHttp(error: DioExceptionType.connectionError)),
        _fails(isA<ExchangeNetworkFailure>()),
      );
    });

    test('a single reason.limit is the minimum failure', () async {
      expect(
        await buy(
          FakeBbxHttp(
            body: {
              'error': {
                'message': 'Amount too low',
                'data': {
                  'reason': {'limit': _limit(0.0001, _min, currency: 'BTC')},
                },
              },
            },
          ),
        ),
        _fails(
          isA<ExchangeOrderLimitFailure>()
              .having((e) => e.bound, 'bound', ExchangeOrderAmountBound.minimum)
              .having((e) => e.amount, 'minAmount', 0.0001)
              .having((e) => e.currency, 'currency', 'BTC'),
        ),
      );
    });

    test('a decimal aggregate maximum is kept', () async {
      expect(
        await buy(FakeBbxHttp(body: _limits([(1000, _max), (2500.5, _max)]))),
        _fails(
          isA<ExchangeOrderLimitFailure>()
              .having((e) => e.bound, 'bound', ExchangeOrderAmountBound.maximum)
              .having((e) => e.amount, 'maxAmount', 2500.5),
        ),
      );
    });

    final unusableLimits = <String, Map<String, Object?>>{
      'mixed currencies': {
        'error': {
          'message': 'No valid payment options available after applying limits',
          'data': {
            'reasons': [
              {'limit': _limit(20, _min)},
              {'limit': _limit(0.0002, _min, currency: 'BTC')},
            ],
          },
        },
      },
      'an empty reasons array': {
        'error': {
          'message': 'No valid payment options available after applying limits',
          'data': {
            'reasons': <Object?>[],
            'details': <Object?>[null, null],
          },
        },
        'result': null,
      },
      'reasons without limits': {
        'error': {
          'message': 'No valid payment options available after applying limits',
          'data': {
            'reasons': [
              {'accessDescription': 'e-Transfer'},
              {'amount': '5'},
            ],
            'details': <Object?>[null],
          },
        },
      },
      'data without a reason': {
        'error': {
          'message': 'Order could not be created',
          'data': {
            'details': <Object?>[null, null],
          },
        },
        'result': null,
      },
      'an unrecognized error': {
        'error': {'message': 'Something else went wrong', 'data': null},
        'result': null,
      },
      'an error without a message': {'error': <String, Object?>{}},
    };
    for (final MapEntry(key: name, value: body) in unusableLimits.entries) {
      test('$name is a rejection without an amount bound', () async {
        expect(
          await buy(FakeBbxHttp(body: body)),
          _fails(isA<ExchangeOrderRejectedFailure>()),
        );
      });
    }

    test('an inactive virtual payee has a typed failure', () async {
      expect(
        await buy(FakeBbxHttp(body: _notActivated)),
        _fails(isA<ExchangeConfidentialSepaInactiveFailure>()),
      );
    });

    test(
      'no stored key is ExchangeNotAuthenticatedFailure, without a request',
      () async {
        final http = FakeBbxHttp();
        expect(
          await _signedOut(http).placeBuyOrder(
            toAddress: 'bc1address',
            orderAmount: const FiatAmount(5),
            currency: FiatCurrency.cad,
            network: OrderBitcoinNetwork.bitcoin,
            isOwner: true,
          ),
          _fails(isA<ExchangeNotAuthenticatedFailure>()),
        );
        expect(http.requests, isEmpty);
      },
    );

    test('an unreadable key is a credential failure', () async {
      expect(
        await _unreadableKey(FakeBbxHttp()).placeBuyOrder(
          toAddress: 'bc1address',
          orderAmount: const FiatAmount(5),
          currency: FiatCurrency.cad,
          network: OrderBitcoinNetwork.bitcoin,
          isOwner: true,
        ),
        _fails(isA<ExchangeCredentialReadFailure>()),
      );
    });
  });

  group('placeSellOrder', () {
    Future<Result<SellOrder, ExchangeFailure>> sell(
      FakeBbxHttp http, {
      bool usePayjoin = false,
    }) => _repository(http).placeSellOrder(
      orderAmount: const FiatAmount(100),
      currency: FiatCurrency.eur,
      network: OrderBitcoinNetwork.bitcoin,
      usePayjoin: usePayjoin,
    );

    FakeBbxHttp created() => FakeBbxHttp(
      body: {'result': orderJsonFixture(orderType: 'Sell Bitcoin')},
    );

    test('sends sellToBalance without usePayjoin when false', () async {
      final http = created();
      expect(_valueOf(await sell(http)), isA<SellOrder>());
      expect((http.requests.single.data as Map)['method'], 'sellToBalance');
      expect(_params(http), {
        'fiatCurrency': 'EUR',
        'bitcoinNetwork': 'bitcoin',
        'fiatAmount': 100.0,
      });
    });

    test('sends usePayjoin when true', () async {
      final http = created();
      await sell(http, usePayjoin: true);
      expect(_params(http), {
        'fiatCurrency': 'EUR',
        'bitcoinNetwork': 'bitcoin',
        'usePayjoin': true,
        'fiatAmount': 100.0,
      });
    });

    test('a single minimum limit is the minimum failure', () async {
      expect(
        await sell(
          FakeBbxHttp(
            body: {
              'error': {
                'code': -32000,
                'data': {
                  'reason': {'limit': _limit(10, _min, currency: 'EUR')},
                },
              },
            },
          ),
        ),
        _fails(
          isA<ExchangeOrderLimitFailure>()
              .having((e) => e.bound, 'bound', ExchangeOrderAmountBound.minimum)
              .having((e) => e.amount, 'minAmount', 10)
              .having((e) => e.currency, 'currency', 'EUR'),
        ),
      );
    });

    test('another order type is the cast error, as before', () async {
      expect(
        await sell(FakeBbxHttp(body: {'result': orderJsonFixture()})),
        _fails(isA<ExchangeOrderLoadFailure>()),
      );
    });
  });

  group('placePayOrder', () {
    Future<Result<FiatPaymentOrder, ExchangeFailure>> pay(
      FakeBbxHttp http, {
      SepaPaymentProcessor? processor,
      String? description,
      bool usePayjoin = false,
      OrderAmount amount = const BitcoinAmount(0.001),
    }) => _repository(http).placePayOrder(
      orderAmount: amount,
      recipientId: 'r-1',
      network: OrderBitcoinNetwork.bitcoin,
      paymentDescription: description,
      paymentProcessor: processor,
      usePayjoin: usePayjoin,
    );

    FakeBbxHttp created() => FakeBbxHttp(
      body: {'result': orderJsonFixture(orderType: 'Fiat Payment')},
    );

    for (final (processor, wire) in [
      (SepaPaymentProcessor.regular, 'REGULAR_SEPA'),
      (SepaPaymentProcessor.confidential, 'CONFIDENTIAL_SEPA'),
    ]) {
      test('sends the ${processor.name} processor and payjoin', () async {
        final http = created();
        expect(
          _valueOf(await pay(http, processor: processor, usePayjoin: true)),
          isA<FiatPaymentOrder>(),
        );
        expect((http.requests.single.data as Map)['method'], 'sellToRecipient');
        expect(_params(http), {
          'recipientId': 'r-1',
          'paymentProcessor': wire,
          'bitcoinNetwork': 'bitcoin',
          'usePayjoin': true,
          'bitcoinAmount': 0.001,
        });
      });
    }

    test('sends a description, and never an empty one', () async {
      final http = created();
      await pay(http, description: 'rent', amount: const FiatAmount(20));
      expect(_params(http), {
        'recipientId': 'r-1',
        'bitcoinNetwork': 'bitcoin',
        'fiatAmount': 20.0,
        'paymentDescription': 'rent',
      });

      final empty = created();
      await pay(empty, description: '');
      expect(_params(empty), {
        'recipientId': 'r-1',
        'bitcoinNetwork': 'bitcoin',
        'bitcoinAmount': 0.001,
      });
    });

    test('an inactive virtual payee is the activation exception', () async {
      expect(
        await pay(
          FakeBbxHttp(body: _notActivated),
          processor: SepaPaymentProcessor.confidential,
        ),
        _fails(isA<ExchangeConfidentialSepaInactiveFailure>()),
      );
    });

    test('other refusals keep only their codes', () async {
      expect(
        await pay(
          FakeBbxHttp(
            body: {
              'error': {
                'code': -32603,
                'message': 'Account details must stay out',
                'data': {
                  'apiError': {
                    'code': 'ERR_ORD_PO404',
                    'message': 'Account details must stay out',
                  },
                },
              },
            },
          ),
        ),
        _fails(
          isA<ExchangeOrderRejectedFailure>()
              .having((e) => e.apiCode, 'apiCode', 'ERR_ORD_PO404')
              .having((e) => e.rpcCode, 'rpcCode', -32603)
              .having(
                (e) => e.toString(),
                'text',
                isNot(contains('Account details')),
              ),
        ),
      );
    });

    test('a maximum limit is the maximum failure', () async {
      expect(
        await pay(FakeBbxHttp(body: _limits([(500, _max)]))),
        _fails(
          isA<ExchangeOrderLimitFailure>()
              .having((e) => e.bound, 'bound', ExchangeOrderAmountBound.maximum)
              .having((e) => e.amount, 'maxAmount', 500),
        ),
      );
    });
  });

  group('placeWithdrawalOrder', () {
    Future<Result<WithdrawOrder, ExchangeFailure>> withdraw(
      FakeBbxHttp http, {
      SepaPaymentProcessor? processor,
      String? question,
      String? answer,
    }) => _repository(http).placeWithdrawalOrder(
      fiatAmount: 50,
      recipientId: 'r-2',
      paymentProcessor: processor,
      securityQuestion: question,
      securityAnswer: answer,
    );

    FakeBbxHttp created() =>
        FakeBbxHttp(body: {'result': orderJsonFixture(orderType: 'Withdraw')});

    test('sends the amount, recipient and processor', () async {
      final http = created();
      expect(
        _valueOf(
          await withdraw(http, processor: SepaPaymentProcessor.confidential),
        ),
        isA<WithdrawOrder>(),
      );
      expect(
        (http.requests.single.data as Map)['method'],
        'createWithdrawalOrder',
      );
      expect(_params(http), {
        'fiatAmount': 50.0,
        'recipientId': 'r-2',
        'paymentProcessor': 'CONFIDENTIAL_SEPA',
      });
    });

    test('sends the Interac security details', () async {
      final http = created();
      await withdraw(http, question: 'q', answer: 'a');
      expect(_params(http), {
        'fiatAmount': 50.0,
        'recipientId': 'r-2',
        'paymentProcessorData': {
          'securityQuestion': 'q',
          'securityAnswer': 'a',
        },
      });
    });

    test('limits and an inactive payee are typed failures', () async {
      expect(
        await withdraw(FakeBbxHttp(body: _limits([(20, _min)]))),
        _fails(
          isA<ExchangeOrderLimitFailure>().having(
            (e) => e.bound,
            'bound',
            ExchangeOrderAmountBound.minimum,
          ),
        ),
      );
      expect(
        await withdraw(FakeBbxHttp(body: _limits([(20, _max)]))),
        _fails(
          isA<ExchangeOrderLimitFailure>().having(
            (e) => e.bound,
            'bound',
            ExchangeOrderAmountBound.maximum,
          ),
        ),
      );
      expect(
        await withdraw(FakeBbxHttp(body: _notActivated)),
        _fails(isA<ExchangeConfidentialSepaInactiveFailure>()),
      );
    });

    test('other failures drop the error', () async {
      expect(
        await withdraw(
          FakeBbxHttp(body: _rpcError),
          question: 'q',
          answer: 'secret',
        ),
        _fails(isA<ExchangeOrderRejectedFailure>()),
      );
    });
  });

  group('confirm and accelerate', () {
    test('confirmBuyOrder confirms the order summary', () async {
      final http = FakeBbxHttp(body: {'result': orderJsonFixture()});
      final order = _valueOf(
        await _repository(http).confirmBuyOrder('order-1'),
      );
      expect(
        (http.requests.single.data as Map)['method'],
        'confirmOrderSummary',
      );
      expect(_params(http), {'orderId': 'order-1'});
      expect(order.orderId, 'order-1');
    });

    test('confirmWithdrawOrder returns the withdraw order', () async {
      final http = FakeBbxHttp(
        body: {'result': orderJsonFixture(orderType: 'Withdraw')},
      );
      expect(
        _valueOf(await _repository(http).confirmWithdrawOrder('order-1')),
        isA<WithdrawOrder>(),
      );
      expect(_params(http), {'orderId': 'order-1'});
    });

    test('accelerateBuyOrder unbatches and expresses the order', () async {
      final http = FakeBbxHttp(body: {'result': orderJsonFixture()});
      expect(
        _valueOf(await _repository(http).accelerateBuyOrder('order-1')),
        isA<BuyOrder>(),
      );
      expect(
        (http.requests.single.data as Map)['method'],
        'unbatchAndExpressOrder',
      );
      expect(_params(http), {'orderId': 'order-1'});
    });

    test('another order type returns a load failure', () async {
      final http = FakeBbxHttp(body: {'result': orderJsonFixture()});
      expect(
        await _repository(http).confirmWithdrawOrder('order-1'),
        _fails(isA<ExchangeOrderLoadFailure>()),
      );
    });

    test('a JSON-RPC rejection omits its message', () async {
      for (final call
          in <Future<Result<Order, ExchangeFailure>> Function(ExchangeOrders)>[
            (r) => r.confirmBuyOrder('o'),
            (r) => r.confirmWithdrawOrder('o'),
            (r) => r.accelerateBuyOrder('o'),
          ]) {
        expect(
          await call(_repository(FakeBbxHttp(body: _rpcError))),
          _fails(
            isA<ExchangeOrderRejectedFailure>()
                .having(
                  (e) => e.toString(),
                  'diagnostics',
                  isNot(contains('sat@example.com')),
                )
                .having((e) => e.rpcCode, 'rpcCode', -1),
          ),
        );
      }
    });

    test('a limit error on confirm is not an amount failure', () async {
      expect(
        await _repository(FakeBbxHttp(body: _limits([(20, _min)])))
            .confirmBuyOrder('o'),
        _fails(isA<ExchangeOrderRejectedFailure>()),
      );
    });

    test('no stored key is ExchangeNotAuthenticatedFailure', () async {
      expect(
        await _signedOut(FakeBbxHttp()).confirmWithdrawOrder('o'),
        _fails(isA<ExchangeNotAuthenticatedFailure>()),
      );
      expect(
        await _signedOut(FakeBbxHttp()).accelerateBuyOrder('o'),
        _fails(isA<ExchangeNotAuthenticatedFailure>()),
      );
    });
  });

  group('createDca', () {
    const dca = {
      'userId': 'u-1',
      'userNbr': 7,
      'amountStr': '25.5',
      'currencyCode': 'CAD',
      'recurringFrequency': 'WEEKLY',
      'recipientType': 'OUT_LIQUID_ADDRESS',
      'nextRunAt': '2026-11-27T00:00:00Z',
      'createdAt': '2026-11-20T00:00:00Z',
      'address': 'lq1address',
    };

    Future<Result<Dca, ExchangeFailure>> create(
      FakeBbxHttp http, {
      DcaBuyFrequency frequency = DcaBuyFrequency.weekly,
      DcaNetwork network = DcaNetwork.liquid,
    }) => _repository(http).createDca(
      amount: 25.5,
      currency: FiatCurrency.cad,
      frequency: frequency,
      network: network,
      address: 'lq1address',
    );

    test('sends the same request as the old client', () async {
      final http = FakeBbxHttp(
        body: {
          'result': {'element': dca},
        },
      );

      await create(http);

      final request = http.requests.single;
      expect(request.path, '/ak/api-ordertrigger');
      expect(
        jsonEncode(request.data),
        '{"jsonrpc":"2.0","id":"1","method":"createDCA","params":{"element":'
        '{"amountStr":"25.5","currencyCode":"CAD","recurringFrequency":'
        '"WEEKLY","recipientType":"OUT_LIQUID_ADDRESS",'
        '"address":"lq1address"}}}',
      );
    });

    test('sends every frequency and network as before', () async {
      for (final (frequency, wire) in [
        (DcaBuyFrequency.hourly, 'HOURLY'),
        (DcaBuyFrequency.daily, 'DAILY'),
        (DcaBuyFrequency.weekly, 'WEEKLY'),
        (DcaBuyFrequency.monthly, 'MONTHLY'),
      ]) {
        final http = FakeBbxHttp(
          body: {
            'result': {'element': dca},
          },
        );
        await create(http, frequency: frequency);
        final element = _params(http)['element'];
        if (element is! Map<String, Object?>) {
          fail('Expected a DCA request element');
        }
        expect(element['recurringFrequency'], wire);
      }
      for (final (network, wire) in [
        (DcaNetwork.bitcoin, 'OUT_BITCOIN_ADDRESS'),
        (DcaNetwork.lightning, 'OUT_LIGHTNING_ADDRESS'),
        (DcaNetwork.liquid, 'OUT_LIQUID_ADDRESS'),
      ]) {
        final http = FakeBbxHttp(
          body: {
            'result': {'element': dca},
          },
        );
        await create(http, network: network);
        final element = _params(http)['element'];
        if (element is! Map<String, Object?>) {
          fail('Expected a DCA request element');
        }
        expect(element['recipientType'], wire);
      }
    });

    test('maps the created DCA', () async {
      final created = _valueOf(
        await create(
          FakeBbxHttp(
            body: {
              'result': {'element': dca},
            },
          ),
        ),
      );

      expect(created.amount, 25.5);
      expect(created.currency, FiatCurrency.cad);
      expect(created.frequency, DcaBuyFrequency.weekly);
      expect(created.network, DcaNetwork.liquid);
      expect(created.address, 'lq1address');
      expect(created.nextPurchaseDate, DateTime.utc(2026, 11, 27));
    });

    test(
      'an unknown frequency keeps the server value out of the failure',
      () async {
        expect(
          await create(
            FakeBbxHttp(
              body: {
                'result': {
                  'element': {...dca, 'recurringFrequency': 'YEARLY'},
                },
              },
            ),
          ),
          _fails(isA<ExchangeOrderLoadFailure>()),
        );
      },
    );

    test('a refusal is a typed failure without the message', () async {
      expect(
        await create(FakeBbxHttp(body: _rpcError)),
        _fails(
          isA<ExchangeOrderRejectedFailure>().having(
            (e) => e.toString(),
            'diagnostics',
            isNot(contains('sat@example.com')),
          ),
        ),
      );
    });

    test('no stored key is ExchangeNotAuthenticatedFailure', () async {
      expect(
        await _signedOut(FakeBbxHttp()).createDca(
          amount: 1,
          currency: FiatCurrency.cad,
          frequency: DcaBuyFrequency.daily,
          network: DcaNetwork.bitcoin,
          address: 'bc1',
        ),
        _fails(isA<ExchangeNotAuthenticatedFailure>()),
      );
    });

    test('an unreadable key is a credential failure', () async {
      expect(
        await _unreadableKey(FakeBbxHttp()).createDca(
          amount: 1,
          currency: FiatCurrency.cad,
          frequency: DcaBuyFrequency.daily,
          network: DcaNetwork.bitcoin,
          address: 'bc1',
        ),
        _fails(isA<ExchangeCredentialReadFailure>()),
      );
    });
  });
}
