import 'dart:convert';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/btcpay/data/datasources/samrock_pairing_datasource.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_failure.dart';
import 'package:bb_mobile/features/btcpay/domain/samrock_pairing_request.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final request = _request();

  test('posts the exact form-encoded SamRock setup contract', () async {
    late RequestOptions captured;
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          captured = options;
          handler.resolve(
            Response<String>(
              requestOptions: options,
              statusCode: 200,
              data: '{"Success":true}',
            ),
          );
        },
      ),
    );
    final datasource = SamRockPairingDatasource(dio: dio);
    final payload = <String, Object?>{
      'BTC': {'Descriptor': 'watch-only-descriptor'},
    };

    expect(
      await datasource.submitSetup(request: request, payload: payload),
      isA<Ok<void, BtcpayFailure>>(),
    );

    expect(captured.method, 'POST');
    expect(captured.uri, request.protocolUri);
    expect(captured.followRedirects, isFalse);
    expect(captured.responseType, ResponseType.plain);
    expect(captured.contentType, Headers.formUrlEncodedContentType);
    final form = captured.data! as Map<String, Object?>;
    expect(jsonDecode(form['json']! as String), payload);
  });

  test('accepts only an explicit boolean success response', () async {
    final datasource = SamRockPairingDatasource(
      dio: _dioReturning(statusCode: 200, body: '{"Success":true}'),
    );

    expect(
      await datasource.submitSetup(request: request, payload: const {}),
      isA<Ok<void, BtcpayFailure>>(),
    );
  });

  test('classifies explicit false on HTTP 2xx as rejection', () async {
    final datasource = SamRockPairingDatasource(
      dio: _dioReturning(statusCode: 200, body: '{"Success":false}'),
    );

    expect(
      _failure(
        await datasource.submitSetup(request: request, payload: const {}),
      ),
      isA<BtcpayPairingRejectedFailure>(),
    );
  });

  for (final body in <String>['{}', '', 'not-json', '{"Success":"true"}']) {
    test(
      'classifies missing boolean success evidence as uncertain: $body',
      () async {
        final datasource = SamRockPairingDatasource(
          dio: _dioReturning(statusCode: 200, body: body),
        );

        expect(
          _failure(
            await datasource.submitSetup(request: request, payload: const {}),
          ),
          isA<BtcpayPairingUncertainFailure>(),
        );
      },
    );
  }

  for (final statusCode in <int>[302, 500]) {
    test('classifies HTTP $statusCode as uncertain', () async {
      final datasource = SamRockPairingDatasource(
        dio: _dioReturning(statusCode: statusCode, body: '{"Success":false}'),
      );

      expect(
        _failure(
          await datasource.submitSetup(request: request, payload: const {}),
        ),
        isA<BtcpayPairingUncertainFailure>(),
      );
    });
  }

  test('classifies transport completion as uncertain', () async {
    final datasource = SamRockPairingDatasource(dio: _dioThrowing());

    expect(
      _failure(
        await datasource.submitSetup(request: request, payload: const {}),
      ),
      isA<BtcpayPairingUncertainFailure>(),
    );
  });
}

SamRockPairingRequest _request() {
  final result = const SamRockPairingRequestParser().parse(
    'https://btcpay.example.com/plugins/store123/samrock/protocol?otp=123&setup=btc',
  );
  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw TestFailure(
      'Expected valid request, got ${failure.runtimeType}',
    ),
  };
}

BtcpayFailure _failure(Result<void, BtcpayFailure> result) => switch (result) {
  Ok() => throw TestFailure('Expected Err, got Ok'),
  Err(:final failure) => failure,
};

Dio _dioReturning({required int statusCode, required String body}) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(
          Response<String>(
            requestOptions: options,
            statusCode: statusCode,
            data: body,
          ),
        );
      },
    ),
  );
  return dio;
}

Dio _dioThrowing() {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
            message: 'contains-sensitive-transport-detail',
          ),
        );
      },
    ),
  );
  return dio;
}
