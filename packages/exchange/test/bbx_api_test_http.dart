import 'dart:convert';
import 'dart:typed_data';

import 'package:bbx_api/bbx_api.dart';
import 'package:bbx_api/bbx_api_testing.dart';
import 'package:dio/dio.dart';
import 'package:primitives/primitives.dart';

class FakeBbxHttp implements HttpClientAdapter {
  final int status;
  final Object? body;
  final DioExceptionType? error;
  final List<RequestOptions> requests = [];

  FakeBbxHttp({this.status = 200, this.body, this.error});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
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

  Bbx client({Future<Result<String?, BbxFailure>> Function()? readApiKey}) =>
      bbxForTesting(
        endpoint: 'https://example.invalid',
        adapter: this,
        readActiveApiKey: readApiKey ?? () async => const Ok('synthetic-key'),
      );
}
