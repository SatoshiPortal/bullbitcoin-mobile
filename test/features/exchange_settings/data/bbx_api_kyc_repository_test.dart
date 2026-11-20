import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/data/exchange_authentication.dart';
import 'package:bb_mobile/core/exchange/data/http/exchange_authentication_interceptor.dart';
import 'package:bb_mobile/core/exchange/domain/entity/file_upload.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_api_key_failure.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_kyc_repository.dart';
import 'package:bb_mobile/features/exchange_settings/data/bbx_api_kyc_repository.dart';
import 'package:bbx_api/bbx_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

/// One sent request: path, content type and body, with the multipart
/// boundary replaced by `BOUNDARY`.
typedef _Sent = (String, String, String);

/// Answers each request with [status] and [body], or throws [error],
/// recording what was sent.
class _UploadHttp implements HttpClientAdapter {
  final int status;
  final Object? body;
  final DioExceptionType? error;
  final List<_Sent> sent = [];

  _UploadHttp({this.status = 200, this.body, this.error});

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
      throw DioException(requestOptions: options, type: type);
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

Dio _dio(HttpClientAdapter http, {ReadExchangeApiKey? readApiKey}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'))
    ..httpClientAdapter = http;
  if (readApiKey != null) addExchangeAuthentication(dio, readApiKey);
  return dio;
}

ExchangeKycRepository _new(HttpClientAdapter http, {ReadExchangeApiKey? key}) =>
    BbxApiKycRepository(api: BbxApiClient(_dio(http, readApiKey: key)));

Future<FileUploadResult> _upload(
  ExchangeKycRepository repository, {
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

      expect(result.isSuccess, _oldSuccess[name]);
      if (!result.isSuccess) {
        expect(result.errorMessage, startsWith('Failed to upload document: '));
        expect(result.errorMessage, isNot(contains('server detail')));
      }
    });
  }

  test('a transport error is a failed result like before', () async {
    final result = await _upload(
      _new(_UploadHttp(error: DioExceptionType.connectionTimeout)),
    );

    expect(result.isSuccess, isFalse);
    expect(
      result.errorMessage,
      'Failed to upload document: DioException [connection timeout]: null',
    );
  });

  test('signed out throws ApiKeyNotFoundException like before', () async {
    Future<ExchangeKycRepository> signedOut(
      ExchangeKycRepository Function(
        HttpClientAdapter, {
        ReadExchangeApiKey? key,
      })
      build,
    ) async => build(_UploadHttp(), key: () async => const Ok(null));

    await expectLater(
      _upload(await signedOut(_new)),
      throwsA(isA<ApiKeyNotFoundException>()),
    );
  });

  test(
    'an unreadable key throws the credential exception like before',
    () async {
      Future<Object?> unreadable(
        ExchangeKycRepository Function(
          HttpClientAdapter, {
          ReadExchangeApiKey? key,
        })
        build,
      ) async {
        try {
          await _upload(
            build(
              _UploadHttp(),
              key: () async => const Err(ExchangeApiKeyReadFailure()),
            ),
          );
          return null;
        } catch (e) {
          return e.runtimeType;
        }
      }

      expect(await unreadable(_new), ExchangeCredentialUnavailableException);
    },
  );
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
