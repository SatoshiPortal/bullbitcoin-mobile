import 'dart:typed_data';

import 'package:exchange/testing.dart';
import 'package:exchange/exchange.dart';
import 'package:bbx_api/bbx_api_testing.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../features/exchange/data/bbx_api_test_http.dart';

class _Throwing implements HttpClientAdapter {
  final Object error;

  _Throwing(this.error);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => throw error;

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'Dio-wrapped programming errors still propagate from order reads',
    () async {
      final repository = testExchangeOrders(
        _Throwing(
          DioException(
            requestOptions: RequestOptions(path: '/synthetic'),
            error: StateError('synthetic programming defect'),
          ),
        ),
      );
      await expectLater(repository.getOrders(), throwsStateError);
      await expectLater(
        repository.getOrderByTxId('synthetic'),
        throwsStateError,
      );
    },
  );

  for (final body in <Object?>[
    {
      'error': {'code': 'synthetic-rejection'},
    },
    {'result': 42},
    {
      'result': {'elements': 'invalid-list'},
    },
    'invalid-envelope',
  ]) {
    test('order read maps invalid wire envelope ${body.runtimeType}', () async {
      final repository = testExchangeOrders(FakeBbxHttp(body: body));
      expect(
        await repository.getOrders(),
        isA<Err<dynamic, ExchangeFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<ExchangeOrderLoadFailure>(),
        ),
      );
      expect(
        await repository.getOrderByTxId('synthetic-tx'),
        isA<Err<dynamic, ExchangeFailure>>(),
      );
    });
  }

  for (final value in <Object>[
    42,
    {'userNumber': 'not-a-number'},
    {
      'userNumber': 1,
      'groups': <String>[],
      'profile': {'firstName': 42, 'lastName': 'synthetic'},
      'email': 'synthetic@example.invalid',
      'balances': <Object>[],
      'dca': {'isActive': false},
      'autoBuy': {'isActive': false, 'addresses': <String, Object>{}},
    },
  ]) {
    test('account wire mismatch ${value.runtimeType} is recoverable', () async {
      final exchange = exchangeWithTransportForTesting(
        readSession: () async => const Ok((
          environment: ExchangeEnvironment.testnet,
          epoch: 0,
          apiKey: anonymousTestApiKey,
        )),
        openClient: (endpoint, readKey) => bbxForTesting(
          endpoint: endpoint.toString(),
          adapter: FakeBbxHttp(body: {'result': value}),
          readActiveApiKey: readKey,
        ),
      );
      expect(
        await exchange.getUserSummary(ExchangeEnvironment.testnet),
        isA<Err<dynamic, ExchangeFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<ExchangeAccountUnavailableFailure>(),
        ),
      );
    });
  }

  for (final body in <Object?>[
    {
      'error': {'code': 'synthetic-rejection'},
    },
    {
      'result': {'orderId': 42, 'orderType': 'Buy Bitcoin'},
    },
  ]) {
    test('action wire mismatch returns a typed failure', () async {
      expect(
        await testExchangeOrders(FakeBbxHttp(body: body)).getOrder('synthetic'),
        isA<Err<Order, ExchangeFailure>>(),
      );
    });
  }

  test('malformed SINPE response remains a typed lookup failure', () async {
    final repository = BbxApiRecipientsRepository(
      api: FakeBbxHttp(
        body: {
          'result': {'ownerName': 42},
        },
      ).client(),
    );
    expect(
      await repository.checkSinpe(phoneNumber: 'synthetic', isTestnet: true),
      isA<Err<String, RecipientsFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<RecipientsSinpeLookupFailure>(),
      ),
    );
  });
}
