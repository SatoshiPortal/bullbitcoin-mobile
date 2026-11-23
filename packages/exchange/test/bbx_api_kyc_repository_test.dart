import 'dart:convert';
import 'dart:typed_data';

import 'package:bbx_api/bbx_api.dart';
import 'package:bbx_api/bbx_api_testing.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'package:exchange/exchange.dart';
import 'package:exchange/src/data/bbx_api_kyc_repository.dart';

/// One sent request: path, content type and body, with the multipart
/// boundary replaced by `BOUNDARY`.
typedef _Sent = (String, String, String);

/// Answers each request with [status] and [body], or throws [error],
/// recording what was sent.
class _UploadHttp implements HttpClientAdapter {
  final int status;
  final Object? body;
  final DioExceptionType? error;
  final String? errorMessage;
  final List<_Sent> sent = [];

  _UploadHttp({this.status = 200, this.body, this.error, this.errorMessage});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bytes = [
      if (requestStream != null)
        for (final chunk in await requestStream.toList()) ...chunk,
    ];
    final contentType = options.headers[Headers.contentTypeHeader] as String;
    final boundary = contentType.split('boundary=').last;
    sent.add((
      options.path,
      contentType.replaceAll(boundary, 'BOUNDARY'),
      latin1.decode(bytes).replaceAll(boundary, 'BOUNDARY'),
    ));
    if (error case final type?) {
      throw DioException(
        requestOptions: options,
        type: type,
        message: errorMessage,
      );
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

BbxApiKycRepository _new(
  HttpClientAdapter http, {
  Future<Result<String?, BbxFailure>> Function()? key,
}) => BbxApiKycRepository(
  api: bbxForTesting(
    endpoint: 'https://example.invalid',
    adapter: http,
    readActiveApiKey: key ?? () async => const Ok('synthetic-key'),
  ),
);

Future<Result<void, ExchangeFailure>> _upload(
  BbxApiKycRepository repository, {
  String fileName = 'doc-u-1-ID',
}) => repository.uploadDocument(
  fileBytes: const [0, 1, 2, 255],
  fileName: fileName,
  docType: 'ID',
  sourceDetail: 'SECURE_UPLOAD',
);

void main() {
  for (final fileName in ['doc-u-1-ID', 'passport.png', 'scan.pdf']) {
    test('sends the same multipart request as the old repository '
        'for $fileName', () async {
      final newHttp = _UploadHttp(body: {'result': <String, Object?>{}});

      await _upload(_new(newHttp), fileName: fileName);

      expect(newHttp.sent, _oldSent[fileName]);
      final (path, contentType, body) = newHttp.sent.single;
      expect(path, '/ak/api-kyc/upload');
      expect(contentType, 'multipart/form-data; boundary=BOUNDARY');
      expect(
        body,
        contains(
          'content-disposition: form-data; name="kycIDDocument"\r\n\r\n'
          '{"jsonrpc":"2.0","id":1,"method":"createMyKYCIDDocument",'
          '"params":{"element":{"idTypeCode":"ID",'
          '"sourceDetail":"SECURE_UPLOAD"}}}\r\n',
        ),
      );
      expect(
        body,
        contains(
          'content-disposition: form-data; name="file"; '
          'filename="$fileName"\r\n',
        ),
      );
      expect(body, contains('\r\n\r\n\x00\x01\x02\xff\r\n'));
    });
  }

  final answers = <String, (int, Object?)>{
    'an empty result': (200, {'result': <String, Object?>{}}),
    'no body': (200, null),
    'an empty object': (200, <String, Object?>{}),
    'a result that is not an object': (200, {'result': 'ok'}),
    'null result errors': (
      200,
      {
        'result': {'error': null, 'errors': null},
      },
    ),
    'an error': (
      200,
      {
        'error': {'code': -32000, 'message': 'server detail'},
      },
    ),
    'a null error': (200, {'error': null}),
    'errors': (200, {'errors': <Object?>[]}),
    'a result error': (
      200,
      {
        'result': {'error': 'server detail'},
      },
    ),
    'result errors': (
      200,
      {
        'result': {'errors': <Object?>[]},
      },
    ),
    'a body that is not an object': (200, 'server detail'),
    'a list body': (200, <Object?>[]),
    'status 204': (204, null),
    'status 500': (500, null),
  };
  for (final MapEntry(key: name, value: (status, body)) in answers.entries) {
    test('$name gives the same outcome as the old repository', () async {
      final result = await _upload(
        _new(_UploadHttp(status: status, body: body)),
      );

      expect(result is Ok, _oldSuccess[name]);
      if (result case Err(:final failure)) {
        expect(failure.logMessage, startsWith('Failed to upload document: '));
        expect(failure.logMessage, isNot(contains('server detail')));
      }
    });
  }

  test(
    'a transport error keeps the raw exception message out of the failure',
    () async {
      final result = await _upload(
        _new(
          _UploadHttp(
            error: DioExceptionType.connectionTimeout,
            errorMessage: 'fixture-sensitive-upload-path',
          ),
        ),
      );

      final failure = (result as Err<void, ExchangeFailure>).failure;
      expect(
        failure.logMessage,
        'Failed to upload document: BbxTimeoutFailure',
      );
      expect(
        failure.logMessage,
        isNot(contains('fixture-sensitive-upload-path')),
      );
    },
  );

  test('a missing credential is not authenticated', () async {
    final result = await _upload(
      _new(_UploadHttp(), key: () async => const Ok(null)),
    );
    expect(
      (result as Err<void, ExchangeFailure>).failure,
      isA<ExchangeNotAuthenticatedFailure>(),
    );
  });

  test('an unreadable key is a distinct credential failure', () async {
    final result = await _upload(
      _new(
        _UploadHttp(),
        key: () async => const Err(BbxCredentialUnavailableFailure()),
      ),
    );
    expect(
      (result as Err<void, ExchangeFailure>).failure,
      isA<ExchangeCredentialReadFailure>(),
    );
  });
}

/// The multipart requests the removed ExchangeKycRepositoryImpl sent.
const _oldSent = <String, List<(String, String, String)>>{
  'doc-u-1-ID': [
    (
      '/ak/api-kyc/upload',
      'multipart/form-data; boundary=BOUNDARY',
      '--BOUNDARY\r\ncontent-disposition: form-data; name="kycIDDocument"\r\n\r\n{"jsonrpc":"2.0","id":1,"method":"createMyKYCIDDocument","params":{"element":{"idTypeCode":"ID","sourceDetail":"SECURE_UPLOAD"}}}\r\n--BOUNDARY\r\ncontent-disposition: form-data; name="file"; filename="doc-u-1-ID"\r\ncontent-type: application/octet-stream\r\n\r\n\x00\x01\x02\xff\r\n--BOUNDARY--\r\n',
    ),
  ],
  'passport.png': [
    (
      '/ak/api-kyc/upload',
      'multipart/form-data; boundary=BOUNDARY',
      '--BOUNDARY\r\ncontent-disposition: form-data; name="kycIDDocument"\r\n\r\n{"jsonrpc":"2.0","id":1,"method":"createMyKYCIDDocument","params":{"element":{"idTypeCode":"ID","sourceDetail":"SECURE_UPLOAD"}}}\r\n--BOUNDARY\r\ncontent-disposition: form-data; name="file"; filename="passport.png"\r\ncontent-type: image/png\r\n\r\n\x00\x01\x02\xff\r\n--BOUNDARY--\r\n',
    ),
  ],
  'scan.pdf': [
    (
      '/ak/api-kyc/upload',
      'multipart/form-data; boundary=BOUNDARY',
      '--BOUNDARY\r\ncontent-disposition: form-data; name="kycIDDocument"\r\n\r\n{"jsonrpc":"2.0","id":1,"method":"createMyKYCIDDocument","params":{"element":{"idTypeCode":"ID","sourceDetail":"SECURE_UPLOAD"}}}\r\n--BOUNDARY\r\ncontent-disposition: form-data; name="file"; filename="scan.pdf"\r\ncontent-type: application/pdf\r\n\r\n\x00\x01\x02\xff\r\n--BOUNDARY--\r\n',
    ),
  ],
};

/// Whether the removed ExchangeKycRepositoryImpl reported a success.
const _oldSuccess = <String, bool>{
  'an empty result': true,
  'no body': true,
  'an empty object': true,
  'a result that is not an object': true,
  'null result errors': true,
  'an error': false,
  'a null error': false,
  'errors': false,
  'a result error': false,
  'result errors': false,
  'a body that is not an object': false,
  'a list body': false,
  'status 204': false,
  'status 500': false,
};
