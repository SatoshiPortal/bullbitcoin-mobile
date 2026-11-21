import 'dart:convert';

import 'package:bb_mobile/core/exchange/domain/exchange_api_key_failure.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/features/limit_orders/data/bbx_api_limit_order_repository.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order_draft.dart';
import 'package:bb_mobile/features/limit_orders/domain/limit_orders_failure.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bbx_api/bbx_api.dart' show BbxApiClient;
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

import '../../exchange/data/exchange_log_capture.dart';
import '../../exchange/data/bbx_api_test_http.dart';

class _MockSettingsRepository extends Mock implements SettingsRepository {}

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

void main() {
  late _MockSettingsRepository settings;

  void useEnvironment(Environment environment) {
    when(() => settings.fetch()).thenAnswer(
      (_) async => SettingsEntity(
        environment: environment,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      ),
    );
  }

  setUp(() {
    settings = _MockSettingsRepository();
    useEnvironment(Environment.mainnet);
  });

  BbxApiLimitOrderRepository repository(
    FakeBbxHttp mainnet, {
    FakeBbxHttp? testnet,
  }) => BbxApiLimitOrderRepository(
    mainnet: mainnet.client(),
    testnet: (testnet ?? FakeBbxHttp()).client(),
    settingsRepository: settings,
  );

  BbxApiLimitOrderRepository withClient(BbxApiClient client) =>
      BbxApiLimitOrderRepository(
        mainnet: client,
        testnet: client,
        settingsRepository: settings,
      );

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
      await repository(http).listActive();
      expect(
        sent(http),
        '{"jsonrpc":"2.0","id":"0","method":"listLimitOrders","params":'
        '{"paginator":{"page":1,"pageSize":50},'
        '"sortBy":{"id":"createdAt","sort":"desc"}}}',
      );
    });

    test('get sends the old request', () async {
      final http = FakeBbxHttp(body: {'result': _order});
      await repository(http).get('lo-1');
      expect(
        sent(http),
        '{"jsonrpc":"2.0","id":"0","method":"getLimitOrder","params":'
        '{"limitOrderId":"lo-1"}}',
      );
    });

    test('create sends the old request with the old rounding', () async {
      final http = FakeBbxHttp(body: {'result': _order});
      await repository(http).create(
        LimitOrderDraft(
          limitPrice: 90000,
          fiatAmount: 100,
          currencyCode: 'CAD',
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
      await repository(http).cancel('lo-1');
      expect(
        sent(http),
        '{"jsonrpc":"2.0","id":"0","method":"cancelLimitOrder","params":'
        '{"limitOrderId":"lo-1"}}',
      );
    });

    test('cancelAll sends the old request', () async {
      final http = FakeBbxHttp(body: {'result': <String, Object?>{}});
      await repository(http).cancelAll();
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
      await repository(http).getRate('EUR');
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
        await repository(FakeBbxHttp(body: {'result': _order})).get('lo-1'),
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

    test('keeps the old defaults and unknown statuses', () async {
      final order = _valueOf(
        await repository(
          FakeBbxHttp(
            body: {
              'result': {..._order, 'status': 'NEW_STATUS'}
                ..remove('limitOrderNbr')
                ..remove('address'),
            },
          ),
        ).get('lo-1'),
      );

      expect(order.number, '');
      expect(order.address, '');
      expect(order.status, LimitOrderStatus.failed);
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
        ).listActive(),
      );

      expect(orders.map((o) => o.id), ['lo-1']);
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
        ).cancelAll(),
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
        ).getRate('CAD'),
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
        ).getRate('CAD'),
      );

      expect(rate.indexPrice, 5);
      expect(rate.userPrice, 6);
    });

    test('a rate without currency is a programmer error, as before', () {
      expect(
        () => repository(
          FakeBbxHttp(
            body: {
              'result': {'indexPrice': 500, 'userPrice': 600},
            },
          ),
        ).getRate('CAD'),
        throwsArgumentError,
      );
    });
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

      _valueOf(await repository(mainnet, testnet: testnet).listActive());

      expect(mainnet.requests, isEmpty);
      expect(testnet.requests, hasLength(1));
    });

    test('regtest refuses before either client', () async {
      useEnvironment(Environment.regtest);
      final mainnet = FakeBbxHttp();
      final testnet = FakeBbxHttp();

      expect(
        _failureOf(await repository(mainnet, testnet: testnet).listActive()),
        isA<LimitOrdersUnsupportedNetworkFailure>(),
      );
      expect(mainnet.requests, isEmpty);
      expect(testnet.requests, isEmpty);
    });
  });

  group('failures', () {
    test('maps the limit order codes to their failures', () async {
      expect(
        _failureOf(
          await repository(FakeBbxHttp(body: _refusal('ERR_ORDTRG_LOMAX429')))
              .create(
                LimitOrderDraft(
                  limitPrice: 1,
                  fiatAmount: 1,
                  currencyCode: 'CAD',
                  address: 'bc1',
                ),
              ),
        ),
        isA<LimitOrdersMaximumActiveFailure>(),
      );
      expect(
        _failureOf(
          await repository(FakeBbxHttp(body: _refusal('ERR_ORDTRG_LO404')))
              .get('lo-1'),
        ),
        isA<LimitOrderNotFoundFailure>(),
      );
      expect(
        _failureOf(
          await repository(FakeBbxHttp(body: _refusal('ERR_ORDTRG_ADDR400')))
              .create(
                LimitOrderDraft(
                  limitPrice: 1,
                  fiatAmount: 1,
                  currencyCode: 'CAD',
                  address: 'bc1',
                ),
              ),
        ),
        isA<LimitOrderInvalidAddressFailure>(),
      );
    });

    test(
      'an unknown code is the operation fallback without the message',
      () async {
        final load = _failureOf(
          await repository(FakeBbxHttp(body: _refusal('ERR_SOMETHING_NEW')))
              .listActive(),
        );
        expect(load, isA<LimitOrdersLoadFailure>());
        expect(load.logMessage, isNot(contains('sat@example.com')));
        expect(load.logMessage, contains('ERR_SOMETHING_NEW'));

        expect(
          _failureOf(
            await repository(FakeBbxHttp(body: _refusal('ERR_SOMETHING_NEW')))
                .cancel('lo-1'),
          ),
          isA<LimitOrderCancellationFailure>(),
        );
      },
    );

    test('a non-200 status or a malformed result is the fallback', () async {
      expect(
        _failureOf(
          await repository(FakeBbxHttp(status: 204, body: {})).cancelAll(),
        ),
        isA<LimitOrderCancellationFailure>(),
      );
      expect(
        _failureOf(
          await repository(FakeBbxHttp(body: {'result': 'nope'})).get('lo-1'),
        ),
        isA<LimitOrdersLoadFailure>(),
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
          ).get('lo-1'),
        );

        expect(failure, isA<LimitOrdersUnexpectedFailure>());
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
          ).get('lo-1'),
        ),
        isA<LimitOrdersUnexpectedFailure>(),
      );
    });

    test('a 401 is an unavailable account', () async {
      expect(
        _failureOf(
          await repository(FakeBbxHttp(status: 401, body: {})).listActive(),
        ),
        isA<LimitOrdersAccountUnavailableFailure>(),
      );
    });

    test('a transport error is unexpected', () async {
      expect(
        _failureOf(
          await repository(
            FakeBbxHttp(error: DioExceptionType.connectionTimeout),
          ).listActive(),
        ),
        isA<LimitOrdersUnexpectedFailure>(),
      );
    });

    test('no stored key is an unavailable account, with no request', () async {
      final http = FakeBbxHttp();
      expect(
        _failureOf(
          await withClient(http.client(readApiKey: () async => const Ok(null)))
              .listActive(),
        ),
        isA<LimitOrdersAccountUnavailableFailure>(),
      );
      expect(http.requests, isEmpty);
    });

    test('an unreadable key is the operation fallback', () async {
      final http = FakeBbxHttp();
      final failure = _failureOf(
        await withClient(
          http.client(
            readApiKey: () async => const Err(ExchangeApiKeyReadFailure()),
          ),
        ).cancelAll(),
      );
      expect(failure, isA<LimitOrderCancellationFailure>());
      expect(failure.logMessage, 'Exchange credential unavailable');
      expect(http.requests, isEmpty);
    });
  });
}
