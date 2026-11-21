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

  test('sends the given request id', () async {
    final dio = FakeHttp.dio(body: {'result': null});
    await BbxApiClient(dio).call('/x', 'm', id: '1');

    final request = (dio.httpClientAdapter as FakeHttp).requests.single;
    expect((request.data as Map)['id'], '1');
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

  group('upload', () {
    test(
      'posts the fields and files as multipart and returns the body',
      () async {
        final dio = FakeHttp.dio(body: {'ok': true});
        final body = await BbxApiClient(dio).upload(
          '/ak/api-x/upload',
          fields: {'meta': '{}'},
          files: {
            'file': const BbxApiFile([7, 8], fileName: 'f.bin'),
          },
        );

        expect(body, {'ok': true});
        final http = dio.httpClientAdapter as FakeHttp;
        final request = http.requests.single;
        expect(request.path, '/ak/api-x/upload');
        expect(request.method, 'POST');
        final form = request.data as FormData;
        expect(
          request.contentType,
          'multipart/form-data; boundary=${form.boundary}',
        );
        expect(
          [for (final f in form.fields) (f.key, f.value)],
          [('meta', '{}')],
        );
        expect(form.files.single.key, 'file');
        expect(form.files.single.value.filename, 'f.bin');
        expect(http.bodies.single, containsAllInOrder([7, 8]));
      },
    );

    test('a non-200 status throws its status', () async {
      await expectLater(
        BbxApiClient(FakeHttp.dio(status: 201)).upload('/x'),
        throwsA(
          isA<BbxApiHttpException>().having((e) => e.statusCode, 'status', 201),
        ),
      );
    });
  });
}
