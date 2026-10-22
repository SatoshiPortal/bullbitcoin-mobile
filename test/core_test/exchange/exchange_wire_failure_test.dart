import 'package:bb_mobile/core/exchange/data/models/order_stats_model.dart';
import 'package:bb_mobile/core/exchange/data/models/recipient_model.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/repository/exchange_order_repository_impl.dart';
import 'package:bb_mobile/core/exchange/data/repository/exchange_user_repository_impl.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_order_failure.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_user_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/gateways/bullbitcoin_api_recipients_gateway.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../core/exchange/order_json_fixture.dart';

class _Http extends Mock implements Dio {}

void main() {
  late _Http http;
  late BullbitcoinApiDatasource datasource;
  setUp(() {
    http = _Http();
    datasource = BullbitcoinApiDatasource(bullbitcoinApiHttpClient: http);
  });

  void respond(Object? body) {
    when(() => http.post(any(), data: any(named: 'data'))).thenAnswer(
      (_) async => Response<Object?>(
        requestOptions: RequestOptions(path: '/synthetic'),
        statusCode: 200,
        data: body,
      ),
    );
  }

  test(
    'Dio-wrapped programming errors still propagate from order reads',
    () async {
      when(() => http.post(any(), data: any(named: 'data'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/synthetic'),
          error: StateError('synthetic programming defect'),
        ),
      );
      final repository = ExchangeOrderRepositoryImpl(
        bullbitcoinApiDatasource: datasource,
        isTestnet: true,
      );
      await expectLater(repository.getOrders(), throwsStateError);
      await expectLater(
        repository.getOrderByTxId('synthetic'),
        throwsStateError,
      );
    },
  );

  test('invalid recipient JSON is a decoding exception', () {
    expect(
      () => RecipientModel.fromJson({'recipientId': 42}),
      throwsA(isA<FormatException>()),
    );
  });
  test('invalid statistics JSON is a decoding exception', () {
    expect(
      () => OrderStatsResponseModel.fromJson({'orderStats': 42}),
      throwsA(isA<FormatException>()),
    );
  });

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
      respond(body);
      final repository = ExchangeOrderRepositoryImpl(
        bullbitcoinApiDatasource: datasource,
        isTestnet: true,
      );
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
      respond({'result': value});
      final repository = ExchangeUserRepositoryImpl(
        bullbitcoinApiDatasource: datasource,
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
      respond(body);
      final repository = ExchangeOrderRepositoryImpl(
        bullbitcoinApiDatasource: datasource,
        isTestnet: true,
      );
      await expectLater(
        repository.getOrder('synthetic'),
        throwsA(isA<Exception>()),
      );
    });
  }

  test('malformed SINPE response remains a typed lookup failure', () async {
    respond({
      'result': {'ownerName': 42},
    });
    final gateway = BullbitcoinApiRecipientsGateway(
      authenticatedApiClient: http,
    );
    expect(
      await gateway.checkSinpe(phoneNumber: 'synthetic', isTestnet: true),
      isA<Err<String, RecipientsFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<RecipientsSinpeLookupFailure>(),
      ),
    );
  });
}
