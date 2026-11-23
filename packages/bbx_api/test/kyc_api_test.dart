import 'dart:convert';

import 'package:bbx_api/bbx_api.dart';
import 'package:dio/dio.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

import 'fake_http.dart';
import 'result_helpers.dart';

Future<Result<void, BbxFailure>> _upload(FakeHttp http) => bbx(http).kyc
    .uploadDocument(
      fileBytes: const [1, 2, 3],
      fileName: 'doc-1-ID.png',
      idTypeCode: 'ID',
      sourceDetail: 'secureUpload',
    );

void main() {
  test(
    'uploadDocument has no send timeout and reports progress (INT-10)',
    () async {
      final http = FakeHttp(body: {'result': <String, Object?>{}});
      final progress = <(int, int)>[];
      valueOf(
        await bbx(http, timeouts: BbxTimeouts.standard).kyc.uploadDocument(
          fileBytes: const [1, 2, 3],
          fileName: 'doc-1-ID.png',
          idTypeCode: 'ID',
          sourceDetail: 'secureUpload',
          onProgress: (sent, total) => progress.add((sent, total)),
        ),
      );

      final request = http.requests.single;
      expect(request.sendTimeout, Duration.zero);
      expect(request.connectTimeout, const Duration(seconds: 30));
      expect(request.receiveTimeout, const Duration(seconds: 30));
      expect(progress, isNotEmpty);
      expect(progress.last.$1, progress.last.$2);
    },
  );

  test('uploadDocument posts the file and the KYC request as multipart', () async {
    final http = FakeHttp(body: {'result': <String, Object?>{}});
    valueOf(await _upload(http));

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
      valueOf(await _upload(FakeHttp(body: body)));
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
      expect(
        await failedCall(_upload(FakeHttp(body: body))),
        isA<BbxRpcFailure>(),
      );
    });
  }

  test('a result error that is null is not a rejection', () async {
    valueOf(
      await _upload(
        FakeHttp(
          body: {
            'result': {'error': null, 'errors': null},
          },
        ),
      ),
    );
  });

  test('a body that is not an object is a format error', () async {
    expect(
      await failedCall(_upload(FakeHttp(body: 'OK'))),
      isA<BbxResponseFormatFailure>(),
    );
  });

  test('a non-200 status is an HTTP failure with its status', () async {
    expect(
      await failedCall(_upload(FakeHttp(status: 204))),
      isA<BbxHttpFailure>().having((f) => f.status, 'status', 204),
    );
  });
}
