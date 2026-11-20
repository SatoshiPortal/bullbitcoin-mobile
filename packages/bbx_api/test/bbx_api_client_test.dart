import 'package:bbx_api/bbx_api.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

import 'fake_http.dart';

void main() {
  test('sends a JSON-RPC request and returns the result', () async {
    final dio = FakeHttp.dio(body: {'result': 42});
    final result = await BbxApiClient(dio)
        .call('/ak/api-orders', 'ping', params: {'a': 1});

    expect(result, 42);
    final request = (dio.httpClientAdapter as FakeHttp).requests.single;
    expect(request.path, '/ak/api-orders');
    expect(request.method, 'POST');
    expect(request.data, {
      'jsonrpc': '2.0',
      'id': '0',
      'method': 'ping',
      'params': {'a': 1},
    });
  });

  test('a JSON-RPC error throws its code and message', () async {
    final client = BbxApiClient(
      FakeHttp.dio(
        body: {
          'error': {'code': -32000, 'message': 'nope'},
        },
      ),
    );
    await expectLater(
      client.call('/x', 'm'),
      throwsA(
        isA<BbxApiRpcException>()
            .having((e) => e.code, 'code', -32000)
            .having((e) => e.message, 'message', 'nope')
            .having((e) => '$e', 'toString', isNot(contains('nope'))),
      ),
    );
  });

  test('a body that is not an object is a format error', () async {
    final client = BbxApiClient(FakeHttp.dio(body: [1, 2]));
    await expectLater(
      client.call('/x', 'm'),
      throwsA(isA<BbxApiFormatException>()),
    );
  });

  test('transport errors are rethrown unchanged', () async {
    final client = BbxApiClient(FakeHttp.dio(status: 500, body: {}));
    await expectLater(client.call('/x', 'm'), throwsA(isA<DioException>()));
  });

  test('a non-200 success status is an HTTP error', () async {
    final client = BbxApiClient(FakeHttp.dio(status: 204, body: {}));
    await expectLater(
      client.call('/x', 'm'),
      throwsA(
        isA<BbxApiHttpException>().having((e) => e.statusCode, 'status', 204),
      ),
    );
  });
}
