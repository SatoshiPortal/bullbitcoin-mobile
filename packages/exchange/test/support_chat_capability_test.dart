import 'dart:typed_data';

import 'package:bbx_api/bbx_api_testing.dart';
import 'package:dio/dio.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'bbx_api_test_http.dart';

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

Exchange _exchange(HttpClientAdapter http, {String? key = 'synthetic-key'}) =>
    exchangeWithTransportForTesting(
      readSession: () async =>
          Ok((environment: ExchangeEnvironment.mainnet, epoch: 0, apiKey: key)),
      openClient: (endpoint, readKey) => bbxForTesting(
        endpoint: endpoint.toString(),
        adapter: http,
        readActiveApiKey: readKey,
      ),
    );

void main() {
  test(
    'a missing key is an authentication failure when reading chat',
    () async {
      final result = await _exchange(
        FakeBbxHttp(),
        key: null,
      ).getSupportMessages();
      expect((result as Err).failure, isA<ExchangeNotAuthenticatedFailure>());
    },
  );

  test('a transport throw is a sanitized attachment load failure', () async {
    final result = await _exchange(
      _Throwing(Exception('network down at host=secret.internal')),
    ).getSupportAttachment('a1');

    final failure = (result as Err).failure;
    expect(failure, isA<ExchangeChatLoadAttachmentFailure>());
    expect(failure.logMessage, isNot(contains('secret.internal')));
  });

  test('a missing key is an authentication failure when sending', () async {
    final result = await _exchange(
      FakeBbxHttp(),
      key: null,
    ).sendSupportMessage(text: 'hi');
    expect((result as Err).failure, isA<ExchangeNotAuthenticatedFailure>());
  });

  test('without a usable identity, the thread is never requested', () async {
    final http = FakeBbxHttp(body: {'result': null});
    final result = await _exchange(http).getSupportMessages();

    expect((result as Err).failure, isA<ExchangeNotAuthenticatedFailure>());
    expect(http.requests.map((r) => r.path), ['/ak/api-users']);
  });
}
