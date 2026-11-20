import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Answers every request with [status] and [body], recording the requests.
class FakeHttp implements HttpClientAdapter {
  final int status;
  final Object? body;
  final List<RequestOptions> requests = [];

  FakeHttp({this.status = 200, this.body});

  static Dio dio({int status = 200, Object? body}) =>
      Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = FakeHttp(status: status, body: body);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
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
