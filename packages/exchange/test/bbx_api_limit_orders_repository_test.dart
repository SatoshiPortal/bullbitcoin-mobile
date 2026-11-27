import 'dart:convert';

import 'package:exchange/exchange.dart';
import 'package:exchange/setup.dart';
import 'package:exchange/testing.dart';
import 'package:preferences/preferences.dart';
import 'package:bbx_api/bbx_api.dart' show Bbx, BbxCredentialUnavailableFailure;
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

import 'exchange_log_capture.dart';
import 'bbx_api_test_http.dart';

class _MockSettingsRepository extends Mock implements Preferences {}

const _order = {
  'limitOrderId': 'lo-1',
  'limitOrderNbr': '42',
  'fiatAmount': '100.00',
  'currencyCode': 'CAD',
  'limitPrice': '90000.00',
  'estimatedBtcAmount': '0.00111111',
  'status': 'ACTIVE',
  'createdAt': '2026-11-20T10:00:00Z',
  'expiresAt': '2026-12-20T10:00:00Z',
  'executedAt': '2026-11-21T10:00:00Z',
  'cancelledAt': null,
  'executedOrderId': 'o-9',
  'address': 'bc1qaddress',
};

Map<String, Object?> _refusal(String code) => {
  'error': {
    'code': -32000,
    'message': 'Refused for sat@example.com',
    'data': {'code': code},
  },
};

F _failureOf<T, F extends Failure>(Result<T, F> result) => switch (result) {
  Ok() => fail('expected an Err, got Ok'),
  Err(:final failure) => failure,
};

T _valueOf<T, F extends Failure>(Result<T, F> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => fail('expected an Ok, got ${failure.runtimeType}'),
};

Matcher _problem(ExchangeLimitOrderProblem problem) =>
    isA<ExchangeLimitOrderFailure>().having(
      (f) => f.problem,
      'problem',
      problem,
    );

void main() {
  late _MockSettingsRepository settings;
  // The signed-in session of the environment in use: every call names it.
  var current = const ExchangeSession(
    environment: ExchangeEnvironment.mainnet,
    epoch: 1,
    sessionId: 'mainnet',
  );

  void useEnvironment(Environment environment) {
    current = environment == Environment.testnet
        ? const ExchangeSession(
            environment: ExchangeEnvironment.testnet,
            epoch: 1,
            sessionId: 'testnet',
          )
        : const ExchangeSession(
            environment: ExchangeEnvironment.mainnet,
            epoch: 1,
            sessionId: 'mainnet',
          );
    when(() => settings.fetch()).thenAnswer(
      (_) async => Ok(
        SettingsEntity(
          environment: environment,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
        ),
      ),
    );
  }

  setUp(() {
    settings = _MockSettingsRepository();
    useEnvironment(Environment.mainnet);
  });

  LimitOrdersRepository fromClient(Bbx Function(Uri) openClient) =>
      exchangeWithTransportForTesting(
        readSession: () => readLegacyExchangeSession(
          preferences: settings,
          readSession: () => null,
          readKey: ({required isTestnet}) async => const Ok('synthetic-key'),
        ),
        openClient: (endpoint, _) => openClient(endpoint),
        access: _SignedInAccess(current),
      ).limitOrders;

  LimitOrdersRepository repository(
    FakeBbxHttp mainnet, {
    FakeBbxHttp? testnet,
  }) => fromClient(
    (endpoint) => endpoint.host.startsWith('testnet')
        ? (testnet ?? FakeBbxHttp()).client()
        : mainnet.client(),
  );

  LimitOrdersRepository withClient(Bbx client) => fromClient((_) => client);

  String sent(FakeBbxHttp http, {String path = '/ak/api-ordertrigger'}) {
    final request = http.requests.single;
    expect(request.path, path);
    return jsonEncode(request.data);
  }

  group('requests', () {
    test('listActive sends the old request', () async {
      final http = FakeBbxHttp(
        body: {
          'result': {'elements': <Object>[]},
        },
      );
      final _ = await repository(http).listActive(current);
      expect(
        sent(http),
        '{"jsonrpc":"2.0","id":"0","method":"listLimitOrders","params":'
        '{"paginator":{"page":1,"pageSize":50},'
        '"sortBy":{"id":"createdAt","sort":"desc"}}}',
      );
    });

    test('get sends the old request', () async {
      final http = FakeBbxHttp(body: {'result': _order});
      final _ = await repository(http).get(current, 'lo-1');
      expect(
        sent(http),
        '{"jsonrpc":"2.0","id":"0","method":"getLimitOrder","params":'
        '{"limitOrderId":"lo-1"}}',
      );
    });

    test('create sends COP amounts without decimals', () async {
      final http = FakeBbxHttp(body: {'result': _order});
      final _ = await repository(http).create(
        current,
        LimitOrderDraft(
          limitPrice: 400000000.4,
          fiatAmount: 200000.6,
          currency: FiatCurrency.cop,
          address: 'bc1qaddress',
        ),
      );
      final element =
          (jsonDecode(sent(http)) as Map<String, dynamic>)['params']['element']
              as Map<String, dynamic>;
      expect(element['limitPrice'], '400000000');
      expect(element['fiatAmount'], '200001');
      expect(element['currencyCode'], 'COP');
    });

    test('create sends the old request with the old rounding', () async {
      final http = FakeBbxHttp(body: {'result': _order});
      final _ = await repository(http).create(
        current,
        LimitOrderDraft(
          limitPrice: 90000,
          fiatAmount: 100,
          currency: FiatCurrency.cad,
          address: 'bc1qaddress',
        ),
      );
      expect(
        sent(http),
        '{"jsonrpc":"2.0","id":"0","method":"addLimitOrder","params":'
        '{"element":{"limitPrice":"90000.00","fiatAmount":"100.00",'
        '"currencyCode":"CAD","estimatedBtcAmount":"0.00111111",'
        '"address":"bc1qaddress"}}}',
      );
    });

    test('cancel sends the old request', () async {
      final http = FakeBbxHttp(body: {'result': _order});
      final _ = await repository(http).cancel(current, 'lo-1');
      expect(
        sent(http),
        '{"jsonrpc":"2.0","id":"0","method":"cancelLimitOrder","params":'
        '{"limitOrderId":"lo-1"}}',
      );
    });

    test('cancelAll sends the old request', () async {
      final http = FakeBbxHttp(body: {'result': <String, Object?>{}});
      final _ = await repository(http).cancelAll(current);
      expect(
        sent(http),
        '{"jsonrpc":"2.0","id":"0","method":"cancelAllLimitOrders",'
        '"params":{}}',
      );
    });

    test('getRate sends the old request', () async {
      final http = FakeBbxHttp(
        body: {
          'result': {
            'element': {'fromCurrency': 'EUR', 'indexPrice': 1, 'userPrice': 1},
          },
        },
      );
      final _ = await repository(http).getRate(current, 'EUR');
      expect(
        sent(http, path: '/public/price'),
        '{"jsonrpc":"2.0","id":"0","method":"getUserRate","params":'
        '{"element":{"fromCurrency":"EUR","toCurrency":"BTC"}}}',
      );
    });
  });

  group('mapping', () {
    test('maps a limit order', () async {
      final order = _valueOf(
        await repository(FakeBbxHttp(body: {'result': _order}))
            .get(current, 'lo-1'),
      );

      expect(order.id, 'lo-1');
      expect(order.number, '42');
      expect(order.fiatAmount, 100);
      expect(order.currencyCode, 'CAD');
      expect(order.limitPrice, 90000);
      expect(order.estimatedBtcAmount, 0.00111111);
      expect(order.status, LimitOrderStatus.active);
      expect(order.createdAt, DateTime.utc(2026, 11, 20, 10));
      expect(order.expiresAt, DateTime.utc(2026, 12, 20, 10));
      expect(order.executedAt, DateTime.utc(2026, 11, 21, 10));
      expect(order.cancelledAt, isNull);
      expect(order.executedOrderId, 'o-9');
      expect(order.address, 'bc1qaddress');
    });

    test('keeps the old defaults and maps a new status to unknown', () async {
      final order = _valueOf(
        await repository(
          FakeBbxHttp(
            body: {
              'result': {..._order, 'status': 'NEW_STATUS'}
                ..remove('limitOrderNbr')
                ..remove('address'),
            },
          ),
        ).get(current, 'lo-1'),
      );

      expect(order.number, '');
      expect(order.address, '');
      expect(order.status, LimitOrderStatus.unknown);
    });

    test('listActive keeps only active orders', () async {
      final orders = _valueOf(
        await repository(
          FakeBbxHttp(
            body: {
              'result': {
                'elements': [
                  _order,
                  {..._order, 'limitOrderId': 'lo-2', 'status': 'CANCELLED'},
                ],
              },
            },
          ),
        ).listActive(current),
      );

      expect(orders.map((o) => o.id), ['lo-1']);
    });

    test('listActive keeps orders whose status is unknown', () async {
      final orders = _valueOf(
        await repository(
          FakeBbxHttp(
            body: {
              'result': {
                'elements': [
                  {..._order, 'status': 'EXECUTING'},
                  {..._order, 'limitOrderId': 'lo-2', 'status': 'EXPIRED'},
                  {..._order, 'limitOrderId': 'lo-3', 'status': 'FAILED'},
                ],
              },
            },
          ),
        ).listActive(current),
      );

      expect(orders.map((o) => o.id), ['lo-1']);
      expect(orders.single.status, LimitOrderStatus.unknown);
      expect(orders.single.isActive, isFalse);
    });

    test('listRecent keeps every status of the page', () async {
      final orders = _valueOf(
        await repository(
          FakeBbxHttp(
            body: {
              'result': {
                'elements': [
                  _order,
                  {..._order, 'limitOrderId': 'lo-2', 'status': 'EXECUTED'},
                  {..._order, 'limitOrderId': 'lo-3', 'status': 'EXPIRED'},
                  {..._order, 'limitOrderId': 'lo-4', 'status': 'CANCELLED'},
                ],
              },
            },
          ),
        ).listRecent(current),
      );

      expect(orders.map((o) => o.id), ['lo-1', 'lo-2', 'lo-3', 'lo-4']);
      expect(orders[1].status, LimitOrderStatus.executed);
    });

    test('cancelAll keeps every returned order', () async {
      final orders = _valueOf(
        await repository(
          FakeBbxHttp(
            body: {
              'result': {
                'elements': [
                  _order,
                  {..._order, 'limitOrderId': 'lo-2', 'status': 'CANCELLED'},
                ],
              },
            },
          ),
        ).cancelAll(current),
      );

      expect(orders.map((o) => o.id), ['lo-1', 'lo-2']);
    });

    test('scales the rate by its precision', () async {
      final rate = _valueOf(
        await repository(
          FakeBbxHttp(
            body: {
              'result': {
                'element': {
                  'fromCurrency': 'CAD',
                  'indexPrice': 12345678,
                  'userPrice': 12400000,
                  'precision': 2,
                },
              },
            },
          ),
        ).getRate(current, 'CAD'),
      );

      expect(rate.currencyCode, 'CAD');
      expect(rate.indexPrice, 123456.78);
      expect(rate.userPrice, 124000);
    });

    test('a rate without precision uses two decimals', () async {
      final rate = _valueOf(
        await repository(
          FakeBbxHttp(
            body: {
              'result': {
                'fromCurrency': 'CAD',
                'indexPrice': 500,
                'userPrice': 600,
              },
            },
          ),
        ).getRate(current, 'CAD'),
      );

      expect(rate.indexPrice, 5);
      expect(rate.userPrice, 6);
    });

    test(
      'an unreadable rate is a load failure, not a thrown error (LIM-8)',
      () async {
        for (final element in [
          {'indexPrice': 500, 'userPrice': 600},
          {'fromCurrency': 'CAD', 'indexPrice': 0, 'userPrice': 600},
          {'fromCurrency': 'CAD', 'indexPrice': 500, 'userPrice': -1},
          {
            'fromCurrency': 'CAD',
            'indexPrice': 500,
            'userPrice': 600,
            'precision': -1,
          },
        ]) {
          final failure = _failureOf(
            await repository(FakeBbxHttp(body: {'result': element}))
                .getRate(current, 'CAD'),
          );
          expect(
            failure,
            isA<ExchangeLimitOrderFailure>().having(
              (f) => f.problem,
              'problem',
              ExchangeLimitOrderProblem.load,
            ),
            reason: '$element',
          );
        }
      },
    );
  });

  group('environment', () {
    test('testnet uses the testnet client', () async {
      useEnvironment(Environment.testnet);
      final mainnet = FakeBbxHttp();
      final testnet = FakeBbxHttp(
        body: {
          'result': {'elements': <Object>[]},
        },
      );

      _valueOf(await repository(mainnet, testnet: testnet).listActive(current));

      expect(mainnet.requests, isEmpty);
      expect(testnet.requests, hasLength(1));
    });

    test('regtest refuses before either client', () async {
      useEnvironment(Environment.regtest);
      final mainnet = FakeBbxHttp();
      final testnet = FakeBbxHttp();

      expect(
        _failureOf(
          await repository(mainnet, testnet: testnet).listActive(current),
        ),
        isA<ExchangeUnsupportedNetworkFailure>(),
      );
      expect(mainnet.requests, isEmpty);
      expect(testnet.requests, isEmpty);
    });
  });

  group('failures', () {
    group('create', () {
      final draft = LimitOrderDraft(
        limitPrice: 1,
        fiatAmount: 1,
        currency: FiatCurrency.cad,
        address: 'bc1',
      );

      test('a timeout after sending is an unknown outcome', () async {
        expect(
          await repository(FakeBbxHttp(error: DioExceptionType.receiveTimeout))
              .create(current, draft),
          isA<WriteOutcomeUnknown<LimitOrder>>(),
        );
      });

      test('a created order that cannot be mapped is an unknown outcome, '
          'without the server value', () async {
        final write = await repository(
          FakeBbxHttp(
            body: {
              'result': {..._order, 'fiatAmount': 'fixture-sensitive-amount'},
            },
          ),
        ).create(current, draft);
        expect(
          write,
          isA<WriteOutcomeUnknown<LimitOrder>>().having(
            (w) => w.reason,
            'reason',
            isNot(contains('fixture-sensitive')),
          ),
        );
      });

      test('a connect timeout was not sent and can be retried', () async {
        expect(
          await repository(
            FakeBbxHttp(error: DioExceptionType.connectionTimeout),
          ).create(current, draft),
          isA<WriteNotSent<LimitOrder>>(),
        );
      });

      test('a 401 is a rejected session', () async {
        expect(
          await repository(FakeBbxHttp(status: 401, body: {}))
              .create(current, draft),
          isA<WriteSessionRejected<LimitOrder>>(),
        );
      });

      test('a refusal keeps its code, which names the reason', () async {
        Future<LimitOrderRefusal> refusalOf(String code) async =>
            switch (await repository(FakeBbxHttp(body: _refusal(code)))
                .create(current, draft)) {
              WriteRefused(:final reason) => limitOrderRefusalOf(reason),
              final other => fail('not a refusal: $other'),
            };
        expect(
          await refusalOf('ERR_ORDTRG_LOMAX429'),
          LimitOrderRefusal.maximumActive,
        );
        expect(
          await refusalOf('ERR_ORDTRG_ADDR400'),
          LimitOrderRefusal.invalidAddress,
        );
        expect(await refusalOf('ERR_SOMETHING_NEW'), LimitOrderRefusal.other);
      });
    });

    test('maps the limit order codes to their failures', () async {
      expect(
        _failureOf(
          await repository(FakeBbxHttp(body: _refusal('ERR_ORDTRG_LO404')))
              .get(current, 'lo-1'),
        ),
        _problem(ExchangeLimitOrderProblem.notFound),
      );
    });

    test(
      'an unknown code is the operation fallback without the message',
      () async {
        final load = _failureOf(
          await repository(FakeBbxHttp(body: _refusal('ERR_SOMETHING_NEW')))
              .listActive(current),
        );
        expect(load, _problem(ExchangeLimitOrderProblem.load));
        expect(load.logMessage, isNot(contains('sat@example.com')));
        expect(load.logMessage, contains('ERR_SOMETHING_NEW'));

        expect(
          _failureOf(
            await repository(FakeBbxHttp(body: _refusal('ERR_SOMETHING_NEW')))
                .cancel(current, 'lo-1'),
          ),
          _problem(ExchangeLimitOrderProblem.cancel),
        );
      },
    );

    test('a non-200 status or a malformed result is the fallback', () async {
      expect(
        _failureOf(
          await repository(FakeBbxHttp(status: 204, body: {}))
              .cancelAll(current),
        ),
        _problem(ExchangeLimitOrderProblem.cancel),
      );
      expect(
        _failureOf(
          await repository(FakeBbxHttp(body: {'result': 'nope'}))
              .get(current, 'lo-1'),
        ),
        _problem(ExchangeLimitOrderProblem.load),
      );
    });

    test(
      'a malformed limit order keeps foreign values out of diagnostics',
      () async {
        final capture = await captureExchangeLogs();
        final failure = _failureOf(
          await repository(
            FakeBbxHttp(
              body: {
                'result': {..._order, 'fiatAmount': 'fixture-sensitive-amount'},
              },
            ),
          ).get(current, 'lo-1'),
        );

        expect(failure, isA<ExchangeUnexpectedFailure>());
        expect(failure.logMessage, 'FormatException');
        expect(capture.reporter.errors, [
          ('Failed to read the limit order', 'FormatException'),
        ]);
        final logs = (await capture.logger.readLogs()).join('\n');
        expect(logs, contains('Failed to read the limit order'));
        expect(logs, isNot(contains('fixture-sensitive-amount')));
      },
    );

    test('an unparsable amount is unexpected', () async {
      expect(
        _failureOf(
          await repository(
            FakeBbxHttp(
              body: {
                'result': {..._order, 'fiatAmount': 'abc'},
              },
            ),
          ).get(current, 'lo-1'),
        ),
        isA<ExchangeUnexpectedFailure>(),
      );
    });

    test('a 401 is an unavailable account', () async {
      expect(
        _failureOf(
          await repository(FakeBbxHttp(status: 401, body: {}))
              .listActive(current),
        ),
        isA<ExchangeSessionRejectedFailure>(),
      );
    });

    test('a transport error is unexpected', () async {
      expect(
        _failureOf(
          await repository(
            FakeBbxHttp(error: DioExceptionType.connectionTimeout),
          ).listActive(current),
        ),
        isA<ExchangeUnexpectedFailure>(),
      );
    });

    test('no stored key is an unavailable account, with no request', () async {
      final http = FakeBbxHttp();
      expect(
        _failureOf(
          await withClient(http.client(readApiKey: () async => const Ok(null)))
              .listActive(current),
        ),
        isA<ExchangeNotAuthenticatedFailure>(),
      );
      expect(http.requests, isEmpty);
    });

    test('an unreadable key is the operation fallback', () async {
      final http = FakeBbxHttp();
      final failure = _failureOf(
        await withClient(
          http.client(
            readApiKey: () async =>
                const Err(BbxCredentialUnavailableFailure()),
          ),
        ).cancelAll(current),
      );
      expect(failure, _problem(ExchangeLimitOrderProblem.cancel));
      expect(failure.logMessage, 'Exchange credential unavailable');
      expect(http.requests, isEmpty);
    });
  });
}

/// Signed in to [session]; a rejected key's expiry is accepted and ignored.
final class _SignedInAccess extends Fake implements ExchangeAccessLifecycle {
  @override
  final ExchangeSession session;

  _SignedInAccess(this.session);

  @override
  ExchangeAccess get current => ExchangeAccessSignedIn(session);

  @override
  Future<Result<void, ExchangeFailure>> expireSession({
    required int epoch,
    required bool isTestnet,
  }) async => const Ok(null);
}
