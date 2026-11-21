import 'dart:typed_data';

import 'package:bb_mobile/core/exchange/domain/exchange_order_failure.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_user_failure.dart';
import 'package:bb_mobile/features/exchange/data/bbx_api_order_repository.dart';
import 'package:bb_mobile/features/exchange/data/bbx_api_user_repository.dart';
import 'package:bb_mobile/features/recipients/data/bbx_api_recipients_repository.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bbx_api/bbx_api.dart' show BbxApiClient;
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../core/exchange/order_json_fixture.dart';
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
  BbxApiOrderRepository orders(BbxApiClient api) =>
      BbxApiOrderRepository(api: api, isTestnet: true);

  test(
    'Dio-wrapped programming errors still propagate from order reads',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'))
        ..httpClientAdapter = _Throwing(
          DioException(
            requestOptions: RequestOptions(path: '/synthetic'),
            error: StateError('synthetic programming defect'),
          ),
        );
      final repository = orders(BbxApiClient(dio));
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
      final repository = orders(FakeBbxHttp(body: body).client());
      expect(
        await repository.getOrders(),
        isA<Err<dynamic, ExchangeOrderFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<ExchangeOrderLoadFailure>(),
        ),
      );
      expect(
        await repository.getOrderByTxId('synthetic-tx'),
        isA<Err<dynamic, ExchangeOrderFailure>>(),
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
      final repository = BbxApiUserRepository(
        api: FakeBbxHttp(body: {'result': value}).client(),
      );
      expect(
        await repository.getUserSummary(),
        isA<Err<dynamic, ExchangeUserFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<ExchangeUserSummaryUnavailableFailure>(),
        ),
      );
    });
  }

  for (final body in <Object?>[
    {
      'error': {'code': 'synthetic-rejection'},
    },
    {
      'result': {...orderJsonFixture(), 'orderId': 42},
    },
  ]) {
    test('action wire mismatch remains an infrastructure exception', () async {
      await expectLater(
        orders(FakeBbxHttp(body: body).client()).getOrder('synthetic'),
        throwsA(isA<Exception>()),
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
