import 'dart:convert';

import 'package:bbx_api/bbx_api.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

import 'fake_http.dart';

Future<void> _upload(Dio dio) => BbxApiClient(dio).kyc.uploadDocument(
  fileBytes: const [1, 2, 3],
  fileName: 'doc-1-ID.png',
  idTypeCode: 'ID',
  sourceDetail: 'secureUpload',
);

void main() {
  test('uploadDocument posts the file and the KYC request as multipart', () async {
    final dio = FakeHttp.dio(body: {'result': <String, Object?>{}});
    await _upload(dio);

    final http = dio.httpClientAdapter as FakeHttp;
    final request = http.requests.single;
    expect(request.path, '/ak/api-kyc/upload');
    expect(request.method, 'POST');
    expect(request.contentType, startsWith('multipart/form-data'));
    final form = request.data as FormData;
    expect(form.fields.single.key, 'kycIDDocument');
    expect(
      form.fields.single.value,
      '{"jsonrpc":"2.0","id":1,"method":"createMyKYCIDDocument",'
      '"params":{"element":{"idTypeCode":"ID","sourceDetail":"secureUpload"}}}',
    );
    final file = form.files.single;
    expect(file.key, 'file');
    expect(file.value.filename, 'doc-1-ID.png');
    expect(file.value.length, 3);
    final body = latin1.decode(http.bodies.single);
    expect(
      body,
      contains(
        'name="file"; filename="doc-1-ID.png"\r\n'
        'content-type: image/png\r\n\r\n\x01\x02\x03\r\n',
      ),
    );
  });

  for (final body in [
    null,
    <String, Object?>{},
    {'result': 'ok'},
  ]) {
    test('$body is a success', () async {
      await _upload(FakeHttp.dio(body: body));
    });
  }

  for (final body in [
    {'error': null},
    {'errors': <Object?>[]},
    {
      'error': {'code': -32000, 'message': 'rejected'},
    },
    {
      'result': {'error': 'rejected'},
    },
    {
      'result': {'errors': <Object?>[]},
    },
  ]) {
    test('$body is a rejection', () async {
      await expectLater(
        _upload(FakeHttp.dio(body: body)),
        throwsA(isA<BbxApiRpcException>()),
      );
    });
  }

  test('a result error that is null is not a rejection', () async {
    await _upload(
      FakeHttp.dio(
        body: {
          'result': {'error': null, 'errors': null},
        },
      ),
    );
  });

  test('a body that is not an object is a format error', () async {
    await expectLater(
      _upload(FakeHttp.dio(body: 'OK')),
      throwsA(isA<BbxApiFormatException>()),
    );
  });

  test('a non-200 status throws its status', () async {
    final dio = FakeHttp.dio(status: 204);
    await expectLater(
      _upload(dio),
      throwsA(
        isA<BbxApiHttpException>().having((e) => e.statusCode, 'status', 204),
      ),
    );
  });
}
