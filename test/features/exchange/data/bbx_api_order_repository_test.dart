import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_api_key_failure.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_order_failure.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/exchange/domain/entity/sepa_payment_processor.dart';
import 'package:bb_mobile/features/dca/public/dca_facade.dart';
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

  group('placeBuyOrder', () {
    FakeBbxHttp created() => FakeBbxHttp(body: {'result': orderJsonFixture()});

    test('sends the address and the fiat amount', () async {
      final http = created();
      final order = await _repository(http, isTestnet: true).placeBuyOrder(
        toAddress: 'lq1address',
        orderAmount: const FiatAmount(5),
        currency: FiatCurrency.cad,
        network: OrderBitcoinNetwork.liquid,
        isOwner: true,
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
      await _repository(http).placeBuyOrder(
        toAddress: 'bc1address',
        orderAmount: const BitcoinAmount(0.001),
        currency: FiatCurrency.eur,
        network: OrderBitcoinNetwork.bitcoin,
        isOwner: false,
        payjoinBip21: 'bitcoin:bc1address?pj=https://payjo.in/s',
      );
      expect(_params(http), {
        'fiatCurrency': 'EUR',
        'network': 'bitcoin',
        'isOwner': false,
        'bip21URI': 'bitcoin:bc1address?pj=https://payjo.in/s',
        'bitcoinAmount': 0.001,
      });
    });

    Future<BuyOrder> buy(FakeBbxHttp http) => _repository(http).placeBuyOrder(
      toAddress: 'bc1address',
      orderAmount: const FiatAmount(5),
      currency: FiatCurrency.cad,
      network: OrderBitcoinNetwork.bitcoin,
      isOwner: true,
    );

    test('aggregate minimums are the lowest minimum', () async {
      await expectLater(
        buy(FakeBbxHttp(body: _limits([(20, _min), (50, _min)]))),
        throwsA(
          isA<BullBitcoinApiMinAmountException>()
              .having((e) => e.minAmount, 'minAmount', 20)
              .having((e) => e.currency, 'currency', 'CAD')
              .having(
                (e) => e.message,
                'message',
                'Minimum amount is 20.0 CAD',
              ),
        ),
      );
    });

    test('aggregate maximums are the highest maximum', () async {
      await expectLater(
        buy(FakeBbxHttp(body: _limits([(1000, _max), (3000, _max)]))),
        throwsA(
          isA<BullBitcoinApiMaxAmountException>()
              .having((e) => e.maxAmount, 'maxAmount', 3000)
              .having((e) => e.currency, 'currency', 'CAD'),
        ),
      );
    });

    test('mixed limits are wrapped as before, without the message', () async {
      await expectLater(
        buy(FakeBbxHttp(body: _limits([(20, _min), (50, _max)]))),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            'Exception: Failed to place buy order: '
                'Exception: Failed to create buy order',
          ),
        ),
      );
    });

    test('an inactive virtual payee is wrapped as before', () async {
      await expectLater(
        buy(FakeBbxHttp(body: _notActivated)),
        throwsA(
          isA<Exception>()
              .having(
                (e) => e,
                'type',
                isNot(
                  isA<BullBitcoinApiConfidentialSepaNotActivatedException>(),
                ),
              )
              .having(
                (e) => e.toString(),
                'message',
                startsWith('Exception: Failed to place buy order:'),
              ),
        ),
      );
    });

    test(
      'no stored key is ApiKeyNotFoundException, without a request',
      () async {
        final http = FakeBbxHttp();
        await expectLater(
          _signedOut(http).placeBuyOrder(
            toAddress: 'bc1address',
            orderAmount: const FiatAmount(5),
            currency: FiatCurrency.cad,
            network: OrderBitcoinNetwork.bitcoin,
            isOwner: true,
          ),
          throwsA(isA<ApiKeyNotFoundException>()),
        );
        expect(http.requests, isEmpty);
      },
    );

    test('an unreadable key is a credential exception', () async {
      await expectLater(
        _unreadableKey(FakeBbxHttp()).placeBuyOrder(
          toAddress: 'bc1address',
          orderAmount: const FiatAmount(5),
          currency: FiatCurrency.cad,
          network: OrderBitcoinNetwork.bitcoin,
          isOwner: true,
        ),
        throwsA(isA<ExchangeCredentialUnavailableException>()),
      );
    });
  });

  group('placeSellOrder', () {
    Future<SellOrder> sell(FakeBbxHttp http, {bool usePayjoin = false}) =>
        _repository(http).placeSellOrder(
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
      expect(await sell(http), isA<SellOrder>());
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

    test('a single minimum limit is the minimum exception', () async {
      await expectLater(
        sell(
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
        throwsA(
          isA<BullBitcoinApiMinAmountException>()
              .having((e) => e.minAmount, 'minAmount', 10)
              .having((e) => e.currency, 'currency', 'EUR'),
        ),
      );
    });

    test('another order type is the cast error, as before', () async {
      await expectLater(
        sell(FakeBbxHttp(body: {'result': orderJsonFixture()})),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('placePayOrder', () {
    Future<FiatPaymentOrder> pay(
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
          await pay(http, processor: processor, usePayjoin: true),
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
      await expectLater(
        pay(
          FakeBbxHttp(body: _notActivated),
          processor: SepaPaymentProcessor.confidential,
        ),
        throwsA(isA<BullBitcoinApiConfidentialSepaNotActivatedException>()),
      );
    });

    test('other refusals keep only their codes', () async {
      await expectLater(
        pay(
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
        throwsA(
          isA<BullBitcoinApiOrderException>()
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

    test('a maximum limit is the maximum exception', () async {
      await expectLater(
        pay(FakeBbxHttp(body: _limits([(500, _max)]))),
        throwsA(
          isA<BullBitcoinApiMaxAmountException>().having(
            (e) => e.maxAmount,
            'maxAmount',
            500,
          ),
        ),
      );
    });
  });

  group('placeWithdrawalOrder', () {
    Future<WithdrawOrder> withdraw(
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
        await withdraw(http, processor: SepaPaymentProcessor.confidential),
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

    test('limits and an inactive payee are their exceptions', () async {
      await expectLater(
        withdraw(FakeBbxHttp(body: _limits([(20, _min)]))),
        throwsA(isA<BullBitcoinApiMinAmountException>()),
      );
      await expectLater(
        withdraw(FakeBbxHttp(body: _limits([(20, _max)]))),
        throwsA(isA<BullBitcoinApiMaxAmountException>()),
      );
      await expectLater(
        withdraw(FakeBbxHttp(body: _notActivated)),
        throwsA(isA<BullBitcoinApiConfidentialSepaNotActivatedException>()),
      );
    });

    test('other failures drop the error', () async {
      await expectLater(
        withdraw(
          FakeBbxHttp(body: _rpcError),
          question: 'q',
          answer: 'secret',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            'Exception: Failed to create withdrawal order',
          ),
        ),
      );
    });
  });

  group('confirm and accelerate', () {
    test('confirmBuyOrder confirms the order summary', () async {
      final http = FakeBbxHttp(body: {'result': orderJsonFixture()});
      final order = await _repository(http).confirmBuyOrder('order-1');
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
        await _repository(http).confirmWithdrawOrder('order-1'),
        isA<WithdrawOrder>(),
      );
      expect(_params(http), {'orderId': 'order-1'});
    });

    test('accelerateBuyOrder unbatches and expresses the order', () async {
      final http = FakeBbxHttp(body: {'result': orderJsonFixture()});
      expect(
        await _repository(http).accelerateBuyOrder('order-1'),
        isA<BuyOrder>(),
      );
      expect(
        (http.requests.single.data as Map)['method'],
        'unbatchAndExpressOrder',
      );
      expect(_params(http), {'orderId': 'order-1'});
    });

    test('another order type fails as before', () async {
      final http = FakeBbxHttp(body: {'result': orderJsonFixture()});
      await expectLater(
        _repository(http).confirmWithdrawOrder('order-1'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Failed to confirm withdraw order:'),
          ),
        ),
      );
    });

    test('a JSON-RPC error is wrapped without its message', () async {
      for (final call in <Future<Order> Function(BbxApiOrderRepository)>[
        (r) => r.confirmBuyOrder('o'),
        (r) => r.confirmWithdrawOrder('o'),
        (r) => r.accelerateBuyOrder('o'),
      ]) {
        await expectLater(
          call(_repository(FakeBbxHttp(body: _rpcError))),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              allOf(
                contains('BbxApiRpcException(code: -1)'),
                isNot(contains('sat@example.com')),
              ),
            ),
          ),
        );
      }
    });

    test('a limit error on confirm is not an amount exception', () async {
      await expectLater(
        _repository(FakeBbxHttp(body: _limits([(20, _min)])))
            .confirmBuyOrder('o'),
        throwsA(
          isA<Exception>().having(
            (e) => e,
            'type',
            isNot(isA<BullBitcoinApiMinAmountException>()),
          ),
        ),
      );
    });

    test('no stored key is ApiKeyNotFoundException', () async {
      await expectLater(
        _signedOut(FakeBbxHttp()).confirmWithdrawOrder('o'),
        throwsA(isA<ApiKeyNotFoundException>()),
      );
      await expectLater(
        _signedOut(FakeBbxHttp()).accelerateBuyOrder('o'),
        throwsA(isA<ApiKeyNotFoundException>()),
      );
    });
  });

  test('createDca goes to the old repository', () async {
    final writes = _Writes();
    final dca = Dca(
      amount: 10,
      currency: FiatCurrency.cad,
      frequency: DcaBuyFrequency.weekly,
      network: DcaNetwork.bitcoin,
      address: 'bc1address',
      nextPurchaseDate: DateTime.utc(2026, 12),
    );
    when(
      () => writes.createDca(
        amount: 10,
        currency: FiatCurrency.cad,
        frequency: DcaBuyFrequency.weekly,
        network: DcaNetwork.bitcoin,
        address: 'bc1address',
      ),
    ).thenAnswer((_) async => dca);

    final http = FakeBbxHttp();
    final created = await _repository(http, writes: writes).createDca(
      amount: 10,
      currency: FiatCurrency.cad,
      frequency: DcaBuyFrequency.weekly,
      network: DcaNetwork.bitcoin,
      address: 'bc1address',
    );
    expect(created, same(dca));
    expect(http.requests, isEmpty);
  });
}
