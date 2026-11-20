import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/exchange/data/exchange_authentication.dart';
import 'package:bb_mobile/core/exchange/data/http/exchange_authentication_interceptor.dart';
import 'package:bbx_api/bbx_api.dart';
import 'package:dio/dio.dart';

/// Answers each request with [status] and [body], or throws [error].
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

  /// A client on this adapter; with [readApiKey], behind the app's
  /// authentication interceptor.
  BbxApiClient client({ReadExchangeApiKey? readApiKey}) {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'))
      ..httpClientAdapter = this;
    if (readApiKey != null) addExchangeAuthentication(dio, readApiKey);
    return BbxApiClient(dio);
  }
}
